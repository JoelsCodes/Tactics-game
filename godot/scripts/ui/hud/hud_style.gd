class_name HudStyle
extends RefCounted
## The look of the HUD and the menus, built in code for a 16:9 desktop screen (layouts are made at
## 1920x1080 and scale with the window): stone/wood nine-slice panels with bronze rim, gold trim and a
## translucent glass center (textures from tools/art/build_ui.py), Cinzel headings, Lato body text. Colors for sides and bars live here too.

const GLASS := Color(0.045, 0.06, 0.12, 0.84)
const GLASS_LIGHT := Color(0.09, 0.12, 0.22, 0.9)
const LINE := Color(0.72, 0.78, 0.9, 0.45)
const GOLD := Color("#e9c777")
const INK := Color("#1b1405")
const TEXT := Color("#eef0f6")
const MUTED := Color("#9aa6c4")
const LEADER := Color("#e9c777")
const VESSEL := Color("#7fe3ff")
const ENEMY := Color("#ff7a6a")
const HP := Color("#5fd38a")
const SP := Color("#5fa8ff")
const XP := Color("#e9c777")
const BACKDROP := Color("#10131c")  ## menu screens

## Font sizes at 1920x1080.
const UI_DIR := "res://assets/ui/"
const FONT_DIR := "res://assets/fonts/"
const FONT := 20
const FONT_SMALL := 16
const FONT_TITLE := 26
const FONT_HEADING := 36


static func box(bg: Color, border := LINE, radius := 8, width := 1, pad_x := 14, pad_y := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	s.anti_aliasing = true
	return s


static func tex(path: String, margin: int, content := Vector4(-1, -1, -1, -1), tint := Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(UI_DIR + path)
	s.set_texture_margin_all(margin)
	s.modulate_color = tint
	s.content_margin_left = content.x if content.x >= 0 else margin
	s.content_margin_top = content.y if content.y >= 0 else margin
	s.content_margin_right = content.z if content.z >= 0 else margin
	s.content_margin_bottom = content.w if content.w >= 0 else margin
	return s


## The big framed panel: stone (default) or dark wood, bronze rim, gold trim and a glass center.
## Which frame the theme's panels use: false = stone, true = dark walnut.
static var wood_panels := false


static func panel(wood := false, pad_x := 40, pad_y := 34) -> StyleBoxTexture:
	return tex("panel_wood.png" if wood or wood_panels else "panel_stone.png", 40, Vector4(pad_x, pad_y, pad_x, pad_y))


static func button_box(state: String) -> StyleBoxTexture:
	return tex("button_%s.png" % state, 20, Vector4(22, 9, 22, 9))


static func font(bold := false, display := false) -> Font:
	var f: String
	if display:
		f = "Cinzel-Bold.ttf" if bold else "Cinzel-Medium.ttf"
	else:
		f = "Lato-Bold.ttf" if bold else "Lato-Regular.ttf"
	return load(FONT_DIR + f)


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", button_box(st))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", font(true))
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("#fff3d0"))
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.35))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "ItemList", box(Color(0.02, 0.025, 0.05, 0.55), Color(GOLD, 0.28), 5, 1, 8, 8))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(Color(GOLD, 0.2), Color(GOLD, 0.85), 4, 1, 6, 4))
	t.set_stylebox("selected_focus", "ItemList", box(Color(GOLD, 0.26), GOLD, 4, 1, 6, 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color("#fff3d0"))
	t.set_constant("v_separation", "ItemList", 10)
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", FONT_SMALL)
	t.set_color("font_color", "SmallLabel", MUTED)
	t.set_type_variation("SectionLabel", "Label")
	t.set_font("font", "SectionLabel", font(true, true))
	t.set_font_size("font_size", "SectionLabel", FONT_SMALL)
	t.set_color("font_color", "SectionLabel", GOLD)
	t.set_constant("outline_size", "SectionLabel", 0)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font(true, true))
	t.set_font_size("font_size", "TitleLabel", FONT_TITLE)
	t.set_color("font_color", "TitleLabel", Color("#f4e3b8"))
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", font(true, true))
	t.set_font_size("font_size", "HeadingLabel", FONT_HEADING)
	t.set_color("font_color", "HeadingLabel", Color("#f4e3b8"))
	return t


## A framed bar: bronze-rimmed dark track and a glossy fill tinted `fill`.
static func bar(fill: Color, height := 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = maxi(height, 14)
	b.add_theme_stylebox_override("background", tex("bar_back.png", 7, Vector4(0, 0, 0, 0)))
	b.add_theme_stylebox_override("fill", tex("bar_fill.png", 6, Vector4(0, 0, 0, 0), fill))
	return b


## Frosted glass for a panel drawn over the game (shaders/ui_glass.gdshader): the blurred game shows
## through the panel's glass center.
static func glass_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ui_glass.gdshader")
	return m


## Gives every textured panel under `root` the frosted-glass material.
static func frost_panels(root: Node) -> void:
	for c in root.get_children():
		if c is PanelContainer and (c as Control).get_theme_stylebox("panel") is StyleBoxTexture:
			(c as Control).material = glass_material()
		frost_panels(c)


## A portrait frame: the gold bevel ring (assets/ui/portrait_frame.png) tinted `col`, over dark glass.
static func portrait_box(col: Color, pad := 4) -> StyleBoxTexture:
	return tex("portrait_frame.png", 14, Vector4(pad, pad, pad, pad), col)


## The full-screen moody backdrop for menu screens.
static func backdrop() -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(UI_DIR + "menu_bg.jpg")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


## An ornate gold rule between menu sections.
static func divider() -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(UI_DIR + "divider.png")
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	r.custom_minimum_size.y = 16
	return r


## A section heading for menus (small gold capitals).
static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = &"SectionLabel"
	return l


static func team_color(bu: BattleUnit) -> Color:
	match TurnManager.group_of(bu):
		TurnManager.Group.LEADER:
			return LEADER
		TurnManager.Group.VESSEL:
			return VESSEL
	return ENEMY
