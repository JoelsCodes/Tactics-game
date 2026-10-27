extends Control
## Battle screen: the turn loop, player controls and enemy turns from js/ui.js
## (startBattle through tapCanvas). Rules live in rules.gd, drawing in battle_view.gd.

static var stage := 0  ## story mission index, set by the title screen
static var auto := false  ## AI plays both sides (screenshots and soak tests)

signal _turn_done

var B: Dictionary
var view: BattleView
var order_box: HBoxContainer
var law_label: Label
var log_panel: PanelContainer
var log_label: Label
var bottom: PanelContainer
var panel_box: VBoxContainer
var sheet: Control
var sheet_box: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label

# turn state (js BS)
var mode := "idle"
var actor = null
var ab_id := ""
var center = null
var reach_r = null
var _log_tween: Tween


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var party := Rules.new_party()
	for u in party:
		while u.lv < 1 + stage * 2:
			u.lv += 1
			Rules.grow(u, Data.JOBS[u.job].g)
	B = Rules.mission_battle(stage, party, {"potion": 6, "phoenix": 2, "antidote": 2})
	law_label.text = "Banned: %s     Favored: %s" % [_law_text(B.law.ban), _law_text(B.law.fav)]
	await get_tree().process_frame
	view.setup(B)
	battle_loop()


static func _law_text(id) -> String:
	return Data.LAWS[id].name if id else "None"


# ---------- layout ----------
func _build_ui() -> void:
	view = BattleView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.tile_tapped.connect(_on_tap)
	add_child(view)

	# Top bar, free space for the map, bottom panel: a full-screen column.
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 8
	col.offset_bottom = -8
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	order_box = HBoxContainer.new()
	order_box.add_theme_constant_override("separation", 4)
	order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(order_box)
	var lawbar := PanelContainer.new()
	lawbar.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, .85), UI.LINE, 8, 6))
	var lh := HBoxContainer.new()
	law_label = UI.label("", 13, UI.FG)
	law_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	law_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lh.add_child(law_label)
	lh.add_child(UI.IconButton.new("menu", _battle_menu, 34))
	lawbar.add_child(lh)
	col.add_child(lawbar)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	bottom = PanelContainer.new()
	panel_box = VBoxContainer.new()
	bottom.add_child(panel_box)
	col.add_child(bottom)

	var vctl := VBoxContainer.new()
	vctl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	vctl.offset_left = -54
	vctl.offset_right = -8
	vctl.offset_top = -110
	vctl.offset_bottom = 70
	vctl.add_child(UI.IconButton.new("rotl", func(): view.rotate_view(-1)))
	vctl.add_child(UI.IconButton.new("rotr", func(): view.rotate_view(1)))
	vctl.add_child(UI.IconButton.new("plus", func(): view.zoom_by(1.2)))
	vctl.add_child(UI.IconButton.new("minus", func(): view.zoom_by(.83)))
	add_child(vctl)

	var log_row := CenterContainer.new()
	log_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	log_row.offset_top = 104
	log_row.offset_bottom = 140
	log_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, .55), Color(0, 0, 0, 0), 14, 8, 0))
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label = UI.label("", 14)
	log_panel.add_child(log_label)
	log_panel.modulate.a = 0
	log_row.add_child(log_panel)
	add_child(log_row)

	sheet = Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.visible = false
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, .5)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e): if e is InputEventScreenTouch and not e.pressed: close_sheet())
	sheet.add_child(scrim)
	var sp := PanelContainer.new()
	sp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sp.anchor_top = .28
	sp.offset_left = 6
	sp.offset_right = -6
	sp.offset_bottom = -6
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_box = VBoxContainer.new()
	sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sheet_box)
	sp.add_child(scroll)
	sheet.add_child(sp)
	add_child(sheet)

	var toast_row := CenterContainer.new()
	toast_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", UI.box(Color("#3a2e14"), UI.BRASS, 10, 10))
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = UI.label("", 15, UI.WARN)
	toast_panel.add_child(toast_label)
	toast_row.add_child(toast_panel)
	add_child(toast_row)


func set_panel(nodes: Array) -> void:
	for c in panel_box.get_children():
		panel_box.remove_child(c)
		c.queue_free()
	for n in nodes:
		panel_box.add_child(n)
	bottom.visible = not nodes.is_empty()


func sheet_open(title: String, nodes: Array) -> void:
	for c in sheet_box.get_children():
		sheet_box.remove_child(c)
		c.queue_free()
	sheet_box.add_child(UI.label(title, 17, UI.BRASS))
	for n in nodes:
		sheet_box.add_child(n)
	sheet.visible = true


func close_sheet() -> void:
	sheet.visible = false


func log_msg(t: String) -> void:
	log_label.text = t
	log_panel.modulate.a = 1
	if _log_tween:
		_log_tween.kill()
	var tw := create_tween()
	_log_tween = tw
	tw.tween_interval(1.6)
	tw.tween_property(log_panel, "modulate:a", 0.0, .6)


func toast(t: String) -> void:
	toast_label.text = t
	toast_panel.visible = true
	get_tree().create_timer(1.6).timeout.connect(func(): toast_panel.visible = false)


func sleep(ms: float) -> void:
	await get_tree().create_timer(ms / 1000.0 / (2.0 if auto else 1.0)).timeout


# ---------- turn loop (js battleLoop) ----------
func battle_loop() -> void:
	log_msg(B.mission.name if B.mission else "Skirmish at " + B.map.name)
	while not B.over:
		var a = Rules.next_actor(B)
		if a == null:
			break
		actor = a
		view.active = a
		view.center_on(a.x, a.y)
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
		elif a.ko:
			a.ct = 0
	view.active = null
	await sleep(500)
	var won: bool = B.over == 1
	var banner := UI.label("Victory!" if won else "Defeat", 26, UI.OK if won else UI.BAD)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := UI.label("%s · %d foes defeated%s" % [B.mission.name, B.kos, (" · loot: " + ", ".join(B.loot.keys().map(func(k): return Data.LOOT[k].name))) if not B.loot.is_empty() else ""], 13, UI.MUTED, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_child(UI.button("Fight again", func(): get_tree().reload_current_scene(), true))
	row.add_child(UI.button("Missions", func(): get_tree().change_scene_to_file("res://scenes/title.tscn")))
	set_panel([banner, info, row])


func draw_order() -> void:
	for c in order_box.get_children():
		order_box.remove_child(c)
		c.queue_free()
	var list := Rules.turn_order(B, 9)
	if actor != null and (list.is_empty() or not is_same(list[0], actor)):
		list.push_front(actor)
	for i in min(9, list.size()):
		var p := UI.Portrait.new(list[i], 38 if i == 0 else 34)
		order_box.add_child(p)


func unit_panel(u: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.Portrait.new(u, 52))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_child(UI.label(u.name, 16))
	head.add_child(UI.label("Lv %d · %s" % [u.lv, "Monster" if u.mon else Data.JOBS[u.job].name], 13, UI.MUTED))
	if u.jp:
		head.add_child(UI.label("%d JP" % u.jp, 13, UI.WARN))
	if u.cards:
		head.add_child(UI.label("Yellow card", 13, UI.WARN))
	v.add_child(head)
	var pct: float = float(u.hp) / u.s.mhp
	v.add_child(UI.hbar(pct, UI.OK if pct > .5 else UI.WARN if pct > .25 else UI.BAD))
	v.add_child(UI.label("HP %d/%d%s · CT %d" % [u.hp, u.s.mhp, (" · MP %d/%d" % [u.mp, u.s.mmp]) if u.s.mmp else "", max(0, roundi(u.ct))], 13, UI.MUTED))
	if not u.st.is_empty():
		var sts := HFlowContainer.new()
		for k in u.st:
			sts.add_child(UI.label(Data.STATUS[k].name, 12, Color(Data.STATUS[k].col)))
		v.add_child(sts)
	h.add_child(v)
	return h


func cmds(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for b in buttons:
		row.add_child(b)
	return row


func hint(t: String) -> Label:
	return UI.label(t, 13, UI.MUTED, true)


# ---------- player turn ----------
func player_turn(_a: Dictionary) -> void:
	mode = "menu"
	show_menu()
	await _turn_done


func _finish_turn() -> void:
	mode = "idle"
	set_panel([])
	_turn_done.emit()


func show_menu() -> void:
	var a: Dictionary = actor
	clear_hl()
	view.cursor = null
	mode = "menu"
	var can_act: bool = not a.acted and not Rules.st(a, "disable")
	var mv := UI.button("Move", bmove)
	mv.disabled = not Rules.can_move(a)
	var act := UI.button("Act", bact)
	act.disabled = not can_act
	var last: Button
	if a.moved and not a.acted and (a.x != a.start.x or a.y != a.start.y):
		last = UI.button("Undo", bundo)
	else:
		last = UI.button("Find", func(): view.center_on(actor.x, actor.y))
	set_panel([unit_panel(a), cmds([mv, act, UI.button("Wait", bwait), last])])


func clear_hl() -> void:
	view.hl = {}
	view.area = {}


func show_inspect(u: Dictionary) -> void:
	var line := "Atk %d · Def %d · Mag %d · Res %d · Spd %d · Move %d · Jump %d · Eva %d" % [Rules.eff(u, "atk"), Rules.eff(u, "def"), Rules.eff(u, "mag"), Rules.eff(u, "res"), roundi(Rules.speed(u)), Rules.eff(u, "mv"), Rules.eff(u, "jp"), Rules.eff(u, "ev")]
	set_panel([unit_panel(u), UI.label(line, 12, UI.MUTED, true), cmds([UI.button("Back", bback)])])


func bback() -> void:
	if mode == "menu":
		show_menu()
	elif mode == "target":
		show_target_panel()


func bmove() -> void:
	var a: Dictionary = actor
	mode = "move"
	reach_r = Rules.reach(B, a)
	clear_hl()
	for k in reach_r.out:
		if reach_r.out[k].d > 0:
			view.hl[k] = Color(.35, .66, 1, .45)
	set_panel([unit_panel(a), hint("Tap a blue tile to move (Move %d, Jump %d)." % [Rules.eff(a, "mv"), Rules.eff(a, "jp")]), cmds([UI.button("Cancel", show_menu)])])


func bundo() -> void:
	var a: Dictionary = actor
	a.x = a.start.x
	a.y = a.start.y
	a.f = a.start.f
	a.vx = float(a.x)
	a.vy = float(a.y)
	a.vh = float(Rules.tile_at(B, a.x, a.y).h)
	a.moved = false
	show_menu()


func act_groups(a: Dictionary) -> Array:
	var groups := [{"name": "Basic", "ids": ["fight"]}]
	for s in Rules.action_sets(a.u):
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
	var nodes := []
	for gp in act_groups(a):
		if gp.ids.is_empty():
			continue
		nodes.append(UI.label(gp.name, 13, UI.MUTED))
		for id in gp.ids:
			var ab: Dictionary = Rules.ability_for(id)
			var why := Rules.blocked(B, a, ab)
			var ban: bool = B.law and Rules.law_match(B.law.ban, a, ab, a.x, a.y) and Data.LAWS[B.law.ban].k != "ranged"
			var fav: bool = B.law and Rules.law_match(B.law.fav, a, ab, a.x, a.y) and Data.LAWS[B.law.fav].k != "ranged"
			var cost := ("x%d" % B.inv[ab.cons]) if ab.get("cons") else ("%d MP" % Rules.mp_cost(a, ab)) if Rules.mp_cost(a, ab) else ""
			var pick_id: String = id
			nodes.append(UI.opt(ab.name, why if why != "" else ab.get("desc", ""), cost, func(): bpick(pick_id), why != "", "Banned" if ban else "Favored" if fav else "", UI.BAD if ban else UI.OK))
	nodes.append(UI.button("Cancel", close_sheet))
	sheet_open(a.name + ": Act", nodes)


func bpick(id: String) -> void:
	close_sheet()
	var a: Dictionary = actor
	var ab: Dictionary = Rules.ability_for(id)
	ab_id = id
	center = null
	mode = "target"
	clear_hl()
	for p in Rules.range_tiles(B, a, ab):
		view.hl[Rules.key(p[0], p[1])] = Color(1, .47, .31, .42) if ab.tgt == "foe" else Color(.43, .86, .55, .42)
	if typeof(ab.rng) != TYPE_STRING and ab.rng == 0:
		center = [a.x, a.y]
		set_area()
	show_target_panel()


func set_area() -> void:
	view.area = {}
	if center == null:
		return
	for p in Rules.area_tiles(B, Rules.ability_for(ab_id), center[0], center[1]):
		view.area[Rules.key(p[0], p[1])] = true


func show_target_panel() -> void:
	var a: Dictionary = actor
	var ab: Dictionary = Rules.ability_for(ab_id)
	if center == null:
		set_panel([unit_panel(a), hint("%s: tap a highlighted tile to target." % ab.name), cmds([UI.button("Cancel", show_menu)])])
		return
	var ts := Rules.targets_of(B, a, ab, center[0], center[1])
	var nodes := []
	var head := HBoxContainer.new()
	head.add_child(UI.label(ab.name, 16, UI.BRASS))
	if Rules.breaks_law(B, a, ab, center[0], center[1]):
		head.add_child(UI.label("Breaks today's law: " + ("red card (jail)" if a.cards else "yellow card"), 12, UI.BAD))
	nodes.append(head)
	for t in ts:
		var p := Rules.predict(B, a, ab, t)
		var eff := ""
		match ab.fx:
			"atk", "mag", "drain": eff = "%d dmg" % p.amt
			"heal": eff = "+%d HP" % -p.amt
			"mpdmg": eff = "%d MP dmg" % p.amt
			"raise": eff = "Revive"
		if p.has("stCh") and ab.get("st"):
			eff += (" · " if eff != "" else "") + "/".join(ab.st.map(func(s): return Data.STATUS[s].name)) + " %d%%" % p.stCh
		var show_hit: bool = ab.fx == "atk" or ab.fx == "steal"
		var row := HBoxContainer.new()
		var nm := UI.label(t.name, 14, UI.BLUE if t.team == 0 else UI.RED)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UI.label(("%d%% · " % roundi(p.hit) if show_hit else "") + (eff if eff != "" else ab.name), 14))
		nodes.append(row)
	if ts.is_empty():
		nodes.append(hint("No targets there."))
	var go := UI.button("Confirm", do_act, true)
	go.disabled = ts.is_empty()
	nodes.append(cmds([go, UI.button("Cancel", show_menu)]))
	set_panel(nodes)


func do_act() -> void:
	var a: Dictionary = actor
	mode = "busy"
	clear_hl()
	set_panel([unit_panel(a)])
	var ev := Rules.perform(B, a, ab_id, center[0], center[1])
	await play_events(ev)
	if B.over or a.jailed or a.ko:
		_finish_turn()
		return
	if a.moved or not Rules.can_move(a):
		bwait()
	else:
		show_menu()


func bwait() -> void:
	mode = "face"
	clear_hl()
	var a: Dictionary = actor
	# Buttons laid out by screen direction (NW, NE, SW, SE).
	var pos_of := {}
	for f in 4:
		var d := view.screen_dir(f)
		pos_of[("n" if d.y < 0 else "s") + ("w" if d.x < 0 else "e")] = f
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for p in ["nw", "ne", "sw", "se"]:
		var f: int = pos_of[p]
		var b := UI.IconButton.new(p, func(): bface(f), 56)
		if a.f == f:
			b.add_theme_stylebox_override("normal", UI.box(UI.PANEL2, UI.BRASS, 8, 10, 2))
		grid.add_child(b)
	var center_row := HBoxContainer.new()
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_child(grid)
	set_panel([unit_panel(a), hint("Choose a facing. Foes behind you hit more often."), center_row, cmds([UI.button("Back", show_menu)])])


func bface(f: int) -> void:
	actor.f = f
	if mode == "face":
		_finish_turn()


func _battle_menu() -> void:
	sheet_open("Battle", [
		UI.opt("Retreat", "Leave the battle. Counts as a defeat.", "", _flee),
		UI.opt("How to play", "Move, then act. Side and back attacks hit more often. Breaking the day's law earns a card; two cards mean jail. Knock out every foe to win.", "", close_sheet),
		UI.button("Close", close_sheet)])


func _flee() -> void:
	close_sheet()
	for u in B.units:
		if u.team == 0:
			u.ko = true
	B.over = -1
	if mode != "idle":
		_finish_turn()


func _on_tap(x: int, y: int) -> void:
	var k := Rules.key(x, y)
	if mode == "move":
		if view.hl.has(k):
			do_move(x, y)
		return
	if mode == "target":
		if not view.hl.has(k):
			var u = Rules.unit_at(B, x, y)
			if u != null:
				show_inspect(u)
			return
		if center != null and center[0] == x and center[1] == y and not Rules.targets_of(B, actor, Rules.ability_for(ab_id), x, y).is_empty():
			do_act()
			return
		center = [x, y]
		set_area()
		show_target_panel()
		return
	if mode == "menu":
		var u = Rules.unit_at(B, x, y)
		if u != null:
			show_inspect(u)


# ---------- movement and enemy turns ----------
func move_anim(u: Dictionary, path: Array) -> void:
	u.walk = true
	for i in range(1, path.size()):
		var p0: Array = path[i - 1]
		var p1: Array = path[i]
		var h0: float = Rules.tile_at(B, p0[0], p0[1]).h
		var h1: float = Rules.tile_at(B, p1[0], p1[1]).h
		u.f = Rules.face_toward({"x": p0[0], "y": p0[1], "f": u.f}, p1[0], p1[1])
		var dur := 150.0 / (2.0 if auto else 1.0)
		var t0 := Time.get_ticks_msec()
		while true:
			var p: float = min(1.0, (Time.get_ticks_msec() - t0) / dur)
			u.vx = p0[0] + (p1[0] - p0[0]) * p
			u.vy = p0[1] + (p1[1] - p0[1]) * p
			u.vh = h0 + (h1 - h0) * p
			u.hop = sin(p * PI) * 10 if h0 != h1 else 0.0
			if p >= 1:
				break
			await get_tree().process_frame
	u.walk = false
	u.hop = 0.0
	u.vx = float(u.x)
	u.vy = float(u.y)
	u.vh = float(Rules.tile_at(B, u.x, u.y).h)


func do_move(x: int, y: int) -> void:
	var a: Dictionary = actor
	var path := Rules.path_to(reach_r, x, y)
	var f: int = a.f
	mode = "busy"
	clear_hl()
	Rules.move_unit(B, a, x, y)
	a.f = f
	await move_anim(a, path)
	if a.acted:
		bwait()
	else:
		show_menu()


func enemy_turn(a: Dictionary) -> void:
	set_panel([unit_panel(a)])
	await sleep(350)
	var p := Rules.ai_plan(B, a)
	if p.x != a.x or p.y != a.y:
		var R := Rules.reach(B, a)
		var path := Rules.path_to(R, p.x, p.y)
		for q in path:
			view.hl[Rules.key(q[0], q[1])] = Color(1, .47, .31, .3)
		await sleep(200)
		clear_hl()
		Rules.move_unit(B, a, p.x, p.y)
		view.center_on(p.x, p.y)
		await move_anim(a, path)
	if p.id:
		var ab: Dictionary = Rules.ability_for(p.id)
		for q in Rules.area_tiles(B, ab, p.cx, p.cy):
			view.area[Rules.key(q[0], q[1])] = true
		view.center_on(p.cx, p.cy)
		log_msg(a.name + ": " + ab.name)
		await sleep(450)
		clear_hl()
		await play_events(Rules.perform(B, a, p.id, p.cx, p.cy))
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
				if u != null:
					u.hop = 6.0
					get_tree().create_timer(.12).timeout.connect(func(): u.hop = 0.0)
				var col: String = Data.ELEMENTS[e.el] if e.get("el") else "#8af0a0" if ab.fx in ["heal", "raise"] else "#ffe08a" if ab.fx == "buff" else "#c8a0ff" if ab.fx == "debuff" else "#ffffff"
				for q in Rules.area_tiles(B, ab, e.tx, e.ty):
					view.burst(q[0], q[1], col, "mag" if ab.cat == "mag" or ab.fx == "mag" else "hit")
				await sleep(260)
			"msg":
				log_msg(e.text)
			"dmg":
				u.flash = view.now()
				view.float_text(u, str(e.v), "#ffffff")
				await sleep(140)
			"heal":
				view.float_text(u, "+%d" % e.v, "#7ef09a")
				await sleep(120)
			"mp":
				view.float_text(u, ("+" if e.v > 0 else "") + "%d MP" % e.v, "#8ac8ff")
				await sleep(100)
			"miss":
				view.float_text(u, "Miss", "#c8c8c8")
				await sleep(120)
			"status":
				view.float_text(u, Data.STATUS[e.s].name, Data.STATUS[e.s].col)
				await sleep(140)
			"ko":
				view.float_text(u, "KO", "#ff6a5a")
				await sleep(220)
			"raise":
				view.float_text(u, "Revived", "#7ef09a")
			"jp":
				view.float_text(u, "+%d JP" % e.v, "#ffd36a")
				await sleep(100)
			"lvup":
				view.float_text(u, "Level up!", "#ffd36a")
				await sleep(200)
			"card":
				toast(("Red card: %s is jailed" if e.red else "Yellow card: %s") % u.name)
				await sleep(600)
	draw_order()
	if actor != null and not mode in ["menu", "target", "face", "move"]:
		set_panel([unit_panel(actor)])
