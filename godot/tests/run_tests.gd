extends Node
## Headless tests. Run from the repo root:
##   godot --headless --path godot res://tests/run_tests.tscn
## 1. Data integrity (same checks as tests/engine.test.js).
## 2. Parity: replays battles recorded from the JS engine (tools/js_trace.js) with the
##    same seeded RNG and requires identical positions, HP, MP, CT and statuses every turn.
## 3. More AI-vs-AI battles (other seeds) on all three story missions.

var fails := 0
var checks := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var rules := get_node_or_null("/root/Rules")
	if rules == null or not rules.has_method("perform") or get_node_or_null("/root/Data") == null:
		print("FAIL autoloads did not load (script error above)")
		get_tree().quit(1)
		return
	data_integrity()
	movement_rules()
	parity()
	ai_battles()
	print("%d checks, %d failed (%.1fs)" % [checks, fails, (Time.get_ticks_msec() - t0) / 1000.0])
	print("all tests passed" if fails == 0 else "TESTS FAILED")
	get_tree().quit(1 if fails else 0)


func data_integrity() -> void:
	var taught_by := {}
	for it in Data.ITEMS.values():
		for id in it.teach:
			ok(Data.AB.has(id), it.id + " teaches unknown " + id)
			taught_by[id] = 1
	for id in Data.AB:
		if Data.AB[id].job:
			ok(taught_by.has(id), "no item teaches " + id)
			ok(Data.JOBS.has(Data.AB[id].job), id + " has unknown job")
	for r in Data.RECIPES:
		ok(Data.ITEMS.has(r.out), "recipe out " + r.out)
	for job in Data.STARTER:
		for id in Data.STARTER[job]:
			ok(Data.ITEMS.has(id), "starter " + id)
	for k in Data.MAPS:
		var m := Rules.parse_map(k)
		ok(m.tiles.all(func(r): return r.size() == m.w), k + " ragged rows")
		for d in m.deploy:
			ok(bool(Data.TERRAIN[m.tiles[d[1]][d[0]].t].pass), k + " deploy on blocked tile")
	for ms in Data.MISSIONS:
		var m := Rules.parse_map(ms.map)
		for e in ms.enemies:
			ok(bool(Data.TERRAIN[m.tiles[e[3]][e[2]].t].pass), "%s enemy on blocked tile %s" % [ms.id, e])
	ok(Data.RACES.human.hp == 80 and typeof(Data.RACES.human.hp) == TYPE_INT, "whole numbers load as ints")
	ok(Rules.jround(-2.5) == -2 and Rules.jround(2.5) == 3, "jround matches JS Math.round")


static func snap(B: Dictionary) -> Array:
	var out := []
	for u in B.units:
		var sts: Array = u.st.keys()
		sts.sort()
		out.append([u.id, u.x, u.y, u.f, u.hp, Rules.mp_total(u), Rules.jround(u.ct * 1000) / 1000.0, 1 if u.ko else 0, 1 if u.jailed else 0, ",".join(sts)])
	return out


static func same(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(a - b) < 1e-6
	return typeof(a) == typeof(b) and a == b


## Plays one battle with the AI on both sides, like tools/js_trace.js.
## step(turn_record) is called after each turn; return false to stop.
static func play(B: Dictionary, max_turns: int, step: Callable) -> int:
	var n := 0
	while not B.over and n < max_turns:
		var a: Dictionary = Rules.next_actor(B)
		var stt := Rules.start_turn(B, a)
		var plan = null
		if not Rules.check_end(B) and not stt.skip and not a.ko:
			plan = Rules.ai_plan(B, a)
			if plan.x != a.x or plan.y != a.y:
				Rules.move_unit(B, a, plan.x, plan.y)
			if plan.id:
				Rules.perform(B, a, plan.id, plan.cx, plan.cy)
			if a.team == 1 and not a.ko and not a.jailed:
				var f = Rules.nearest_foe(B, a)
				if f:
					a.f = Rules.face_toward(a, f.x, f.y)
		if not a.ko and not a.jailed:
			Rules.end_turn(B, a)
		elif a.ko:
			a.ct = 0
		n += 1
		if not step.call({"actor": a.id, "skip": stt.skip, "plan": plan, "units": snap(B)}):
			break
	return n


## Knocked-out bodies can be walked through but not stopped on.
func movement_rules() -> void:
	var B := Rules.mission_battle(0, [Rules.new_party()[0]], {})  # Rook alone at (1, 9), open ground to the north
	var a: Dictionary = B.units[0]
	var foe: Dictionary = B.units.filter(func(u): return u.team == 1)[0]
	var before := Rules.reach(B, a)
	var n := [a.x, a.y - 1]
	var n2 := [a.x, a.y - 2]
	ok(before.out.has(Rules.key(n[0], n[1])) and before.out.has(Rules.key(n2[0], n2[1])), "test tiles are open before the body lands")
	foe.x = n[0]
	foe.y = n[1]
	foe.ko = true
	var r := Rules.reach(B, a)
	ok(r.all.has(Rules.key(n[0], n[1])), "a body tile can be crossed")
	ok(not r.out.has(Rules.key(n[0], n[1])), "a unit cannot end its move on a body")
	ok(r.out.has(Rules.key(n2[0], n2[1])), "tiles beyond a body are reachable")
	foe.ko = false
	r = Rules.reach(B, a)
	ok(not r.all.has(Rules.key(n[0], n[1])), "a living foe still blocks the way")


func parity() -> void:
	var dir := "res://tests/fixtures/"
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.begins_with("trace_"))
	ok(files.size() >= 6, "parity fixtures present (run node godot/tools/js_trace.js)")
	for f in files:
		var T: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		var stage := int(T.stage)
		Rules.seed_lcg(int(T.seed))
		var party := Rules.new_party()
		for u in party:
			while u.lv < 1 + stage * 2:
				u.lv += 1
				Rules.grow(u, Data.JOBS[u.job].g)
		var B := Rules.mission_battle(stage, party, {"potion": 6, "phoenix": 2, "antidote": 2})
		var start := []
		for u in B.units:
			start.append([u.id, u.name, u.team, u.x, u.y, u.f, u.s.mhp, u.s.atk, u.s.spd, u.ct])
		if not same(start, T.start):
			ok(false, "%s: battle setup differs\n  js: %s\n  gd: %s" % [f, T.start, start])
			continue
		var turns: Array = T.turns
		var i := [0]
		var bad := [""]
		play(B, turns.size(), func(rec):
			var want: Dictionary = turns[i[0]]
			var p = rec.plan
			var gp = null if p == null else [p.x, p.y, p.id, p.cx, p.cy]
			var jp = null if want.plan == null else [want.plan.x, want.plan.y, want.plan.id, want.plan.cx, want.plan.cy]
			if rec.actor != want.actor or rec.skip != want.skip or not same(gp, jp) or not same(rec.units, want.units):
				bad[0] = "turn %d\n  js: actor %s plan %s\n      %s\n  gd: actor %s plan %s\n      %s" % [i[0] + 1, want.actor, jp, want.units, rec.actor, gp, rec.units]
				return false
			i[0] += 1
			return true)
		ok(bad[0] == "", "%s differs from JS at %s" % [f, bad[0]])
		ok(bad[0] != "" or (i[0] == turns.size() and B.over == int(T.over)), "%s: %d/%d turns, over %d (js %d)" % [f, i[0], turns.size(), B.over, T.over])
		if bad[0] == "":
			print("  parity ok: %s (%d turns, %s)" % [f, turns.size(), "win" if B.over == 1 else "loss"])
	Rules.unseed()


func ai_battles() -> void:
	for stage in 3:
		var res := {"win": 0, "loss": 0, "stalled": 0}
		for run in 4:
			# Seeded so the test is stable: some AI-vs-AI battles stall by design (see README).
			Rules.seed_lcg(1000 + stage * 10 + run)
			var party := Rules.new_party()
			for u in party:
				while u.lv < 1 + stage * 2:
					u.lv += 1
					Rules.grow(u, Data.JOBS[u.job].g)
			var B := Rules.mission_battle(stage, party, {"potion": 6, "phoenix": 2, "antidote": 2})
			play(B, 400, func(_r): return true)
			res["win" if B.over == 1 else "loss" if B.over == -1 else "stalled"] += 1
		Rules.unseed()
		print("  AI vs AI, mission %d: %s" % [stage + 1, res])
		ok(res.win + res.loss >= 3, "mission %d: most AI battles finish" % (stage + 1))
