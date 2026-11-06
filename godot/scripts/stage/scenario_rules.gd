class_name ScenarioRules
extends RefCounted
## The story battles' own rules on top of "defeat all enemies" (BattleSetup.rules), played by BattleStage:
##   carriers    {exit: [[x, y], ...], allowed}  EnemyData.behavior "carrier": a lantern bearer walks to the exit and is carried off the map (the spirit is
##               lost); knocking it down frees the spirit. More than `allowed` carried off loses the battle (chapter three, Battle 1).
##   clock       {every, spirits}  while a "device" stands, a spirit is consumed every `every` rounds; `spirits` consumed loses (Battle 2).
##   king_drain  {pct, source, stop_below}  each round Alaric loses pct% of his max HP while the `source` unit stands; below `stop_below`% of its HP the
##               source's hold breaks and the drain stops (Battle 4).
##   king_must_live  Alaric knocked out loses the battle.
##   king_hp_pct Alaric starts the battle with this percent of his HP (chapter five, Battle 4: hurt and spent)
##   captured    a vessel's name that cannot be summoned this battle (Lyra, held in the apparatus)
##   win_when_down   "carrier", "device" or a unit's name: the battle is won once every such unit is down (carried-off ones do not count when they lose it).
##   event       {unit, below, banner, line, fx ("counter" default, or "none"), status {name: turns}}  once, when that unit is at or below `below`% HP: a banner, the Fade Clock badge shakes and breaks over it (Battle 4).
##   standards   {every, kind, map}  chapter four, Battle 3: each living "standard" unit calls one `kind` of Mountain.enemy next to itself every `every` rounds
##   protect     a unit's name that must not fall (the memorial): its fall loses the battle even if it was the last enemy
##   win_unless  [names]: the battle is won once every enemy but these is down (Battle 4: everyone but the memorial)
##   boss_summon {unit, every, kind, count, map, banner}  the boss calls `count` of `kind` every `every` rounds (the Hollow Heart's Echoes of War)
## "device", "standard" and "memorial" units (EnemyData.behavior) never move or act.

var stage: BattleStage
var rules: Dictionary
var freed := 0
var escaped := 0
var consumed := 0
var carriers_total := 0
var _event_done := false
var _drain_off := false
var _last_round := 1


func _init(s: BattleStage, r: Dictionary) -> void:
	stage = s
	rules = r
	for e in stage.battle.enemies:
		if _is(e, "carrier"):
			carriers_total += 1
	if rules.has("king_hp_pct") and stage.battle.deployment.king != null:
		var k := stage.battle.deployment.king
		k.hp = maxi(1, k.max_hp() * int(rules.king_hp_pct) / 100)
	if rules.has("captured"):  # Battle 4: Lyra is held in the apparatus, so she cannot be summoned
		var dm := stage.battle.deployment
		dm.owned_vessels = dm.owned_vessels.filter(func(v): return v.display_name != String(rules.captured))
	refresh_objective()


func _is(bu: BattleUnit, behavior: String) -> bool:
	return bu.data is EnemyData and (bu.data as EnemyData).behavior == behavior


func _inert(bu: BattleUnit) -> bool:
	return _is(bu, "device") or _is(bu, "standard") or _is(bu, "memorial")


func _find(display_name: String) -> BattleUnit:
	for e in stage.battle.enemies:
		if e.data.display_name == display_name:
			return e
	return null


func refresh_objective() -> void:
	var t := ""
	if rules.has("carriers"):
		t = "Spirits freed %d/%d  ·  carried off %d" % [freed, carriers_total, escaped]
	elif rules.has("clock"):
		var devices := stage.battle.enemies.filter(func(e): return _is(e, "device") and not e.is_down()).size()
		t = "Soul-binders left %d  ·  spirits lost %d/%d" % [devices, consumed, int(rules.clock.spirits)]
	elif rules.has("standards"):
		var left := stage.battle.enemies.filter(func(e): return _is(e, "standard") and not e.is_down()).size()
		t = "War standards left %d" % left
	elif rules.has("protect"):
		var mem := _find(String(rules.protect))
		t = "Defeat Gideon  ·  memorial %d%%" % (mem.hp * 100 / maxi(1, mem.max_hp()) if mem != null else 0)
	elif rules.has("boss_summon"):
		t = "Defeat the %s" % String(rules.boss_summon.unit)
	elif rules.has("king_drain"):
		var src := _find(String(rules.king_drain.source))
		t = "Break the apparatus" if not _drain_off else "Finish the apparatus"
		if src != null:
			t += " (%d%% left)" % (src.hp * 100 / maxi(1, src.max_hp()))
	if t != "":
		stage.hud.set_objective(t)


## A unit that is a carrier or a device takes its own turn here. Returns true when it has played (the turn is over).
func enemy_turn(bu: BattleUnit) -> bool:
	if _inert(bu):
		stage.end_turn()
		return true
	if not _is(bu, "carrier"):
		return false
	var exits: Array = rules.get("carriers", {}).get("exit", [])
	var best := bu.cell
	if not exits.is_empty():
		var goal := Vector2i(int(exits[0][0]), int(exits[0][1]))
		var reach := stage.battle.move_range(bu)
		var dm := stage.battle.grid.reachable(goal, 400, bu.stat(StatModifier.Stat.JUMP), bu.team)
		var best_cost := dm.cost_to(bu.cell) if dm.can_reach(bu.cell) else 9999
		for c in reach.cells():
			if exits.any(func(e): return Vector2i(int(e[0]), int(e[1])) == c):
				best = c
				break
			var cost := dm.cost_to(c) if dm.can_reach(c) else 9999
			if cost < best_cost:
				best_cost = cost
				best = c
	if best != bu.cell:
		await stage.walk(bu, best)
	if not stage.is_inside_tree() or stage.battle.current != bu:
		return true
	if exits.any(func(e): return Vector2i(int(e[0]), int(e[1])) == bu.cell):
		await _carry_off(bu)
	if stage.battle.outcome == BattleController.Outcome.ONGOING and stage.battle.current == bu:
		stage.end_turn()
	return true


func _carry_off(bu: BattleUnit) -> void:
	escaped += 1
	stage.hud.say("A lantern is carried off the map. The spirit inside is lost.")
	stage._float(bu, "Carried off!", Color(1.0, 0.45, 0.4), true)
	stage.battle._flee(bu)
	await stage._play_flees()
	refresh_objective()
	if escaped > int(rules.carriers.get("allowed", 0)):
		_end(BattleController.Outcome.LOST)


func _end(o: BattleController.Outcome) -> void:
	if stage.battle.outcome == BattleController.Outcome.ONGOING:
		stage.battle.outcome = o
		stage.battle.battle_ended.emit(o)


## At the start of a round (the turn counter went up): the clock, the drain.
func on_round(round: int) -> void:
	if round == _last_round:
		return
	_last_round = round
	if rules.has("clock") and stage.battle.enemies.any(func(e): return _is(e, "device") and not e.is_down()):
		if round % int(rules.clock.every) == 0:
			consumed += 1
			stage.hud.say("A spirit is consumed by the soul-binders!")
			var any: BattleUnit = null
			for e in stage.battle.enemies:
				if _is(e, "device") and not e.is_down():
					any = e
					break
			if any != null:
				stage._float(any, "A spirit is consumed (%d / %d)" % [consumed, int(rules.clock.spirits)], Color(0.7, 0.8, 1.0), true)
			if consumed >= int(rules.clock.spirits):
				_end(BattleController.Outcome.LOST)
	_reinforce(round)
	var d: Dictionary = rules.get("king_drain", {})
	if not d.is_empty() and not _drain_off:
		var src := _find(String(d.source))
		var king := stage.battle.deployment.king
		if src != null and not src.is_down() and king != null and not king.is_down():
			var loss := maxi(1, king.max_hp() * int(d.pct) / 100)
			king.hp = maxi(0, king.hp - loss)
			stage._float(king, "Life drained -%d" % loss, Color(0.75, 0.4, 1.0), true)
			if king.is_down():
				stage.battle._check_outcome()
	refresh_objective()


## Reinforcements: every `every` rounds each war standard calls a soldier; the boss calls its echoes.
func _reinforce(round: int) -> void:
	var st: Dictionary = rules.get("standards", {})
	if not st.is_empty() and round % int(st.every) == 0:
		for e in stage.battle.enemies.filter(func(e): return _is(e, "standard") and not e.is_down()):
			_call(Mountain.enemy(String(st.kind), int(st.map), 100 + _called), e.cell, "")
	var bs: Dictionary = rules.get("boss_summon", {})
	if not bs.is_empty() and round % int(bs.every) == 0:
		var boss := _find(String(bs.unit))
		if boss != null and not boss.is_down():
			for i in int(bs.count):
				_call(Mountain.enemy(String(bs.kind), int(bs.map), 100 + _called), boss.cell, "")
			stage.hud.say(String(bs.get("banner", "")))
			stage._float(boss, "Echoes of War!", Color(0.75, 0.5, 1.0), true)


var _called := 0


func _call(data: EnemyData, near: Vector2i, _unused: String) -> void:
	_called += 1
	stage.spawn_enemy_near(data, near)


## After every action: freed spirits, the mid-battle event, the win and loss rules. Safe to call often.
func check() -> void:
	if stage.battle.outcome != BattleController.Outcome.ONGOING:
		return
	for e in stage.battle.enemies:
		if _is(e, "carrier") and e.is_down() and not e.fled and not e.has_meta("freed"):
			e.set_meta("freed", true)
			freed += 1
			stage._float(e, "Spirit freed!", Color(0.6, 0.95, 1.0), true)
			stage.hud.say("A spirit is freed from its lantern (%d / %d)." % [freed, carriers_total])
	if rules.has("protect"):
		var mem2 := _find(String(rules.protect))
		if mem2 != null and mem2.is_down():
			stage.battle.outcome = BattleController.Outcome.ONGOING  # a win that came by felling the memorial is no win
			_end(BattleController.Outcome.LOST)
			return
	if rules.get("king_must_live", false):
		var king := stage.battle.deployment.king
		if king != null and king.is_down():
			_end(BattleController.Outcome.LOST)
			return
	var ev: Dictionary = rules.get("event", {})
	if not ev.is_empty() and not _event_done:
		var u := _find(String(ev.unit))
		if u != null and u.hp * 100 <= u.max_hp() * int(ev.below):
			_event_done = true
			_drain_off = true
			_play_event(u, ev)
	if rules.has("win_unless"):
		var rest: Array = stage.battle.enemies.filter(func(e): return not rules.win_unless.has(e.data.display_name))
		if not rest.is_empty() and rest.all(func(e): return e.is_down()):
			_end(BattleController.Outcome.WON)
	if rules.has("win_when_down"):
		var key := String(rules.win_when_down)
		var group: Array = stage.battle.enemies.filter(func(e): return _is(e, key) or e.data.display_name == key)
		if not group.is_empty() and group.all(func(e): return e.is_down()):
			if escaped <= int(rules.get("carriers", {}).get("allowed", 0)):
				_end(BattleController.Outcome.WON)
	refresh_objective()


func _play_event(u: BattleUnit, ev: Dictionary) -> void:
	stage.hud.say(String(ev.get("banner", "")))
	var line: Array = ev.get("line", [])
	if not line.is_empty() and stage.animate:
		stage.bark.say(line[0], line[1], line[2], 2.6)
	for st in ev.get("status", {}):  # a second phase that is resolve, not corruption (the Last King): a ward and haste for a few turns
		u.add_status(String(st), int(ev.status[st]))
	var v: UnitView3D = stage.views.get(u)
	if v == null or not stage.animate or String(ev.get("fx", "counter")) == "none":
		return
	# the Fade Clock badge over the apparatus shakes and breaks: Lyra pushes against the bond
	var l := Label3D.new()
	l.text = "6"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = HudStyle.font(true)
	l.font_size = 160
	l.pixel_size = 0.0085
	l.outline_size = 22
	l.modulate = Color(0.6, 0.9, 1.0)
	l.no_depth_test = true
	l.position = v.position + Vector3(0, 2.1, 0)
	stage.board.add_child(l)
	var base := l.position
	var tw := stage.create_tween()
	for i in 14:
		tw.tween_property(l, "position", base + Vector3(randf_range(-0.14, 0.14), randf_range(-0.06, 0.06), 0), 0.05)
		if i % 2 == 1:
			tw.tween_callback(func(): l.text = str(maxi(0, int(l.text) - 1)))
	tw.tween_callback(func(): v.spawn_fx("burst", v.position + Vector3(0, 0.8, 0), 1.8))
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3(2.4, 2.4, 2.4), 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(l.queue_free)
