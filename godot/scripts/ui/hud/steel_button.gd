class_name SteelButton
extends Button
## One command of the battle's steel menu (SteelMenu): an icon, a word and, for a command that opens a list, a chevron. It draws no background of its
## own: the menu draws the dark engraved bar behind it and the lit selector over that. `lit` is set by the menu on the selected one.

const TEXT := Color("#a9b6c6")        ## the word on a dark bar
const TEXT_LIT := Color("#f4f9ff")    ## the word on the lit bar
const TEXT_OFF := Color("#69737f")    ## muted steel: a command that cannot be used
const HEIGHT := 36

var submenu := false  ## this command opens a list: it shows a chevron
var lit := false:
	set(v):
		lit = v
		_recolor()
		queue_redraw()


func _init(label := "", icon_name := "", opens_list := false) -> void:
	text = label
	submenu = opens_list
	if icon_name != "":
		icon = HudStyle.icon(icon_name)
	set_meta("ui_sound", true)  # the menu plays its own sounds; the HUD's generic hover tick and click skip this button
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_theme_constant_override("icon_max_width", 22)
	add_theme_constant_override("h_separation", 12)
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 30.0
	plain.content_margin_right = 40.0
	for k in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(k, plain)
	Typography.apply(self, Typography.Role.BODY_STRONG)
	_recolor()


func _recolor() -> void:
	var c := TEXT_LIT if lit else TEXT
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(k, c)
	add_theme_color_override("font_disabled_color", TEXT_OFF)
	for k in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		add_theme_color_override(k, c)
	add_theme_color_override("icon_disabled_color", Color(TEXT_OFF, 0.7))


func _draw() -> void:
	if not submenu:
		return
	var col := TEXT_OFF if disabled else (TEXT_LIT if lit else Color(TEXT, 0.7))
	var x := size.x - 28.0
	var cy := size.y * 0.5
	draw_polyline(PackedVector2Array([Vector2(x, cy - 6), Vector2(x + 6, cy), Vector2(x, cy + 6)]), col, 2.0, true)
