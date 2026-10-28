class_name HudStyle
extends RefCounted
## The look of the HUD and the menus, built in code for a 16:9 desktop screen (layouts are made at
## 1920x1080 and scale with the window): deep navy glass panels, hairline pale borders and one warm gold
## accent (pressed buttons, the active turn). Colors for sides and bars live here too.

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


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT
	t.set_stylebox("panel", "PanelContainer", box(GLASS))
	t.set_stylebox("panel", "Panel", box(GLASS))
	t.set_stylebox("normal", "Button", box(GLASS_LIGHT, LINE, 8, 1, 20, 10))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.18, 0.3, 0.95), Color(0.9, 0.93, 1, 0.8), 8, 1, 20, 10))
	t.set_stylebox("pressed", "Button", box(GOLD, GOLD, 8, 1, 20, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.05, 0.06, 0.1, 0.7), Color(0.72, 0.78, 0.9, 0.15), 8, 1, 20, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", TEXT)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.35))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "ItemList", box(Color(0.03, 0.04, 0.09, 0.7), LINE, 6, 1, 8, 8))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(Color(GOLD, 0.25), GOLD, 4, 1, 6, 4))
	t.set_stylebox("selected_focus", "ItemList", box(Color(GOLD, 0.3), GOLD, 4, 1, 6, 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color("#fff3d0"))
	t.set_constant("v_separation", "ItemList", 10)
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", FONT_SMALL)
	t.set_color("font_color", "SmallLabel", MUTED)
	t.set_type_variation("SectionLabel", "Label")
	t.set_font_size("font_size", "SectionLabel", FONT_SMALL)
	t.set_color("font_color", "SectionLabel", GOLD)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", FONT_TITLE)
	t.set_color("font_color", "TitleLabel", Color("#f4e3b8"))
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font_size("font_size", "HeadingLabel", FONT_HEADING)
	t.set_color("font_color", "HeadingLabel", Color("#f4e3b8"))
	return t


## A bar with a dark track and a colored fill.
static func bar(fill: Color, height := 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 4, 0, 0, 0))
	b.add_theme_stylebox_override("fill", box(fill, Color(0, 0, 0, 0), 4, 0, 0, 0))
	return b


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
