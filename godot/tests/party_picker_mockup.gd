extends Node
## Mockups of the barracks party picker (owner, Nov 2026): three layouts of "who fights beside Alaric", drawn with MenuKit and the real portraits, saved as
## a.png, b.png and c.png in the folder given by out=. Pictures only: nothing here is wired to the game.
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/party_picker_mockup.tscn -- out=/tmp/party
const MEMBERS := [
	{"name": "Alaric", "sheet": "king", "role": "King", "lv": 12, "hp": "58 / 58", "style": "Rook  ·  Impact", "fixed": true},
	{"name": "Bram", "sheet": "warden", "role": "Warden", "lv": 11, "hp": "64 / 64", "style": "Pawn  ·  Axe", "in": true},
	{"name": "Lyra", "sheet": "mira", "role": "Co-Captain", "lv": 11, "hp": "41 / 41", "style": "Bishop  ·  Pierce", "in": true},
	{"name": "Gideon", "sheet": "gideon", "role": "Knight", "lv": 9, "hp": "52 / 52", "style": "Knight  ·  Impact", "in": true},
	{"name": "Kaelen", "sheet": "kaelen", "role": "Archer", "lv": 9, "hp": "38 / 38", "style": "Rook  ·  Pierce", "in": false},
	{"name": "Merc", "sheet": "merc", "role": "Sellsword", "lv": 8, "hp": "47 / 47", "style": "Pawn  ·  Impact", "in": false},
]
var out := "/tmp/party_picker"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	for v in ["a", "b", "c"]:
		var root := Control.new()
		add_child(root)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		call("_variant_" + v, root)
		for i in 6:
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


# ---------- shared pieces ----------

func _shell(root: Control, title: String, sub: String, hints: Array) -> Dictionary:
	var s := MenuKit.screen(root, title)
	s.subtitle.text = sub
	MenuKit.set_hints(s.footer, hints)
	return s


func _portrait(m: Dictionary, size: Vector2, rim: Color) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0a0f1c")
	st.border_color = rim
	st.set_border_width_all(2)
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)
	var t := TextureRect.new()
	t.texture = UnitLook.portrait(m.sheet)
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(t)
	return frame


func _badge(text: String, fill: Color, ink: Color) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.set_corner_radius_all(3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	p.add_child(MenuKit.label(text, MenuKit.SMALL, ink, true))
	return p


func _stats(m: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.add_child(MenuKit.label(m.name, MenuKit.HEADING - 4, MenuKit.GOLD_BRIGHT, true, true))
	v.add_child(MenuKit.label("%s  ·  LV %d" % [m.role, m.lv], MenuKit.SMALL, MenuKit.TEAL, true))
	v.add_child(MenuKit.label(m.style, MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
	v.add_child(MenuKit.label("HP  " + m.hp, MenuKit.SMALL, MenuKit.HP, true))
	return v


## A member card on a plate: portrait left, text right. `state` is "in", "out", "full" (dim, can't add) or "fixed".
func _card(m: Dictionary, state: String, width := 0.0) -> Control:
	var f := MenuKit.frame(state in ["in", "fixed"], 12)
	var lit := state in ["in", "fixed"]
	var panel: PanelContainer = f[0]
	if width > 0:
		panel.custom_minimum_size.x = width
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_portrait(m, Vector2(92, 92), MenuKit.GOLD if lit else MenuKit.GOLD_DIM))
	row.add_child(_stats(m))
	f[1].add_child(row)
	if state == "in":
		f[1].add_child(_badge("IN PARTY", MenuKit.GOLD, Color("#0d131a")))
	elif state == "fixed":
		f[1].add_child(_badge("ALWAYS LEADS", MenuKit.TEAL, Color("#0d131a")))
	elif state == "full":
		f[1].add_child(_badge("PARTY FULL", MenuKit.GOLD_DIM, MenuKit.PARCHMENT))
	else:
		f[1].add_child(_badge("RESERVE", MenuKit.NAVY_2, MenuKit.PARCHMENT_DIM))
	if state in ["out", "full"]:
		panel.modulate = Color(1, 1, 1, 0.72)
	return panel


func _counter(text: String, filled: int, of: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(MenuKit.label(text, MenuKit.BODY, MenuKit.PARCHMENT, true))
	for i in of:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 10)
		pip.color = MenuKit.GOLD_BRIGHT if i < filled else MenuKit.GOLD_DIM
		var c := CenterContainer.new()
		c.add_child(pip)
		h.add_child(c)
	return h


# ---------- A: roster on the left, battle slots on the right ----------

func _variant_a(root: Control) -> void:
	var s := _shell(root, "Formation", "Choose who fights beside Alaric", [["Enter", "Add or remove"], ["Q / E", "Change section"], ["Esc", "Back"]])
	var left := MenuKit.column(s.body, "Company  ·  5 members", 0, 1.35)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	left.add_child(grid)
	for m in MEMBERS.slice(1):
		var c := _card(m, "in" if m.get("in", false) else "out")
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	var right := MenuKit.column(s.body, "Battle party", 520, 1.0)
	right.add_child(_counter("Party  3 / 3", 3, 3))
	right.add_child(_slot(MEMBERS[0], 0, true))
	for i in 3:
		right.add_child(_slot(MEMBERS[1 + i], i + 1, false))
	var tip := MenuKit.body_text()
	tip.text = "Select a member on the left to add them, or select a slot to swap. Alaric always leads."
	tip.add_theme_color_override("font_color", MenuKit.PARCHMENT_DIM)
	right.add_child(tip)


func _slot(m: Dictionary, n: int, fixed: bool) -> Control:
	var f := MenuKit.frame(true, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var num := MenuKit.label("★" if fixed else str(n), MenuKit.HEADING, MenuKit.TEAL if fixed else MenuKit.GOLD, true, true)
	num.custom_minimum_size.x = 34
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(num)
	row.add_child(_portrait(m, Vector2(64, 64), MenuKit.TEAL if fixed else MenuKit.GOLD))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(MenuKit.label(m.name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT, true, true))
	v.add_child(MenuKit.label("%s  ·  LV %d" % [m.role, m.lv], MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	if not fixed:
		row.add_child(MenuKit.label("Remove", MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	f[1].add_child(row)
	return f[0]


# ---------- B: one grid, tap to toggle ----------

func _variant_b(root: Control) -> void:
	var s := _shell(root, "Formation", "Tap a member to send them into battle or hold them back", [["Enter", "Toggle"], ["Q / E", "Change section"], ["Esc", "Back"]])
	var col := MenuKit.column(s.body, "Company", 0, 1.0)
	var top := HBoxContainer.new()
	top.add_child(_counter("Party  3 / 3", 3, 3))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(MenuKit.label("Alaric leads every battle.  Full party: remove someone first.", MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
	col.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	col.add_child(grid)
	for m in MEMBERS:
		var st := "fixed" if m.get("fixed", false) else ("in" if m.get("in", false) else "full")
		var c := _card(m, st)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)


# ---------- C: the opening formation on a small board ----------

func _variant_c(root: Control) -> void:
	var s := _shell(root, "Formation", "Place your party for the opening of the battle", [["Enter", "Pick up or set down"], ["Q / E", "Change section"], ["Esc", "Back"]])
	var left := MenuKit.column(s.body, "Opening positions", 0, 1.3)
	left.add_child(MenuKit.label("The party starts in these tiles beside Alaric. Pick someone up, set them on a free tile.", MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
	var board := Control.new()
	board.custom_minimum_size = Vector2(780, 610)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(board)
	var cols := 7
	var rows := 5
	var tile := Vector2(108, 118)
	var cells := {Vector2i(3, 2): 0, Vector2i(2, 1): 1, Vector2i(2, 3): 2, Vector2i(3, 1): 3}
	for y in rows:
		for x in cols:
			var r := ColorRect.new()
			r.position = Vector2(x, y) * tile + Vector2(8, 8)
			r.size = tile - Vector2(4, 4)
			var near := absi(x - 3) <= 1 and absi(y - 2) <= 1
			r.color = Color("#243446") if near else Color("#141d29")
			board.add_child(r)
			if near and not cells.has(Vector2i(x, y)):
				var hint := MenuKit.label("free", MenuKit.SMALL, MenuKit.GOLD_DIM, true)
				hint.position = r.position + Vector2(36, 46)
				board.add_child(hint)
	for c in cells:
		var m: Dictionary = MEMBERS[cells[c]]
		var p := _portrait(m, Vector2(76, 76), MenuKit.TEAL if cells[c] == 0 else MenuKit.GOLD)
		p.position = Vector2(c) * tile + Vector2(20, 12)
		board.add_child(p)
		var n := MenuKit.label(m.name, MenuKit.SMALL, MenuKit.PARCHMENT, true)
		n.position = Vector2(c) * tile + Vector2(22, 92)
		board.add_child(n)
	var right := MenuKit.column(s.body, "Reserve", 470, 1.0)
	right.add_child(_counter("Party  3 / 3", 3, 3))
	for m in MEMBERS.slice(4):
		right.add_child(_card(m, "out"))
	var tip := MenuKit.body_text()
	tip.text = "Drag a reserve onto the board to swap them with someone in the party."
	tip.add_theme_color_override("font_color", MenuKit.PARCHMENT_DIM)
	right.add_child(tip)
