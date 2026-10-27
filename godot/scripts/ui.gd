class_name UI
## Theme and small widgets shared by the screens. Colors match the web version's CSS.

const BG := Color("#14171d")
const PANEL := Color("#1d222b")
const PANEL2 := Color("#262c37")
const LINE := Color("#353d4b")
const FG := Color("#ece6d6")
const MUTED := Color("#9aa1ad")
const BRASS := Color("#d6a94e")
const OK := Color("#7ed39a")
const BAD := Color("#ef7a6a")
const WARN := Color("#e8c060")
const BLUE := Color("#6aaefc")
const RED := Color("#ff7a68")

static var _theme: Theme


static func box(bg: Color, border := LINE, radius := 8, pad := 10, bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", FG)
	t.set_color("font_color", "Button", FG)
	t.set_color("font_hover_color", "Button", FG)
	t.set_color("font_pressed_color", "Button", FG)
	t.set_color("font_focus_color", "Button", FG)
	t.set_color("font_disabled_color", "Button", Color(FG, .45))
	t.set_stylebox("normal", "Button", box(PANEL2, LINE, 8, 10))
	t.set_stylebox("hover", "Button", box(PANEL2.lightened(.06), LINE, 8, 10))
	t.set_stylebox("pressed", "Button", box(PANEL2.darkened(.15), BRASS, 8, 10))
	t.set_stylebox("disabled", "Button", box(Color(PANEL2, .45), Color(LINE, .45), 8, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, .96), LINE, 12, 10))
	t.set_stylebox("panel", "Panel", box(Color(PANEL, .96), LINE, 12, 10))
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, LINE, 4, 2, 0))
	_theme = t
	return t


static func label(text: String, size := 15, color := FG, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		b.add_theme_stylebox_override("normal", box(Color("#c89a48"), Color("#e8c47a"), 8, 10))
		b.add_theme_stylebox_override("hover", box(Color("#d4a654"), Color("#e8c47a"), 8, 10))
		b.add_theme_stylebox_override("pressed", box(Color("#b8893a"), Color("#e8c47a"), 8, 10))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color("#231a0b"))
	b.pressed.connect(cb)
	return b


## A tappable row: title, small description, optional value on the right.
static func opt(title: String, sub: String, right: String, cb: Callable, disabled := false, tag := "", tag_col := WARN) -> Control:
	var row := OptRow.new(disabled)
	row.pressed.connect(cb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(label(title, 15))
	if tag != "":
		top.add_child(label(tag, 12, tag_col))
	v.add_child(top)
	if sub != "":
		v.add_child(label(sub, 12, MUTED, true))
	h.add_child(v)
	if right != "":
		var r := label(right, 13, MUTED)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(r)
	row.add_child(h)
	return row


## Panel that acts like a button and sizes itself to wrapped text (a Button does not).
## Ignores releases after a drag so scrolling a list does not pick a row.
class OptRow extends PanelContainer:
	signal pressed
	var disabled := false
	var _down = null

	func _init(disabled_ := false) -> void:
		disabled = disabled_
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.LINE, 8, 10))
		if disabled:
			modulate = Color(1, 1, 1, .45)

	func _gui_input(e: InputEvent) -> void:
		if disabled or not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_down = e.global_position
			add_theme_stylebox_override("panel", UI.box(UI.PANEL2.darkened(.15), UI.BRASS, 8, 10))
		else:
			add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.LINE, 8, 10))
			if _down != null and e.global_position.distance_to(_down) < 12:
				pressed.emit()
			_down = null


static func hbar(pct: float, col: Color, h := 6) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, .5)
	bg.custom_minimum_size = Vector2(0, h)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := ColorRect.new()
	fg.color = col
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fg.anchor_bottom = 1
	fg.anchor_right = clampf(pct, 0, 1)
	bg.add_child(fg)
	return bg


static func spacer(w := 0, h := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Unit portrait: the battle sprite on a rounded tile, framed in the team color.
class Portrait extends Control:
	var bu: Dictionary
	var team := -1
	var art := Art.new(self)

	func _init(unit_or_bu: Dictionary, px := 34, team_ := -1) -> void:
		bu = unit_or_bu if unit_or_bu.has("u") else {"u": unit_or_bu, "id": unit_or_bu.id, "race": unit_or_bu.race, "job": unit_or_bu.job, "mon": unit_or_bu.mon, "s": Rules.calc_stats(unit_or_bu), "x": 0}
		team = team_ if team_ >= 0 else bu.get("team", -1)
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		art.begin(0)
		var border := UI.LINE if team < 0 else (UI.BLUE if team == 0 else UI.RED)
		draw_style_box(UI.box(Color("#22272f"), border, int(size.x * .2), 0, 2), Rect2(Vector2.ZERO, size))
		var k := size.x / 34.0
		# Frame the head for people; whole body, nudged left, for the wide monsters.
		var wide: bool = bu.mon in ["wolfhound", "sandmaw", "ooze"]
		var z := k * (1.0 if wide else 1.0)
		art.save()
		art.translate(size.x * (.42 if wide else .5), size.y * (.8 if wide else 1.22))
		art.scale(z, z)
		art.sprite(bu, false)
		art.restore()


## Button with a drawn icon (no font glyphs needed): rotl, rotr, plus, minus, menu,
## or an arrow nw/ne/sw/se.
class IconButton extends Button:
	var kind := ""

	func _init(kind_: String, cb: Callable, px := 44) -> void:
		kind = kind_
		custom_minimum_size = Vector2(px, px)
		pressed.connect(cb)
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var c := size / 2
		var r := size.x * .22
		var col := UI.FG
		var w := 2.5
		match kind:
			"plus":
				draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, w)
				draw_line(c - Vector2(0, r), c + Vector2(0, r), col, w)
			"minus":
				draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, w)
			"menu":
				for i in [-1, 0, 1]:
					draw_line(c + Vector2(-r, i * r * .6), c + Vector2(r, i * r * .6), col, 2)
			"rotl", "rotr":
				var a0 := -PI * .9 if kind == "rotl" else -PI * .1
				var a1 := PI * .4 if kind == "rotl" else PI * 1.4
				draw_arc(c, r, a0, a1, 20, col, w, true)
				var tip := c + Vector2(cos(a0), sin(a0)) * r
				var dirv := Vector2(-sin(a0), cos(a0)) * (-1 if kind == "rotl" else 1)
				var side := dirv.orthogonal()
				draw_colored_polygon(PackedVector2Array([tip + dirv * 6, tip - side * 5, tip + side * 5]), col)
			"nw", "ne", "sw", "se":
				var d := Vector2(-1 if kind[1] == "w" else 1, -1 if kind[0] == "n" else 1).normalized()
				var tip := c + d * r * 1.2
				draw_line(c - d * r, tip - d * 4, col, 3)
				var side := d.orthogonal()
				draw_colored_polygon(PackedVector2Array([tip, tip - d * 9 + side * 6, tip - d * 9 - side * 6]), col)
