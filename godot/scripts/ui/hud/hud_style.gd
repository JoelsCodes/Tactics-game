class_name HudStyle
extends RefCounted
## The battle HUD's look, built in code: deep navy glass panels with a hairline pale border and one
## warm gold accent (pressed buttons, the active turn). Colors for teams and bars live here too.

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


static func box(bg: Color, border := LINE, radius := 6, width := 1, pad_x := 10, pad_y := 8) -> StyleBoxFlat:
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
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box(GLASS))
	t.set_stylebox("panel", "Panel", box(GLASS))
	t.set_stylebox("normal", "Button", box(GLASS_LIGHT, LINE, 6, 1, 14, 8))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.18, 0.3, 0.95), Color(0.9, 0.93, 1, 0.8), 6, 1, 14, 8))
	t.set_stylebox("pressed", "Button", box(GOLD, GOLD, 6, 1, 14, 8))
	t.set_stylebox("disabled", "Button", box(Color(0.05, 0.06, 0.1, 0.7), Color(0.72, 0.78, 0.9, 0.15), 6, 1, 14, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", TEXT)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.35))
	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", 12)
	t.set_color("font_color", "SmallLabel", MUTED)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 17)
	t.set_color("font_color", "TitleLabel", Color("#f4e3b8"))
	return t


## A thin bar with a dark track and a colored fill.
static func bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = 7
	b.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 3, 0, 0, 0))
	b.add_theme_stylebox_override("fill", box(fill, Color(0, 0, 0, 0), 3, 0, 0, 0))
	return b


static func team_color(bu: BattleUnit) -> Color:
	match TurnManager.group_of(bu):
		TurnManager.Group.LEADER:
			return LEADER
		TurnManager.Group.VESSEL:
			return VESSEL
	return ENEMY
