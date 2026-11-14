class_name HudStyle
extends RefCounted
## The look of the HUD and the menus, built in code for a 16:9 desktop screen (layouts are made at
## 1920x1080 and scale with the window): stone/wood nine-slice panels with bronze rim, gold trim and a
## translucent glass center (textures from tools/art/build_ui.py), Cinzel Bold headings, Inter body text (all fonts come from Typography). Colors for sides and bars live here too.

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
## The steel HUD's text colours (docs/mockups/steel_hud): cool white for names and values, a lighter steel blue for headings and caption tabs, muted steel for labels.
const NAME := Color("#f0f6ff")
const CAPTION := Color("#cfe6ff")
const SUBTLE := Color("#9eacbd")
const BODY := Color("#c4d0de")
const ICE := Color("#8fd4ff")

## Font sizes at 1920x1080.
const UI_DIR := "res://assets/ui/"
const FONT := 19  ## the body size (Typography.Role.BODY)
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


## The old two-flag font call, now answered by Typography: `display` is Cinzel Bold, the rest Inter (`bold` is SemiBold).
static func font(bold := false, display := false) -> Font:
	return Typography.legacy(bold, display)


static func theme() -> Theme:
	var t := Theme.new()
	Typography.install(t)  # the fonts and sizes of every control and type variation (Inter for play, Cinzel Bold for headings)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", button_box(st))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
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
	t.set_constant("v_separation", "ItemList", 14)
	t.set_color("font_color", "SmallLabel", MUTED)
	t.set_color("font_color", "TagLabel", MUTED)
	t.set_color("font_color", "SectionLabel", GOLD)
	t.set_constant("outline_size", "SectionLabel", 0)
	t.set_color("font_color", "TitleLabel", Color("#f4e3b8"))
	t.set_color("font_color", "HeadingLabel", Color("#f4e3b8"))
	# tooltips: the same navy and gold as the panels, in Inter
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.04, 0.09, 0.97), Color(GOLD, 0.6), 6, 1, 14, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t


# ---------- the sleek battle HUD (dark smoky glass, thin bronze and gold lines) ----------

const CYAN := Color("#7fe6ff")  ## the acting unit's queue card


const ICON_DIR := "res://assets/ui/icons/"  ## the owner's own icons (override the generated ones)


## True when the owner supplied this command icon (assets/ui/icons/<name>.png).
static func custom_icon(name: String) -> bool:
	return labeled_icon(name) or ResourceLoader.exists(ICON_DIR + name + ".png")


## True when the owner's icon has its own text painted in (assets/ui/icons/<name>_labeled.png): it is
## then the whole button face and the button shows no label of its own. Wins over <name>.png.
static func labeled_icon(name: String) -> bool:
	return ResourceLoader.exists(ICON_DIR + name + "_labeled.png")


## A command icon: the owner's PNG from assets/ui/icons/ if there is one, else the generated
## assets/ui/icon_<name>.png (white, meant to be tinted).
static func icon(name: String) -> Texture2D:
	if labeled_icon(name):
		return load(ICON_DIR + name + "_labeled.png")
	return load(ICON_DIR + name + ".png") if custom_icon(name) else load(UI_DIR + "icon_%s.png" % name)


## The battle HUD's panel: smoky dark-brown glass with a bronze edge and a gold hairline.
static func slim_panel(pad_x := 18, pad_y := 14) -> StyleBoxTexture:
	return tex("steel_panel.png", 16, Vector4(pad_x, pad_y, pad_x, pad_y))  # dark engraved steel (tools/art/build_steel_ui.py; docs/mockups/steel_hud)


## The lit panel: the one thing that glows (the acting unit's card, the open tab).
static func lit_panel(pad_x := 18, pad_y := 14) -> StyleBoxTexture:
	return tex("steel_lit.png", 16, Vector4(pad_x, pad_y, pad_x, pad_y))


static func slot_box(state: String) -> StyleBoxTexture:
	return tex("slot_%s.png" % state, 14, Vector4(10, 8, 10, 8))


## The HUD's small buttons (Surge, Speed, Back, Cancel): a steel hexagon, lit in the icy blue on hover and when pressed, muted when disabled.
static func steel_button_box(state: String) -> StyleBoxTexture:
	var file := "steel_tab.png"
	match state:
		"hover", "pressed", "focus", "hover_pressed":
			file = "steel_tab_lit.png"
		"disabled":
			file = "steel_tab_off.png"
	var s := tex(file, 0, Vector4(22, 6, 22, 6))
	s.texture_margin_left = 17
	s.texture_margin_right = 17
	s.texture_margin_top = 0
	s.texture_margin_bottom = 0
	return s


static func queue_box(now: bool) -> StyleBoxTexture:
	return tex("steel_card_lit.png" if now else "steel_card.png", 12, Vector4(6, 5, 8, 5))


## A thin flat bar (HP / SP lines in the queue and the status card): a near-black track with a cool edge, a bright fill with a lighter top edge.
static func slim_bar(fill: Color, height := 6) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("background", box(Color("#05080c"), Color("#2f3e50"), 1, 1, 0, 0))
	var f := box(fill, Color(fill.lightened(0.3), 0.0), 1, 0, 0, 0)
	f.border_width_top = 1
	f.border_color = fill.lightened(0.35)
	b.add_theme_stylebox_override("fill", f)
	return b


## A caption tab (the label over a card: ACTING, TARGET, FORECAST): a steel hexagon holding a Cinzel label in cool white.
static func plaque(text: String, size := 20) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := tex("steel_tab.png", 0, Vector4(26, 2, 26, 4))
	sb.texture_margin_left = 17
	sb.texture_margin_right = 17
	sb.texture_margin_top = 0
	sb.texture_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.name = "Text"
	l.text = text
	l.add_theme_font_override("font", font(false, true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CAPTION)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## The battle HUD's theme: the menu theme with the sleek panel and slim buttons.
static func hud_theme() -> Theme:
	var t := theme()
	t.set_stylebox("panel", "PanelContainer", slim_panel())
	t.set_stylebox("panel", "Panel", slim_panel())
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "Button", steel_button_box(st))
	t.set_color("font_color", "Button", Color("#a9b6c6"))
	t.set_color("font_hover_color", "Button", Color("#f4f9ff"))
	t.set_color("font_pressed_color", "Button", Color("#f4f9ff"))
	t.set_color("font_focus_color", "Button", Color("#f4f9ff"))
	t.set_color("font_disabled_color", "Button", Color("#69737f"))
	return t


## A framed bar (XP, skill progress): a near-black track with a cool steel edge and a bright fill with a lighter top edge, `height` tall (at least 14).
static func bar(fill: Color, height := 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = maxi(height, 14)
	b.add_theme_stylebox_override("background", box(Color("#05080c"), Color("#3a4a5e"), 2, 1, 0, 0))
	var f := box(fill, fill, 2, 0, 0, 0)
	f.border_width_top = 2
	f.border_color = fill.lightened(0.4)
	b.add_theme_stylebox_override("fill", f)
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
	return tex("steel_portrait.png", 14, Vector4(pad, pad, pad, pad), col)


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
	r.texture = load(UI_DIR + "steel_divider.png")
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	r.custom_minimum_size.y = 12
	return r


## A section heading for menus (small gold capitals).
static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text  # mixed case: Cinzel Bold already reads as a heading, capitals on top were shouting
	l.theme_type_variation = &"SectionLabel"
	return l


static func team_color(bu: BattleUnit) -> Color:
	match TurnManager.group_of(bu):
		TurnManager.Group.LEADER:
			return LEADER
		TurnManager.Group.VESSEL:
			return VESSEL
	return ENEMY
