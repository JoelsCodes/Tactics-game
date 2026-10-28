extends SceneTree
## Generates the editor resources from the built art:
##   assets/characters/<name>.tres   SpriteFrames (idle, ready, attack, cast, victory)
##   ui/theme.tres                   the UI theme (pixel font, window frames, styles)
## Run after tools/art/build_art.py and an import:
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/build_resources.gd


func _init() -> void:
	build_frames()
	build_theme()
	quit()


func build_frames() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	for ch in meta:
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		var anims: Dictionary = meta[ch].anims
		for a in anims:
			var def: Dictionary = anims[a]
			sf.add_animation(a)
			sf.set_animation_speed(a, float(def.fps))
			sf.set_animation_loop(a, bool(def.loop))
			for f in def.frames:
				sf.add_frame(a, load("res://assets/characters/%s/%s" % [ch, f]))
		var err := ResourceSaver.save(sf, "res://assets/characters/%s.tres" % ch)
		print("frames ", ch, " ", error_string(err))


func tex_box(path: String, margin := 8, cx := 10, cy := 8) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_texture_margin(side, margin)
	s.content_margin_left = cx
	s.content_margin_right = cx
	s.content_margin_top = cy
	s.content_margin_bottom = cy
	return s


func flat(bg: Color, border := Color(0, 0, 0, 0), radius := 4, bw := 0, cx := 8, cy := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = cx
	s.content_margin_right = cx
	s.content_margin_top = cy
	s.content_margin_bottom = cy
	s.anti_aliasing = true
	return s


func build_theme() -> void:
	var t := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/Inter-Medium.otf")
	t.default_font = font
	t.default_font_size = 15
	var cream := Color("#eef0f6")
	var ink := Color(0.02, 0.03, 0.07)
	# Triangle Strategy look: deep navy glass, hairline pale borders, one warm accent.
	var glass := Color(0.045, 0.06, 0.12, .9)
	var line := Color(0.72, 0.78, 0.9, .55)
	var accent := Color("#e9c777")
	# Windows
	t.set_stylebox("panel", "PanelContainer", flat(glass, line, 3, 1, 14, 10))
	t.set_stylebox("panel", "Panel", flat(glass, line, 3, 1, 14, 10))
	t.set_type_variation("StripPanel", "PanelContainer")
	t.set_stylebox("panel", "StripPanel", flat(Color(0.03, 0.04, 0.09, .6), Color(0.72, 0.78, 0.9, .3), 3, 1, 6, 4))
	t.set_type_variation("GoldPanel", "PanelContainer")
	t.set_stylebox("panel", "GoldPanel", flat(glass, accent, 3, 1, 18, 10))
	t.set_type_variation("RowPanel", "PanelContainer")
	t.set_stylebox("panel", "RowPanel", flat(Color(0.08, 0.11, 0.2, .92), Color(0.72, 0.78, 0.9, .28), 2, 1, 12, 7))
	t.set_type_variation("RowPanelPressed", "PanelContainer")
	t.set_stylebox("panel", "RowPanelPressed", flat(Color(0.2, 0.2, 0.17, .95), accent, 2, 1, 12, 7))
	# Buttons: flat dark with a hairline; the pressed state fills pale gold.
	t.set_stylebox("normal", "Button", flat(Color(0.07, 0.1, 0.19, .92), Color(0.72, 0.78, 0.9, .4), 2, 1, 14, 7))
	t.set_stylebox("hover", "Button", flat(Color(0.14, 0.18, 0.3, .95), Color(0.9, 0.93, 1, .8), 2, 1, 14, 7))
	t.set_stylebox("pressed", "Button", flat(accent, accent, 2, 1, 14, 7))
	t.set_stylebox("disabled", "Button", flat(Color(0.05, 0.06, 0.1, .7), Color(0.72, 0.78, 0.9, .15), 2, 1, 14, 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", cream)
	t.set_color("font_pressed_color", "Button", Color("#1b1405"))
	t.set_color("font_disabled_color", "Button", Color(cream, .35))
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", flat(accent, accent, 2, 1, 16, 8))
	t.set_stylebox("hover", "PrimaryButton", flat(Color("#f6dc9c"), Color("#fff3d0"), 2, 1, 16, 8))
	t.set_color("font_color", "PrimaryButton", Color("#1b1405"))
	t.set_color("font_hover_color", "PrimaryButton", Color("#1b1405"))
	t.set_type_variation("CommandButton", "Button")
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 8
	empty.content_margin_right = 6
	t.set_stylebox("normal", "CommandButton", empty)
	t.set_stylebox("disabled", "CommandButton", empty)
	t.set_stylebox("hover", "CommandButton", flat(Color(0.75, 0.82, 1, .16), Color(0, 0, 0, 0), 1, 0, 8, 3))
	t.set_stylebox("pressed", "CommandButton", flat(Color(0.91, 0.78, 0.47, .3), Color(0, 0, 0, 0), 1, 0, 8, 3))
	t.set_font_size("font_size", "CommandButton", 17)
	t.set_color("font_pressed_color", "CommandButton", Color("#fff3d0"))
	t.set_constant("h_separation", "CommandButton", 4)
	t.set_type_variation("MapButton", "Button")
	t.set_stylebox("normal", "MapButton", flat(Color(0.045, 0.06, 0.12, .78), Color(0.72, 0.78, 0.9, .55), 21, 1, 0, 0))
	t.set_stylebox("hover", "MapButton", flat(Color(0.14, 0.18, 0.3, .9), Color(0.9, 0.93, 1, .9), 21, 1, 0, 0))
	t.set_stylebox("pressed", "MapButton", flat(Color(0.91, 0.78, 0.47, .9), Color(1, .93, .7), 21, 1, 0, 0))
	# Labels
	t.set_color("font_color", "Label", cream)
	t.set_color("font_outline_color", "Label", ink)
	t.set_color("default_color", "RichTextLabel", cream)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	var semi := FontVariation.new()
	semi.base_font = load("res://assets/fonts/Inter-SemiBold.otf")
	var display := FontVariation.new()
	display.base_font = load("res://assets/fonts/InterDisplay-SemiBold.otf")
	for spec in [["HeaderLabel", 18, Color("#f4e3b8"), 0], ["SmallLabel", 12, Color("#a9b6d6"), 0], ["SectionLabel", 12, accent, 0],
			["HintLabel", 13, cream, 4], ["LogLabel", 14, cream, 4], ["BannerLabel", 24, Color("#fbf3dc"), 0], ["TitleLabel", 44, Color("#f4e3b8"), 6]]:
		t.set_type_variation(spec[0], "Label")
		t.set_font_size("font_size", spec[0], spec[1])
		t.set_color("font_color", spec[0], spec[2])
		t.set_constant("outline_size", spec[0], spec[3])
		t.set_color("font_outline_color", spec[0], ink)
		if spec[0] in ["HeaderLabel", "SectionLabel", "BannerLabel"]:
			t.set_font("font", spec[0], semi)
		if spec[0] == "TitleLabel":
			t.set_font("font", spec[0], display)
	# Scrollbars
	t.set_stylebox("scroll", "VScrollBar", flat(Color(0, 0, 0, .25), Color(0, 0, 0, 0), 2, 0, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", flat(Color(0.72, 0.78, 0.9, .6), Color(0, 0, 0, 0), 2, 0, 3, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(0.91, 0.78, 0.47), Color(0, 0, 0, 0), 2, 0, 3, 0))
	var err := ResourceSaver.save(t, "res://ui/theme.tres")
	print("theme ", error_string(err))
