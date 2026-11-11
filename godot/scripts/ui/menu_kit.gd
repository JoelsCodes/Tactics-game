class_name MenuKit
extends RefCounted
## The look of the out-of-battle menus (owner, Nov 2026: "a polished, commercially released fantasy tactical RPG"): dark navy and charcoal
## panels with antique-gold trim and decorative corners, muted teal accents, warm parchment text; Cinzel titles, Lato for numbers. Every
## menu builds from these pieces so they look and behave the same (the Company Headquarters, BarracksScreen, is the reference).
## Mouse, keyboard and controller all work through Godot's focus (ui_* actions include the gamepad); every interactive piece has
## normal, hover, focus, pressed/selected and disabled looks and a short tween. The game has no audio system yet, so there are no UI sounds.

const NAVY := Color("#0c1222")
const NAVY_2 := Color("#131b30")
const CHARCOAL := Color("#16171c")
const GOLD := Color("#c9a45c")
const GOLD_BRIGHT := Color("#ecd08a")
const GOLD_DIM := Color("#7d6638")
const TEAL := Color("#4fa3a0")
const TEAL_DIM := Color("#2a5a5c")
const PARCHMENT := Color("#e8dcc0")
const PARCHMENT_DIM := Color("#a89c84")
const SHADOW := Color(0, 0, 0, 0.55)
const HP := Color("#6cbf7f")
const SP := Color("#5b9bd5")
const XP := Color("#d8b45f")

## Sizes come from Typography (one place); these names stay for the many menus that already use them.
const TITLE := 44
const HEADING := 28
const BODY := 19
const SMALL := 16
const ANIM := 0.14  ## seconds for hover, focus and selection tweens


## A layered panel: a navy face, a thin gold rim, a soft drop shadow. `raised` is a lighter face for cards on a panel.
static func panel_box(raised := false, pad := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = NAVY_2 if raised else Color(NAVY, 0.94)
	s.border_color = Color(GOLD_DIM, 0.9)
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.shadow_color = SHADOW
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	s.set_content_margin_all(pad)
	return s


## Button looks for a state: normal, hover, focus, pressed (also "selected") and disabled.
static func button_box(state: String) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(2)
	s.set_content_margin_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	match state:
		"hover":
			s.bg_color = Color("#1d2842")
			s.border_color = GOLD
		"focus":
			s.bg_color = Color(0, 0, 0, 0)
			s.border_color = GOLD_BRIGHT
			s.draw_center = false
		"pressed":
			s.bg_color = Color("#2a2414")
			s.border_color = GOLD_BRIGHT
		"disabled":
			s.bg_color = Color(CHARCOAL, 0.8)
			s.border_color = Color(GOLD_DIM, 0.35)
		_:
			s.bg_color = Color("#151d33")
			s.border_color = Color(GOLD_DIM, 0.85)
	s.set_border_width_all(2 if state == "focus" else 1)
	return s


static func font(bold := false, display := false) -> Font:
	return HudStyle.font(bold, display)


## The theme every menu uses: buttons, labels, scroll bars and panels in the kit's look.
static func theme() -> Theme:
	var t := HudStyle.theme()  # keeps the existing type variations (HeadingLabel, SmallLabel) the sub-menus use
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", button_box(st))
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_focus_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	t.set_color("font_disabled_color", "Button", Color(PARCHMENT_DIM, 0.5))
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	return t


static func label(text: String, size := BODY, color := PARCHMENT, bold := false, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font(bold, display))
	return l


## A section title in small gold capitals with a fading rule under it.
static func heading(text: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var l := Typography.label(text, Typography.Role.SECTION, GOLD)  # Cinzel Bold, mixed case
	v.add_child(l)
	v.add_child(Rule.new())
	return v


## A framed panel with gold corner ornaments. Add content to `.body` (returned as the second element).
static func frame(raised := false, pad := 18) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(raised, pad))
	var corners := Corners.new()
	corners.inset = pad - 4  # the ornaments sit on the panel's own corners, outside its padding
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	p.add_child(body)
	p.add_child(corners)  # drawn over the face, under nothing interactive (it ignores the mouse)
	return [p, body]


## A thin stat bar with a dark track and a value label beside it.
static func stat_bar(caption: String, value: int, max_value: int, fill: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := label(caption, SMALL, PARCHMENT_DIM, true)
	cap.custom_minimum_size.x = 30
	row.add_child(cap)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(max_value, 1)
	bar.value = clampi(value, 0, maxi(max_value, 1))
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(GOLD_DIM, 0.4)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	var num := label("%d / %d" % [value, max_value] if max_value > 0 else "max", SMALL, PARCHMENT, true)
	num.custom_minimum_size.x = 92
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num)
	return row


## A key hint for the footer: a small framed key cap and what it does.
static func hint(key: String, what: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var cap := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#1b2236")
	s.border_color = GOLD_DIM
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", s)
	cap.add_child(label(key, SMALL, GOLD_BRIGHT, true))
	h.add_child(cap)
	h.add_child(label(what, SMALL, PARCHMENT_DIM))
	return h


## Fades and slides a page in: the panel transition every menu uses.
static func reveal(c: Control, dx := 18.0) -> void:
	if not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	if c.get_parent() is Container:  # a container places its children itself: fade only, never move them
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.2)
		return
	var to := c.position
	c.position = to + Vector2(dx, 0)
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_property(c, "position", to, 0.2)


## Gives a control a gentle brighten on hover and focus (immediate feedback for mouse, keyboard and pad).
static func liven(c: Control) -> void:
	var up := func():
		c.create_tween().tween_property(c, "modulate", Color(1.12, 1.1, 1.04), ANIM)
	var down := func():
		if not c.has_focus():
			c.create_tween().tween_property(c, "modulate", Color.WHITE, ANIM)
	c.mouse_entered.connect(up)
	c.focus_entered.connect(up)
	c.mouse_exited.connect(down)
	c.focus_exited.connect(func(): c.create_tween().tween_property(c, "modulate", Color.WHITE, ANIM))


## The backdrop every menu sits on: the menu painting darkened under a navy wash, with a soft vignette.
static func backdrop() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := HudStyle.backdrop()
	bg.modulate = Color(0.45, 0.5, 0.62)
	root.add_child(bg)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(NAVY, 0.72)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)
	var vig := Vignette.new()
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	return root


## A list in the kit's look: navy rows, gold selection, a hover glow, room to breathe.
static func style_list(l: ItemList) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.28)
	bg.border_color = Color(GOLD_DIM, 0.45)
	bg.set_border_width_all(1)
	bg.set_content_margin_all(10)
	l.add_theme_stylebox_override("panel", bg)
	l.add_theme_stylebox_override("focus", button_box("focus"))
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color("#2a2414")
	sel.border_color = GOLD_BRIGHT
	sel.border_width_left = 3
	sel.set_content_margin_all(9)  # room around a row's text so the selection never touches it
	l.add_theme_stylebox_override("selected", sel)
	l.add_theme_stylebox_override("selected_focus", sel)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color("#1a2440")
	l.add_theme_stylebox_override("hovered", hov)
	var cur := StyleBoxFlat.new()
	cur.draw_center = false
	cur.border_color = Color(GOLD, 0.7)
	cur.set_border_width_all(1)
	l.add_theme_stylebox_override("cursor", cur)
	l.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	l.add_theme_color_override("font_color", PARCHMENT)
	l.add_theme_color_override("font_selected_color", GOLD_BRIGHT)
	l.add_theme_color_override("font_hovered_color", Color.WHITE)
	l.add_theme_color_override("guide_color", Color(GOLD_DIM, 0.18))
	l.add_theme_font_size_override("font_size", BODY)
	l.add_theme_constant_override("v_separation", 22)  # a list row is the text plus 22 px: about 50 px at 1080p (was 10: about 38)
	l.add_theme_constant_override("line_separation", 4)
	l.focus_mode = Control.FOCUS_ALL


## The colour of a skill rank, E (plain) to S (bright gold).
static func rank_color(rank: int) -> Color:
	return [PARCHMENT_DIM, PARCHMENT, TEAL, Color("#8fb8ff"), GOLD, GOLD_BRIGHT][clampi(rank, 0, 5)]


## A member's identity plate for a menu's header: a gold-rimmed portrait, name, role and level.
static func unit_plate(u: UnitData) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	if u == null:
		return h
	var frame := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#0a0f1c")
	s.border_color = GOLD if u.is_human() else TEAL
	s.set_border_width_all(2)
	s.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", s)
	var t := TextureRect.new()
	t.texture = UnitLook.portrait(UnitLook.sheet_for(u))
	t.custom_minimum_size = Vector2(60, 60)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(t)
	h.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(label(u.display_name, HEADING, GOLD_BRIGHT if u.is_human() else TEAL, true, true))
	v.add_child(label("%s  ·  LV %d" % [u.role_name(), u.level], SMALL + 1, PARCHMENT_DIM, true))
	h.add_child(v)
	return h


## The shell every sub-screen uses (Mentorship, Skills, Equipment): backdrop, a header with Back, the title and the member's plate, a gold rule,
## the body row and a footer of hints. Returns {back, title, subtitle, plate, body, footer}.
static func screen(root: Control, heading_text: String) -> Dictionary:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme()
	root.add_child(backdrop())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	var back := Button.new()
	back.text = "‹  Back"
	back.custom_minimum_size = Vector2(150, 50)
	liven(back)
	head.add_child(back)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := label(heading_text, TITLE - 4, GOLD_BRIGHT, true, true)
	t.clip_text = true
	titles.add_child(t)
	var sub := label("", SMALL + 1, TEAL, true)
	titles.add_child(sub)
	head.add_child(titles)
	var plate := HBoxContainer.new()
	head.add_child(plate)
	page.add_child(head)
	page.add_child(Rule.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	page.add_child(Rule.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 26)
	page.add_child(footer)
	return {"back": back, "title": t, "subtitle": sub, "plate": plate, "body": body, "footer": footer}


## A framed column in a screen's body with a heading; `width` 0 lets it share the free space (by `ratio`). Returns its content box.
static func column(body: Control, heading_text: String, width := 0, ratio := 1.0) -> VBoxContainer:
	var f := frame(false, 20)
	if width > 0:
		f[0].custom_minimum_size.x = width
	else:
		f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f[0].size_flags_stretch_ratio = ratio
	body.add_child(f[0])
	if heading_text != "":
		f[1].add_child(heading(heading_text))
	return f[1]


## Puts a member's plate into a screen's header slot (replacing what was there).
static func set_plate(slot: Control, u: UnitData) -> void:
	for c in slot.get_children():
		c.queue_free()
	slot.add_child(unit_plate(u))


## Fills a footer with key hints: [[key, what], ...].
static func set_hints(footer: Control, hints: Array) -> void:
	for c in footer.get_children():
		c.queue_free()
	for h in hints:
		footer.add_child(hint(h[0], h[1]))


## The detail text of a menu: parchment body text that wraps.
static func body_text() -> Label:
	var l := label("", BODY, PARCHMENT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## The main action button of a screen (Study, Equip): taller, bright gold text.
static func action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 62)
	Typography.apply(b, Typography.Role.BODY_STRONG)  # a gameplay button: Inter SemiBold in sentence case, a little larger
	b.add_theme_font_size_override("font_size", Typography.size(Typography.Role.BODY_STRONG) + 4)
	liven(b)
	return b


## A soft dark vignette at the screen's edges.
class Vignette extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var steps := 14
		for i in steps:
			var a := 0.035 * (1.0 - float(i) / steps)
			var inset := i * 10.0
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(0, 0, 0, a), false, 10.0)


## Gold corner ornaments drawn over a panel.
class Corners extends Control:
	var color := GOLD
	var arm := 16.0
	var inset := 0.0  ## how far outside this control's rect the panel's edge is (the panel's padding)

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var x0 := -inset
		var y0 := -inset
		var w := size.x + inset
		var h := size.y + inset
		var c := Color(color, 0.9)
		for p in [[Vector2(x0, y0), Vector2(1, 1)], [Vector2(w, y0), Vector2(-1, 1)], [Vector2(x0, h), Vector2(1, -1)], [Vector2(w, h), Vector2(-1, -1)]]:
			var o: Vector2 = p[0] + p[1] * 3.0
			var d: Vector2 = p[1]
			draw_line(o, o + Vector2(arm * d.x, 0), c, 2.0)
			draw_line(o, o + Vector2(0, arm * d.y), c, 2.0)
			draw_rect(Rect2(o + d * 5.0 - Vector2(2, 2), Vector2(4, 4)), GOLD_BRIGHT)  # a small stud inside the corner


## A thin gold rule that fades out to the right.
class Rule extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 2)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var steps := 24
		for i in steps:
			var a := 1.0 - float(i) / steps
			draw_rect(Rect2(size.x * i / steps, 0, size.x / steps + 1, 1), Color(GOLD, 0.8 * a))
