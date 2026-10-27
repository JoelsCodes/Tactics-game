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
	font.base_font = load("res://assets/fonts/PixelifySans.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	t.default_font = font
	t.default_font_size = 16
	var cream := Color("#f6eedb")
	var ink := Color(0.04, 0.04, 0.09)
	# Windows
	t.set_stylebox("panel", "PanelContainer", tex_box("res://assets/ui/window.png", 8, 12, 10))
	t.set_stylebox("panel", "Panel", tex_box("res://assets/ui/window.png", 8, 12, 10))
	t.set_type_variation("StripPanel", "PanelContainer")
	t.set_stylebox("panel", "StripPanel", flat(Color(0.03, 0.04, 0.1, .55), Color(0.85, 0.72, 0.42, .6), 6, 1, 4, 4))
	t.set_type_variation("GoldPanel", "PanelContainer")
	t.set_stylebox("panel", "GoldPanel", tex_box("res://assets/ui/button_pressed.png", 8, 16, 10))
	t.set_type_variation("RowPanel", "PanelContainer")
	t.set_stylebox("panel", "RowPanel", flat(Color(0.13, 0.19, 0.38, .92), Color(0.42, 0.52, 0.82, .9), 4, 1, 10, 6))
	t.set_type_variation("RowPanelPressed", "PanelContainer")
	t.set_stylebox("panel", "RowPanelPressed", flat(Color(0.3, 0.26, 0.14, .95), Color(1, .85, .45), 4, 1, 10, 6))
	# Buttons
	t.set_stylebox("normal", "Button", tex_box("res://assets/ui/button.png", 8, 12, 6))
	t.set_stylebox("hover", "Button", tex_box("res://assets/ui/button_hover.png", 8, 12, 6))
	t.set_stylebox("pressed", "Button", tex_box("res://assets/ui/button_pressed.png", 8, 12, 6))
	t.set_stylebox("disabled", "Button", tex_box("res://assets/ui/button_disabled.png", 8, 12, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", cream)
	t.set_color("font_pressed_color", "Button", Color("#2a1a06"))
	t.set_color("font_disabled_color", "Button", Color(cream, .4))
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", tex_box("res://assets/ui/button_pressed.png", 8, 12, 6))
	t.set_stylebox("hover", "PrimaryButton", tex_box("res://assets/ui/button_pressed.png", 8, 12, 6))
	t.set_color("font_color", "PrimaryButton", Color("#2a1a06"))
	t.set_color("font_hover_color", "PrimaryButton", Color("#2a1a06"))
	t.set_type_variation("CommandButton", "Button")
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 8
	empty.content_margin_right = 6
	t.set_stylebox("normal", "CommandButton", empty)
	t.set_stylebox("disabled", "CommandButton", empty)
	t.set_stylebox("hover", "CommandButton", flat(Color(1, 1, 1, .12), Color(0, 0, 0, 0), 3, 0, 8, 2))
	t.set_stylebox("pressed", "CommandButton", flat(Color(1, .82, .4, .35), Color(0, 0, 0, 0), 3, 0, 8, 2))
	t.set_font_size("font_size", "CommandButton", 18)
	t.set_color("font_pressed_color", "CommandButton", Color("#fff6d8"))
	t.set_constant("h_separation", "CommandButton", 4)
	t.set_type_variation("MapButton", "Button")
	t.set_stylebox("normal", "MapButton", flat(Color(0.08, 0.12, 0.26, .72), Color(0.86, 0.74, 0.45, .9), 21, 2, 0, 0))
	t.set_stylebox("hover", "MapButton", flat(Color(0.16, 0.22, 0.42, .85), Color(1, .86, .5), 21, 2, 0, 0))
	t.set_stylebox("pressed", "MapButton", flat(Color(0.5, 0.4, 0.16, .9), Color(1, .9, .6), 21, 2, 0, 0))
	# Labels
	t.set_color("font_color", "Label", cream)
	t.set_color("font_outline_color", "Label", ink)
	t.set_color("default_color", "RichTextLabel", cream)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	for spec in [["HeaderLabel", 18, Color("#ffe6a8"), 0], ["SmallLabel", 13, Color("#b9c6ea"), 0], ["SectionLabel", 13, Color("#e7c46a"), 0],
			["HintLabel", 14, cream, 5], ["LogLabel", 15, cream, 5], ["BannerLabel", 22, Color("#fff4dc"), 0], ["TitleLabel", 46, Color("#ffd86a"), 10]]:
		t.set_type_variation(spec[0], "Label")
		t.set_font_size("font_size", spec[0], spec[1])
		t.set_color("font_color", spec[0], spec[2])
		t.set_constant("outline_size", spec[0], spec[3])
		t.set_color("font_outline_color", spec[0], Color(0.16, 0.08, 0.02) if spec[0] == "TitleLabel" else ink)
	# Scrollbars
	t.set_stylebox("scroll", "VScrollBar", flat(Color(0, 0, 0, .25), Color(0, 0, 0, 0), 3, 0, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", flat(Color(0.85, 0.72, 0.42, .8), Color(0, 0, 0, 0), 3, 0, 3, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(1, .86, .5), Color(0, 0, 0, 0), 3, 0, 3, 0))
	var err := ResourceSaver.save(t, "res://ui/theme.tres")
	print("theme ", error_string(err))
