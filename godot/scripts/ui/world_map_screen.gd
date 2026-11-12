class_name WorldMapScreen
extends Control
## The world map (laid out for a 16:9 screen): a chart of places (WorldMapArt) and a panel for the chosen one. Places open one at
## a time, as the story unlocks them (WorldData). Pick an open place, then a map in it, then a level, and the battle starts.
## A map is locked until its story mission has been played once; then it can be replayed, with no story beats, your real party
## and everything the enemies give kept, and nothing new unlocks (WorldData). The base is a place too: it opens the base, a place
## to walk around in.
## Click a place or use Left/Right and Enter; Esc goes back one step.

signal level_started(map_id: String, level: int)

static var last_place: StringName = &""  ## the place that was open when the map was left (kept for the next visit)

@export var go_on := true  ## false in the checks: record the request instead of changing scene
@export var resume_story := true  ## plays a pending post-battle story on opening (CampaignState.pending_story); false in the checks
var game: SaveGame
var art: WorldMapArt
var selected: StringName = &""
var picked_map := ""  ## the map whose levels are showing ("" = the map list)
var panel: PanelContainer
var title: Label
var body: VBoxContainer
var hint: Label
var start_requests: Array = []  ## [map id, level] for the tests (start_level also changes the scene)
var _entries: Array[Button] = []


func _ready() -> void:
	if game == null:
		game = GameSession.current()
	if resume_story and WorldData.resume_pending_story(get_tree(), game):  # a story owed by a won mission (the game closed before it played)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = HudStyle.theme()
	art = WorldMapArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.unlocked = func(id): return is_open(id)
	add_child(art)
	_build_panel()
	var head := Label.new()
	head.text = "WORLD MAP"
	head.add_theme_font_override("font", HudStyle.font(true, true))
	head.add_theme_font_size_override("font_size", 38)
	head.add_theme_color_override("font_color", Color("#f3e6c4"))
	head.add_theme_constant_override("outline_size", 10)
	head.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	head.position = Vector2(56, 36)
	add_child(head)
	hint = Label.new()
	hint.text = "Click a place  ·  Left / Right to move  ·  Enter to open  ·  Esc to go back"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.75))
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(56, size.y - 52)
	add_child(hint)
	var start := last_place
	if start == &"" or not is_open(start):
		start = _newest_open()
	select(start)


func is_open(id: StringName) -> bool:
	return game.campaign.is_area_unlocked(id)


func _newest_open() -> StringName:
	var open := game.campaign.areas_unlocked
	return open[open.size() - 1] if not open.is_empty() else &""


## The open places, left to right on the chart.
func open_places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in WorldData.PLACES:
		if is_open(p.id):
			out.append(p)
	out.sort_custom(func(a, b): return a.pos.x < b.pos.x)
	return out


func select(id: StringName) -> void:
	selected = id
	picked_map = ""
	art.selected = id
	if id != &"" and is_open(id):
		last_place = id
	_refresh()


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HudStyle.box(Color(0.04, 0.06, 0.11, 0.88), Color(0.91, 0.78, 0.47, 0.6), 10, 2, 26, 22))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -600
	panel.offset_right = -48
	panel.offset_top = -330
	panel.offset_bottom = 330
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	title = Label.new()
	title.add_theme_font_override("font", HudStyle.font(true, true))
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", HudStyle.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	col.add_child(HudStyle.divider())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)


func _refresh() -> void:
	for c in body.get_children():
		c.queue_free()
	_entries.clear()
	panel.visible = selected != &""
	if selected == &"":
		return
	var p := WorldData.place(selected)
	if not is_open(selected):
		title.text = "Not yet reached"
		_text("The way there is not open. The story will open it.")
		return
	title.text = p.name
	_text(p.blurb)
	if p.kind == "base":
		var b := _button("Enter the base", 0)
		b.pressed.connect(enter_base)
		body.add_child(b)
		_entries.append(b)
		return
	if p.maps.is_empty():
		_text("Nothing to fight here yet.")
		return
	if picked_map == "":
		_text("Choose a map.")
		for m in p.maps:
			var state := WorldData.map_state(game.campaign, m.id)
			var best := game.campaign.best_grade(m.id)  # the best grade a battle here has earned (BattleRating)
			var b := _button("%s   ·   %s%s" % [m.name, _state_text(state, m), "   ·   Best: %s" % best if best != "" else ""], 0)
			b.disabled = state == "locked"
			b.pressed.connect(open_map.bind(m.id))
			body.add_child(b)
			_entries.append(b)
	else:
		var m := WorldData.map(picked_map)
		_text(m.name)
		_text(m.blurb)
		var best_here := game.campaign.best_grade(picked_map)
		if best_here != "":
			_text("Best grade: %s.%s" % [best_here, "" if best_here == "S" else " A better one pays more bonus XP."])
		if m.get("skirmish", false):
			_text("Skirmish: your party as it is now, against foes of the level you pick. Whatever they give (XP, relics) is yours.")
		elif WorldData.map_state(game.campaign, picked_map) == "mission":
			_text("Story mission: your party as it is now. Winning it opens the next map. (The story is not written yet, so it starts from here.)")
		else:
			_text("Replay: your party as it is now, no story. Whatever the enemies give (XP, relics) is yours, and nothing new unlocks.")
		var i := 1
		for l in m.levels:
			var b := _button(l, 0)
			b.pressed.connect(start_level.bind(picked_map, i))
			body.add_child(b)
			_entries.append(b)
			i += 1
		var back := _button("Back", 0)
		back.pressed.connect(close_map)
		body.add_child(back)


func _state_text(state: String, _m: Dictionary) -> String:
	match state:
		"cleared":
			return "replay"
		"mission":
			return "story mission"
	return "play its story mission first"


func open_map(map_id: String) -> void:
	picked_map = map_id
	_refresh()


func close_map() -> void:
	picked_map = ""
	_refresh()


func enter_base() -> void:
	if not is_open(WorldData.BASE):
		return
	start_requests.append(["base", 0])
	if go_on:
		get_tree().change_scene_to_file("res://scenes/base_area.tscn")


## Starts a level of a map (the battle scene starts; `start_requests` records it for the tests).
func start_level(map_id: String, level: int) -> void:
	start_requests.append([map_id, level])
	level_started.emit(map_id, level)
	if go_on and is_inside_tree():
		WorldData.start(get_tree(), game, map_id, level)


func _text(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", HudStyle.TEXT)
	body.add_child(l)


func _button(t: String, _w: int) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 54)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var id := art.pick(e.position - art.position)
		if id != &"":
			select(id)
			accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_RIGHT, KEY_LEFT:
			var open := open_places()
			if open.is_empty():
				return
			var i := -1
			for k in open.size():
				if open[k].id == selected:
					i = k
			i = clampi(i + (1 if e.keycode == KEY_RIGHT else -1), 0, open.size() - 1) if i >= 0 else 0
			select(open[i].id)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not _entries.is_empty() and picked_map == "" and WorldData.place(selected).get("kind", "") == "base":
				enter_base()
		KEY_ESCAPE:
			if picked_map != "":
				close_map()
