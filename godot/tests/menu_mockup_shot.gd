extends Node
## Mockups (owner, Nov 2026): the new main-menu Roster page (a party list, a vertical portrait strip with stats, equipment and skills; no party picking) and the
## Formation pop-up that opens before a battle (layout A: the company on the left, the battle party's slots on the right, Fight). Pictures only, sample data.
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/menu_mockup_shot.tscn -- out=/tmp/menus
const M := [
	{"name": "Alaric", "sheet": "king", "role": "King", "lv": 12, "hp": [58, 58], "sp": [14, 16], "style": "Rook  ·  Impact", "party": true},
	{"name": "Bram", "sheet": "warden", "role": "Warden", "lv": 11, "hp": [64, 64], "sp": [9, 10], "style": "Pawn  ·  Axe", "party": true},
	{"name": "Lyra", "sheet": "mira", "role": "Co-Captain", "lv": 11, "hp": [41, 41], "sp": [18, 20], "style": "Bishop  ·  Pierce", "party": true},
	{"name": "Gideon", "sheet": "gideon", "role": "Knight", "lv": 9, "hp": [52, 52], "sp": [8, 9], "style": "Knight  ·  Impact", "party": true},
	{"name": "Kaelen", "sheet": "kaelen", "role": "Archer", "lv": 9, "hp": [38, 38], "sp": [12, 12], "style": "Rook  ·  Pierce", "party": false},
	{"name": "Merc", "sheet": "merc", "role": "Sellsword", "lv": 8, "hp": [47, 47], "sp": [7, 8], "style": "Pawn  ·  Impact", "party": false},
]
const TABS := ["Roster", "Equipment", "Abilities", "Campaign", "Records", "System"]
var out := "/tmp/menus"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	for v in ["roster", "formation"]:
		var root := Control.new()
		add_child(root)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		call("_" + v, root)
		for i in 6:
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, v])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


# ---------- pieces ----------

func _portrait(sheet: String, size: Vector2, rim: Color, strip := false) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0a0f1c")
	st.border_color = rim
	st.set_border_width_all(2)
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)
	var t := TextureRect.new()
	var tex := UnitLook.portrait(sheet)
	if strip and tex != null:  # a vertical strip: the middle of the portrait, full height
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		var at := AtlasTexture.new()
		at.atlas = tex
		var keep := h * size.x / size.y
		at.region = Rect2((w - keep) * 0.5, 0, keep, h)
		tex = at
	t.texture = tex
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(t)
	return frame


func _bar(value: int, max_value: int, fill: Color, w := 150.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 8)
	var back := ColorRect.new()
	back.color = Color("#070b12")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(back)
	var f := ColorRect.new()
	f.color = fill
	f.position = Vector2.ZERO
	f.size = Vector2(w * clampf(float(value) / maxf(max_value, 1), 0.0, 1.0), 8)
	c.add_child(f)
	return c


func _tabs(root_page: Control, lit: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for t in TABS:
		var b := Button.new()
		b.text = t
		b.custom_minimum_size = Vector2(170, 52)
		b.toggle_mode = true
		b.button_pressed = t == lit
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var ch := VBoxContainer.new()
	ch.add_theme_constant_override("separation", 0)
	ch.add_child(MenuKit.label("Chapter three", MenuKit.SMALL, MenuKit.TEAL, true))
	ch.add_child(MenuKit.label("The Unquiet Dead", MenuKit.BODY, MenuKit.PARCHMENT, true, true))
	row.add_child(ch)
	return row


func _member_row(m: Dictionary, lit: bool) -> Control:
	var f := MenuKit.frame(lit, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_portrait(m.sheet, Vector2(66, 66), MenuKit.GOLD_BRIGHT if lit else MenuKit.GOLD_DIM))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_child(MenuKit.label(m.name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT if lit else MenuKit.PARCHMENT, true, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(MenuKit.label("LV %d" % m.lv, MenuKit.SMALL, MenuKit.TEAL, true))
	v.add_child(top)
	v.add_child(_bar(m.hp[0], m.hp[1], MenuKit.HP, 200))
	v.add_child(_bar(m.sp[0], m.sp[1], MenuKit.SP, 200))
	row.add_child(v)
	f[1].add_child(row)
	if lit:
		f[0].modulate = Color(1.05, 1.1, 1.2)
	return f[0]


func _stat_row(caption: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var c := MenuKit.label(caption, MenuKit.BODY, MenuKit.PARCHMENT_DIM, true)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	h.add_child(MenuKit.label(value, MenuKit.BODY, MenuKit.PARCHMENT, true))
	return h


func _slot(caption: String, text: String) -> Control:
	var f := MenuKit.frame(true, 10)
	f[1].add_theme_constant_override("separation", 2)
	f[1].add_child(MenuKit.label(caption, MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	f[1].add_child(MenuKit.label(text, MenuKit.BODY, MenuKit.GOLD_BRIGHT if text != "Empty" else MenuKit.GOLD_DIM, true))
	f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f[0]


func _skill(name: String, rank: int, kind: String) -> Control:
	var f := MenuKit.frame(true, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var badge := MenuKit.label("EDCBAS"[rank], MenuKit.HEADING - 4, MenuKit.rank_color(rank), true, true)
	badge.custom_minimum_size.x = 30
	h.add_child(badge)
	var n := MenuKit.label(name, MenuKit.BODY, MenuKit.PARCHMENT, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(MenuKit.label(kind, MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	f[1].add_child(h)
	f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f[0]


# ---------- the Roster page ----------

func _roster(root: Control) -> void:
	var s := MenuKit.screen(root, "Roster")
	var page: Control = s.body.get_parent()
	# the screen's title row becomes the tab bar
	var head: Control = page.get_child(0)
	for c in head.get_children():
		c.queue_free()
	var tabs := _tabs(page, "Roster")
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tabs)
	MenuKit.set_hints(s.footer, [["↑ ↓", "Choose member"], ["Q / E", "Change tab"], ["Enter", "Open"], ["Esc", "Back"]])
	# left: the company list
	var left := MenuKit.column(s.body, "Company  ·  6 members", 420, 0.0)
	for i in M.size():
		left.add_child(_member_row(M[i], i == 0))
	# centre: the strip and the numbers
	var mid := MenuKit.column(s.body, "", 0, 1.1)
	var m: Dictionary = M[0]
	var head2 := HBoxContainer.new()
	head2.add_child(MenuKit.label(m.name, MenuKit.TITLE - 8, MenuKit.GOLD_BRIGHT, true, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head2.add_child(sp)
	head2.add_child(MenuKit.label("%s  ·  Level %d" % [m.role, m.lv], MenuKit.BODY, MenuKit.TEAL, true))
	mid.add_child(head2)
	mid.add_child(MenuKit.Rule.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(body)
	var strip := _portrait(m.sheet, Vector2(250, 640), MenuKit.GOLD_BRIGHT, true)
	body.add_child(strip)
	var nums := VBoxContainer.new()
	nums.add_theme_constant_override("separation", 6)
	nums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(nums)
	nums.add_child(MenuKit.stat_bar("HP", 58, 58, MenuKit.HP))
	nums.add_child(MenuKit.stat_bar("SP", 14, 16, MenuKit.SP))
	nums.add_child(MenuKit.stat_bar("XP", 740, 1000, MenuKit.XP))
	nums.add_child(Control.new())
	for r in [["Attack", "21"], ["Defense", "17"], ["Magic", "9"], ["Resistance", "12"], ["Speed", "14"], ["Will", "16"], ["Move", "5"], ["Jump", "3"]]:
		nums.add_child(_stat_row(r[0], r[1]))
		nums.add_child(MenuKit.Rule.new())
	var style := MenuKit.label("Weapon style   " + m.style, MenuKit.BODY, MenuKit.PARCHMENT, true)
	nums.add_child(style)
	# right: equipment and skills
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.custom_minimum_size.x = 500
	s.body.add_child(right)
	var eq := MenuKit.frame(false, 20)
	eq[1].add_child(MenuKit.heading("Equipment"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	eq[1].add_child(g)
	g.add_child(_slot("Main weapon", "Oathblade"))
	g.add_child(_slot("Weapon style", "Rook · Impact"))
	g.add_child(_slot("Relic 1", "Ember Signet"))
	g.add_child(_slot("Relic 2", "Empty"))
	right.add_child(eq[0])
	var sk := MenuKit.frame(false, 20)
	sk[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	sk[1].add_child(MenuKit.heading("Abilities & skills"))
	sk[1].add_child(MenuKit.label("Active", MenuKit.SMALL, MenuKit.TEAL, true))
	sk[1].add_child(_skill("Quick Jab", 0, "Physical"))
	sk[1].add_child(_skill("Shield Prod", 0, "Physical"))
	sk[1].add_child(_skill("Severing Blade", 2, "Physical"))
	sk[1].add_child(MenuKit.label("Learned from enemies", MenuKit.SMALL, MenuKit.TEAL, true))
	sk[1].add_child(_skill("Cinder Bolt", 1, "Elemental"))
	var note := MenuKit.label("Reach and area show in the Abilities tab.", MenuKit.SMALL, MenuKit.PARCHMENT_DIM)
	sk[1].add_child(note)
	right.add_child(sk[0])


# ---------- the Formation pop-up before a battle ----------

func _formation(root: Control) -> void:
	root.theme = MenuKit.theme()
	root.add_child(MenuKit.backdrop())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var f := MenuKit.frame(false, 26)
	f[0].custom_minimum_size = Vector2(1460, 800)
	center.add_child(f[0])
	var head := HBoxContainer.new()
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(MenuKit.label("Formation", MenuKit.TITLE - 8, MenuKit.GOLD_BRIGHT, true, true))
	t.add_child(MenuKit.label("The Riverbank  ·  Battle 2  ·  Your last party is remembered", MenuKit.SMALL + 1, MenuKit.TEAL, true))
	head.add_child(t)
	head.add_child(MenuKit.label("Party  3 / 3", MenuKit.BODY, MenuKit.PARCHMENT, true))
	f[1].add_child(head)
	f[1].add_child(MenuKit.Rule.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	f[1].add_child(body)
	var left := MenuKit.column(body, "Company", 0, 1.25)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	left.add_child(grid)
	for m in M.slice(1):
		grid.add_child(_company_card(m))
	var right := MenuKit.column(body, "Battle party", 500, 0.0)
	right.add_child(_party_slot(M[0], "★", true))
	for i in 3:
		right.add_child(_party_slot(M[1 + i], str(i + 1), false))
	var tip := MenuKit.label("Choose someone on the left to swap them in. Alaric always leads.", MenuKit.SMALL, MenuKit.PARCHMENT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(tip)
	f[1].add_child(MenuKit.Rule.new())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	var back := Button.new()
	back.text = "‹  Back"
	back.custom_minimum_size = Vector2(190, 56)
	foot.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	foot.add_child(MenuKit.label("Enter  Add or remove", MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	var go := MenuKit.action_button("Fight")
	go.custom_minimum_size = Vector2(260, 60)
	foot.add_child(go)
	f[1].add_child(foot)


func _company_card(m: Dictionary) -> Control:
	var f := MenuKit.frame(m.party, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_portrait(m.sheet, Vector2(84, 84), MenuKit.GOLD if m.party else MenuKit.GOLD_DIM))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(MenuKit.label(m.name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT, true, true))
	v.add_child(MenuKit.label("%s  ·  LV %d" % [m.role, m.lv], MenuKit.SMALL, MenuKit.TEAL, true))
	v.add_child(MenuKit.label(m.style, MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
	row.add_child(v)
	f[1].add_child(row)
	var tag := MenuKit.label("IN PARTY" if m.party else "RESERVE", MenuKit.SMALL, MenuKit.GOLD_BRIGHT if m.party else MenuKit.PARCHMENT_DIM, true)
	f[1].add_child(tag)
	f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not m.party:
		f[0].modulate = Color(1, 1, 1, 0.75)
	return f[0]


func _party_slot(m: Dictionary, n: String, fixed: bool) -> Control:
	var f := MenuKit.frame(true, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var num := MenuKit.label(n, MenuKit.HEADING, MenuKit.TEAL if fixed else MenuKit.GOLD, true, true)
	num.custom_minimum_size.x = 34
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(num)
	row.add_child(_portrait(m.sheet, Vector2(64, 64), MenuKit.TEAL if fixed else MenuKit.GOLD))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(MenuKit.label(m.name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT, true, true))
	v.add_child(MenuKit.label("%s  ·  LV %d" % [m.role, m.lv], MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	row.add_child(v)
	if not fixed:
		row.add_child(MenuKit.label("Remove", MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	f[1].add_child(row)
	return f[0]
