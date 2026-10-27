extends Node
## Battle scene controller: the turn loop, player commands and enemy turns (from
## js/ui.js). Rules live in rules.gd; the battlefield in world.gd; the UI in hud.gd.

static var stage := 0  ## story mission index, set by the title screen
static var auto := false  ## AI plays both sides (screenshots and soak tests)

signal _turn_done

var B: Dictionary
var mode := "idle"
var actor = null
var ab_id := ""
var center = null
var reach_r = null

@onready var world: BattleWorld = $World
@onready var hud: Hud = $HUD
@onready var sky: TextureRect = $Backdrop/Sky


func _ready() -> void:
	var party := Rules.new_party()
	for u in party:
		while u.lv < 1 + stage * 2:
			u.lv += 1
			Rules.grow(u, Data.JOBS[u.job].g)
	B = Rules.mission_battle(stage, party, {"potion": 6, "phoenix": 2, "antidote": 2})
	world.setup(B)
	var g: Gradient = (sky.texture as GradientTexture2D).gradient
	var cols: Array = world.sky_colors()
	g.set_color(0, cols[0])
	g.set_color(1, cols[1])
	world.tile_tapped.connect(_on_tap)
	hud.rotate_pressed.connect(func(d): world.rotate_view(d))
	hud.zoom_pressed.connect(func(f): world.zoom_by(f))
	hud.menu_pressed.connect(_battle_menu)
	hud.set_law(B.law.ban, B.law.fav)
	battle_loop()


func sleep(ms: float) -> void:
	await get_tree().create_timer(ms / 1000.0 / (2.0 if auto else 1.0)).timeout


# ---------- turn loop ----------
func battle_loop() -> void:
	hud.toast(B.mission.name)
	world.intro()
	await sleep(1500)
	while not B.over:
		var a = Rules.next_actor(B)
		if a == null:
			break
		actor = a
		world.set_active(a)
		world.center_on(a.x, a.y)
		draw_order()
		var stt := Rules.start_turn(B, a)
		await play_events(stt.ev)
		if Rules.check_end(B):
			break
		if not stt.skip and not a.ko:
			if a.team == 0 and not auto:
				await player_turn(a)
			else:
				await enemy_turn(a)
		if not a.ko and not a.jailed:
			Rules.end_turn(B, a)
			if a.get("removed"):
				hud.toast("%s fades from the field (Remove)" % a.name)
				Rules.check_end(B)
		elif a.ko:
			a.ct = 0
	world.set_active(null)
	world.set_highlights({})
	await sleep(400)
	var won: bool = B.over == 1
	for u in B.units:
		if u.team == (0 if won else 1) and Rules.alive(u):
			world.view_of(u).play("victory")
	var loot := ""
	if not B.loot.is_empty():
		loot = "\nLoot: " + ", ".join(B.loot.keys().map(func(k): return Data.LOOT[k].name))
	hud.show_end(won, "%s  ·  %d foes defeated%s" % [B.mission.name, B.kos, loot], [
		{"text": "Fight again", "primary": true, "cb": func(): get_tree().reload_current_scene()},
		{"text": "Missions", "cb": func(): get_tree().change_scene_to_file("res://scenes/title.tscn")}])


func draw_order() -> void:
	var list := Rules.turn_order(B, 8)
	if actor != null and (list.is_empty() or not is_same(list[0], actor)):
		list.push_front(actor)
	hud.set_order(list)


# ---------- player turn ----------
func player_turn(_a: Dictionary) -> void:
	mode = "menu"
	show_menu()
	await _turn_done


func _finish_turn() -> void:
	mode = "idle"
	world.hide_facing()
	hud.clear_bottom()
	_turn_done.emit()


func show_menu() -> void:
	var a: Dictionary = actor
	world.set_highlights({})
	world.set_cursor(null)
	world.hide_facing()
	mode = "menu"
	world.set_marker(null)
	var can_act: bool = not a.acted and not Rules.st(a, "disable")
	var undo: bool = a.moved and not a.acted and (a.x != a.start.x or a.y != a.start.y)
	hud.hide_target()
	hud.hint("")
	hud.show_status(a)
	hud.set_commands([
		{"text": "Move", "cb": bmove, "disabled": not Rules.can_move(a), "primary": true},
		{"text": "Act", "cb": bact, "disabled": not can_act},
		{"text": "Vessel" if Rules.objs_in_reach(B, a).is_empty() else "Vessel (%d)" % Rules.objs_in_reach(B, a).size(), "cb": bvessel, "disabled": not a.vessel and Rules.objs_in_reach(B, a).is_empty()},
		{"text": "Throw", "cb": bthrow, "disabled": not can_act or Rules.throwables(B, a).is_empty()},
		{"text": "Wait", "cb": bwait},
		{"text": "Undo" if undo else "Find", "cb": bundo if undo else func(): world.center_on(actor.x, actor.y)}])


## Taking a field object into the vessel is free: it does not use the move or the action.
func bvessel() -> void:
	var a: Dictionary = actor
	var objs := Rules.objs_in_reach(B, a)
	var rows := []
	for o in objs:
		var it: Dictionary = o.item
		rows.append({"text": "%s: %s, %s  [%s; %s]  (%d tiles)" % [it.name, Data.AB[it.skill].name, Data.AB[it.basic].name, Rules.bonus_text(it), Rules.title_text(it.title), absi(o.x - a.x) + absi(o.y - a.y)], "cb": func(): await grab(o.id)})
	rows.append({"text": "Back", "cb": show_menu, "primary": true})
	hud.hint("Holding: %s. Take an object (free). It vanishes after the battle; use each skill %d times to keep it." % ["%s [%s]" % [a.vessel.name, Rules.bonus_text(a.vessel)] if a.vessel else "nothing", Rules.SK_NEED])
	hud.set_commands(rows)


var throw_pick = null  ## {kind, id, name} while choosing where to throw


## Lift and throw: pick what to lift, then tap where it lands (or throw it off the map).
func bthrow() -> void:
	var rows := []
	for t in Rules.throwables(B, actor):
		var pick: Dictionary = t
		rows.append({"text": "Lift " + t.name, "cb": func(): bthrow_target(pick)})
	rows.append({"text": "Back", "cb": show_menu, "primary": true})
	hud.hint("Lift a unit or object next to you, then throw it (uses your action).")
	hud.set_commands(rows)


func bthrow_target(pick: Dictionary) -> void:
	throw_pick = pick
	mode = "throw"
	var h := {}
	var a: Dictionary = actor
	var r := int(ceil(Rules.THROW_R))
	for y in range(roundi(a.y) - r, roundi(a.y) + r + 1):
		for x in range(roundi(a.x) - r, roundi(a.x) + r + 1):
			if Rules.can_land(B, a, pick.kind, pick.id, x, y):
				h[Rules.key(x, y)] = Color(1, .8, .3, .45)
	world.set_highlights(h)
	var rows := []
	var ob = Rules.ob_point(B, a)
	if ob != null and pick.kind == "unit":
		rows.append({"text": "Off the map!", "cb": func(): do_throw(ob[0], ob[1]), "primary": true})
	rows.append({"text": "Cancel", "cb": show_menu})
	hud.hint("Throw %s: tap a yellow spot%s. Every throw costs the unit 10%% HP (never below 30%%)." % [pick.name, " or throw it off the map" if ob != null else ""])
	hud.set_commands(rows)


func do_throw(x: float, y: float) -> void:
	var a: Dictionary = actor
	mode = "busy"
	world.set_highlights({})
	world.set_marker(null)
	hud.clear_bottom()
	world.view_of(a).act("attack")
	await play_events(Rules.throw(B, a, throw_pick.kind, throw_pick.id, x, y))
	if B.over or a.jailed or a.ko:
		_finish_turn()
	elif a.moved or not Rules.can_move(a):
		bwait()
	else:
		show_menu()


## A thrown unit flies in an arc and lands with a thud.
func throw_anim(e: Dictionary) -> void:
	if e.kind != "unit":
		return
	var u = bu_by_id(e.what)
	var t0 = Rules.tile_at(B, e.fx, e.fy)
	var t1 = Rules.tile_at(B, e.x, e.y)
	var h0: float = t0.h if t0 != null else 0.0
	var h1: float = t1.h if t1 != null else -4.0
	var view := world.view_of(u)
	u.flying = true
	var start := Time.get_ticks_msec()
	var dur := 520.0 / (2.0 if auto else 1.0)
	while true:
		var p: float = min(1.0, (Time.get_ticks_msec() - start) / dur)
		u.vx = e.fx + (e.x - e.fx) * p
		u.vy = e.fy + (e.y - e.fy) * p
		u.vh = h0 + (h1 - h0) * p
		u.hop = sin(p * PI) * 40.0
		if e.ob:
			view.modulate.a = 1.0 - p
		if p >= 1:
			break
		await get_tree().process_frame
	u.hop = 0.0
	u.flying = false
	view.modulate.a = 1.0
	if not e.ob:
		u.vh = h1
		world.shake(3)


func grab(obj_id: String) -> void:
	await play_events(Rules.pickup(B, actor, obj_id))
	show_menu()


func show_inspect(u: Dictionary) -> void:
	var line := "Atk %d  Def %d  Mag %d  Res %d  Spd %d  Move %d  Jump %d  Eva %d" % [Rules.eff(u, "atk"), Rules.eff(u, "def"), Rules.eff(u, "mag"), Rules.eff(u, "res"), roundi(Rules.speed(u)), Rules.eff(u, "mv"), Rules.eff(u, "jp"), Rules.eff(u, "ev")]
	hud.show_status(u, line)
	hud.set_commands([{"text": "Back", "cb": bback, "primary": true}])


func bback() -> void:
	if mode == "menu":
		show_menu()
	elif mode == "target":
		show_target_panel()


func bmove() -> void:
	var a: Dictionary = actor
	mode = "move"
	reach_r = Rules.reach(B, a)
	var h := {}
	for v in reach_r.out.values():
		if v.d > 0:
			h[Rules.key(v.x, v.y)] = Color(.35, .7, 1, .5)
	world.set_highlights(h)
	hud.hint("Tap anywhere in the blue area to move  ·  Move %d  Jump %d" % [Rules.eff(a, "mv"), Rules.eff(a, "jp")])
	hud.set_commands([{"text": "Cancel", "cb": show_menu}])


func bundo() -> void:
	var a: Dictionary = actor
	a.x = a.start.x
	a.y = a.start.y
	a.f = a.start.f
	a.vx = a.x
	a.vy = a.y
	a.vh = float(Rules.tile_at(B, a.x, a.y).h)
	a.moved = false
	show_menu()


func act_groups(a: Dictionary) -> Array:
	var groups := [{"name": "Basic", "ids": ["fight"]}]
	for s in Rules.action_sets(a.u, a):
		groups.append({"name": s.name, "ids": s.list})
	var items := []
	for k in Data.CONS:
		if B.inv.get(k, 0) > 0:
			items.append("item:" + k)
	if not items.is_empty():
		groups.append({"name": "Items", "ids": items})
	groups.append({"name": "Judge", "ids": ["combo"]})
	return groups


func bact() -> void:
	var a: Dictionary = actor
	var groups := []
	for gp in act_groups(a):
		if gp.ids.is_empty():
			continue
		var rows := []
		for id in gp.ids:
			var ab: Dictionary = Rules.ability_for(id)
			var why := Rules.blocked(B, a, ab)
			var ban: bool = B.law and Rules.law_match(B.law.ban, a, ab, a.x, a.y) and Data.LAWS[B.law.ban].k != "ranged"
			var fav: bool = B.law and Rules.law_match(B.law.fav, a, ab, a.x, a.y) and Data.LAWS[B.law.fav].k != "ranged"
			var cost := ("x%d" % B.inv[ab.cons]) if ab.get("cons") else ("%d MP" % Rules.mp_cost(a, ab)) if Rules.mp_cost(a, ab) else ""
			var pick_id: String = id
			rows.append({"name": ab.name, "desc": why if why != "" else ab.get("desc", ""), "cost": cost, "disabled": why != "",
				"tag": "Banned" if ban else "Favored" if fav else "", "tag_col": Color("#ff8a7a") if ban else Color("#8fe39a"), "cb": func(): bpick(pick_id)})
		groups.append({"name": gp.name, "rows": rows})
	hud.open_list(a.name + "  ·  Act", groups, close_sheet)


func close_sheet() -> void:
	hud.close_list()


func bpick(id: String) -> void:
	close_sheet()
	var a: Dictionary = actor
	var ab: Dictionary = Rules.ability_for(id)
	ab_id = id
	center = null
	mode = "target"
	var h := {}
	for p in Rules.range_tiles(B, a, ab):
		h[Rules.key(p[0], p[1])] = Color(1, .45, .3, .45) if ab.tgt == "foe" else Color(.4, .9, .55, .45)
	world.set_highlights(h)
	world.set_marker(null)
	if typeof(ab.rng) != TYPE_STRING and ab.rng == 0:
		center = [a.x, a.y]
		set_area()
	show_target_panel()


func set_area() -> void:
	var a := {}
	if center != null:
		for p in Rules.area_tiles(B, Rules.ability_for(ab_id), center[0], center[1]):
			a[Rules.key(p[0], p[1])] = true
	world.set_highlights(world.hl, a)


func show_target_panel() -> void:
	var a: Dictionary = actor
	var ab: Dictionary = Rules.ability_for(ab_id)
	hud.hide_status()
	if center == null:
		hud.hide_target()
		hud.hint("%s  ·  tap a unit or a spot in range" % ab.name)
		hud.set_commands([{"text": "Cancel", "cb": show_menu}])
		return
	hud.hint("")
	var ts := Rules.targets_of(B, a, ab, center[0], center[1])
	var rows := []
	for t in ts:
		var p := Rules.predict(B, a, ab, t)
		var eff := ""
		match ab.fx:
			"atk", "mag", "drain": eff = "%d dmg" % p.amt
			"heal": eff = "+%d HP" % -p.amt
			"mpdmg": eff = "%d MP dmg" % p.amt
			"raise": eff = "Revive"
		if p.has("stCh") and ab.get("st"):
			eff += ("  " if eff != "" else "") + "/".join(ab.st.map(func(s): return Data.STATUS[s].name)) + " %d%%" % p.stCh
		var show_hit: bool = ab.fx == "atk" or ab.fx == "steal"
		rows.append({"name": t.name, "team": t.team, "text": ("%d%%  " % roundi(p.hit) if show_hit else "") + (eff if eff != "" else ab.name)})
	var warn := ""
	if Rules.breaks_law(B, a, ab, center[0], center[1]):
		warn = "Breaks the law: " + ("red card" if a.cards else "yellow card")
	hud.show_target(ab.name, warn, rows)
	hud.set_commands([{"text": "Confirm", "cb": do_act, "disabled": ts.is_empty(), "primary": true}, {"text": "Cancel", "cb": show_menu}])


func do_act() -> void:
	var a: Dictionary = actor
	mode = "busy"
	world.set_highlights({})
	world.set_marker(null)
	hud.clear_bottom()
	await perform(a, ab_id, center[0], center[1])
	if B.over or a.jailed or a.ko:
		_finish_turn()
		return
	if a.moved or not Rules.can_move(a):
		bwait()
	else:
		show_menu()


## Runs an ability with its pose, spell circle and banner, then plays the events.
func perform(a: Dictionary, id: String, cx: float, cy: float) -> void:
	var ab: Dictionary = Rules.ability_for(id)
	var magic: bool = ab.cat == "mag" or ab.fx in ["mag", "heal", "raise", "buff", "debuff", "cure", "quick"]
	a.f = Rules.face_toward(a, cx, cy)
	world.view_of(a).act("cast" if magic else "attack")
	if id != "fight":
		hud.banner(ab.name)
	if magic:
		var el = Rules.element_of(a, ab)
		world.spell_circle(a, Color(Data.ELEMENTS[el]) if el else Color("#9fd8ff") if ab.fx != "heal" else Color("#8af0a0"))
		await sleep(380)
	else:
		await sleep(160)
	await play_events(Rules.perform(B, a, id, cx, cy))


func bwait() -> void:
	mode = "face"
	world.set_highlights({})
	world.show_facing(actor)
	hud.hint("Choose a facing: tap a tile in that direction. Foes behind you hit more often.")
	hud.show_status(actor)
	hud.set_commands([{"text": "Done", "cb": func(): bface(actor.f), "primary": true}, {"text": "Back", "cb": show_menu}])


func bface(f: int) -> void:
	actor.f = f
	if mode == "face":
		_finish_turn()


func _battle_menu() -> void:
	hud.open_list("Battle", [{"name": "", "rows": [
		{"name": "Retreat", "desc": "Leave the battle. Counts as a defeat.", "cb": _flee},
		{"name": "How to play", "desc": "Move, then Act. Side and back attacks hit more often. Breaking the day's law earns a card; two cards mean jail. Defeat every foe to win.", "cb": close_sheet},
		{"name": "Missions", "desc": "Back to the mission list.", "cb": func(): get_tree().change_scene_to_file("res://scenes/title.tscn")}]}], close_sheet)


func _flee() -> void:
	close_sheet()
	for u in B.units:
		if u.team == 0:
			u.ko = true
	B.over = -1
	if mode != "idle":
		_finish_turn()


func _on_tap(x: float, y: float) -> void:
	match mode:
		"move":
			# the reachable spot nearest the tap, if it is close enough
			var best = null
			var bd := .6
			for v in reach_r.out.values():
				var d := Rules.pdist(v.x, v.y, x, y)
				if d < bd:
					best = v
					bd = d
			if best != null:
				do_move(best.x, best.y)
		"target":
			var ab: Dictionary = Rules.ability_for(ab_id)
			var u = Rules.unit_at(B, x, y)
			var p := [u.x, u.y] if u != null else [Rules.snap(x), Rules.snap(y)]
			if not Rules.in_range(B, actor, ab, p[0], p[1]):
				if u != null:
					show_inspect(u)
				return
			if center != null and Rules.pdist(center[0], center[1], p[0], p[1]) < .3 and not Rules.targets_of(B, actor, ab, p[0], p[1]).is_empty():
				do_act()
				return
			center = p
			world.set_marker(center, Color("#ffb08a") if ab.tgt == "foe" else Color("#a8f0b0"))
			set_area()
			show_target_panel()
		"throw":
			var p := [Rules.snap(x), Rules.snap(y)]
			if Rules.can_land(B, actor, throw_pick.kind, throw_pick.id, p[0], p[1]):
				do_throw(p[0], p[1])
		"face":
			if Rules.pdist(x, y, actor.x, actor.y) > .2:
				actor.f = Rules.face_toward(actor, x, y)
				world.show_facing(actor)
		"menu":
			var u = Rules.unit_at(B, x, y)
			if u != null:
				show_inspect(u)


# ---------- movement and enemy turns ----------
func move_anim(u: Dictionary, path: Array) -> void:
	var v := world.view_of(u)
	v.play("walk")
	for i in range(1, path.size()):
		var p0: Array = path[i - 1]
		var p1: Array = path[i]
		var h0: float = Rules.tile_at(B, p0[0], p0[1]).h
		var h1: float = Rules.tile_at(B, p1[0], p1[1]).h
		u.f = Rules.face_toward({"x": p0[0], "y": p0[1], "f": u.f}, p1[0], p1[1])
		var step := Rules.pdist(p0[0], p0[1], p1[0], p1[1])
		var dur := (190.0 if h0 != h1 else 150.0 * step) / (2.0 if auto else 1.0)
		var t0 := Time.get_ticks_msec()
		while true:
			var p: float = min(1.0, (Time.get_ticks_msec() - t0) / dur)
			u.vx = p0[0] + (p1[0] - p0[0]) * p
			u.vy = p0[1] + (p1[1] - p0[1]) * p
			u.vh = h0 + (h1 - h0) * p
			u.hop = sin(p * PI) * (12.0 if h0 != h1 else 3.0)
			if p >= 1:
				break
			await get_tree().process_frame
	u.hop = 0.0
	u.vx = u.x
	u.vy = u.y
	u.vh = float(Rules.tile_at(B, u.x, u.y).h)
	v.play("idle")


func do_move(x: float, y: float) -> void:
	var a: Dictionary = actor
	var path := Rules.path_to(reach_r, x, y)
	var f: int = a.f
	mode = "busy"
	world.set_highlights({})
	hud.hint("")
	hud.set_commands([])
	Rules.move_unit(B, a, x, y)
	a.f = f
	await move_anim(a, path)
	if a.acted:
		bwait()
	else:
		show_menu()


func enemy_turn(a: Dictionary) -> void:
	hud.show_status(a)
	hud.set_commands([])
	await sleep(350)
	var p := Rules.ai_plan(B, a)
	if p.x != a.x or p.y != a.y:
		var R := Rules.reach(B, a)
		var path := Rules.path_to(R, p.x, p.y)
		var h := {}
		for q in path:
			h[Rules.key(q[0], q[1])] = Color(1, .45, .3, .35)
		world.set_highlights(h)
		await sleep(220)
		world.set_highlights({})
		Rules.move_unit(B, a, p.x, p.y)
		world.center_on(p.x, p.y)
		await move_anim(a, path)
	if p.id and p.id.begins_with("throw:"):
		world.center_on(a.x, a.y)
		world.view_of(a).act("attack")
		await play_events(Rules.perform(B, a, p.id, p.cx, p.cy))
	elif p.id:
		var ab: Dictionary = Rules.ability_for(p.id)
		var ar := {}
		for q in Rules.area_tiles(B, ab, p.cx, p.cy):
			ar[Rules.key(q[0], q[1])] = true
		world.set_highlights({}, ar)
		world.center_on(p.cx, p.cy)
		await sleep(450)
		world.set_highlights({})
		await perform(a, p.id, p.cx, p.cy)
	if not a.ko and not a.jailed:
		var f = Rules.nearest_foe(B, a)
		if f != null:
			a.f = Rules.face_toward(a, f.x, f.y)
	await sleep(200)


func bu_by_id(id) -> Variant:
	for u in B.units:
		if u.id == id:
			return u
	return null


func play_events(ev: Array) -> void:
	for e in ev:
		var u = bu_by_id(e.id) if e.has("id") else null
		match e.type:
			"act":
				var ab = Rules.ability_for(e.ab)
				if ab == null:
					ab = Rules.FIGHT
				if u != null and e.ab == "fight" and not is_same(u, actor):
					world.view_of(u).act("attack")  # counterattacks
				var col := Color(Data.ELEMENTS[e.el]) if e.get("el") else Color("#8af0a0") if ab.fx in ["heal", "raise"] else Color("#ffe08a") if ab.fx == "buff" else Color("#c8a0ff") if ab.fx == "debuff" else Color("#fff4e0")
				for q in Rules.area_tiles(B, ab, e.tx, e.ty):
					world.burst(q[0], q[1], col, "mag" if ab.cat == "mag" or ab.fx == "mag" or ab.fx in ["heal", "buff", "debuff", "cure", "raise"] else "hit")
				await sleep(240)
			"msg":
				hud.log_msg(e.text)
				if e.text == "Critical!":
					world.shake(6)
			"dmg":
				world.view_of(u).flash()
				if not u.ko and u.hp > 0:
					world.view_of(u).act("hit")
				world.view_of(u).refresh()
				world.float_text(u, str(e.v), Color("#ffffff"), e.v >= u.s.mhp * .3)
				if e.v >= u.s.mhp * .3:
					world.shake(4)
				await sleep(150)
			"heal":
				world.view_of(u).refresh()
				world.float_text(u, "+%d" % e.v, Color("#7ef09a"))
				await sleep(120)
			"mp":
				world.float_text(u, ("+" if e.v > 0 else "") + "%d MP" % e.v, Color("#8ac8ff"))
				await sleep(100)
			"prof":
				world.float_text(u, "%s %s Lv %d" % [Data.PROFS[e.pf], "MP" if e.kind == "mp" else "", e.lv], Color("#ffd36a"))
				await sleep(120)
			"miss":
				world.float_text(u, "Miss", Color("#c8c8c8"))
				await sleep(120)
			"status":
				world.view_of(u).refresh()
				world.float_text(u, Data.STATUS[e.s].name, Color(Data.STATUS[e.s].col))
				await sleep(140)
			"ko":
				world.view_of(u).set_ko(true)
				world.float_text(u, "KO", Color("#ff6a5a"), true)
				world.shake(5)
				await sleep(300)
			"raise":
				world.view_of(u).set_ko(false)
				world.float_text(u, "Revived", Color("#7ef09a"))
			"jp":
				world.float_text(u, "+%d JP" % e.v, Color("#ffd36a"))
				await sleep(100)
			"throw":
				await throw_anim(e)
				if e.ob:
					world.float_text(u, "Out of bounds!", Color("#ff9a6a"), true)
					await sleep(300)
			"pickup":
				world.float_text(u, e.name, Color("#ffd36a"))
				await sleep(200)
			"learn":
				world.float_text(u, "Learned %s!" % Data.AB[e.skill].name, Color("#ffd36a"), true)
				await sleep(400)
			"lvup":
				world.view_of(u).refresh()
				world.float_text(u, "LEVEL UP!", Color("#ffd36a"), true)
				world.view_of(u).play("victory")
				get_tree().create_timer(.9).timeout.connect(func(): if not B.over: world.view_of(u).play("idle"))
				await sleep(250)
			"card":
				hud.toast(("Red card! %s is jailed" if e.red else "Yellow card: %s") % u.name)
				await sleep(700)
	draw_order()
	for u in B.units:
		world.view_of(u).refresh()
	if actor != null and mode in ["busy", "idle"]:
		hud.show_status(actor)
