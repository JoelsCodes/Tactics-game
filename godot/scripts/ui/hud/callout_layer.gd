class_name CalloutLayer
extends Control
## Big words over the fight: a callout slides in from the side on a streak of light, holds a moment and leaves ("CRITICAL!",
## "PINCER!", "DOUBLE KO!", "SURGE!"); a banner crosses the middle of the screen (the battle's start); a flash washes the whole
## picture for an instant (a finishing blow). Presentation only: it never blocks input.

const SLOT_Y := 300.0  ## where the first callout sits at 1080p (under the message line)
const SLOT_STEP := 74.0
const MAX_LIVE := 3

var _live: Array[Control] = []
var _flash: ColorRect
static var reduce_flash := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)


func live() -> int:
	_live = _live.filter(func(c): return is_instance_valid(c))
	return _live.size()


## A word that slams in from the left, holds and leaves to the right. Returns the node (freed when it is over).
func callout(text: String, col := Color("#ffd86a"), size := 58, hold := 0.75) -> Control:
	if live() >= MAX_LIVE:
		var old: Control = _live.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var slot := 0
	var used := _live.map(func(c): return int(c.get_meta("slot", 0)))
	while used.has(slot):
		slot += 1
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("slot", slot)
	box.set_meta("text", text)
	var view := get_viewport_rect().size
	var y := SLOT_Y + SLOT_STEP * slot
	var streak := TextureRect.new()
	streak.texture = _streak_texture()
	streak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	streak.stretch_mode = TextureRect.STRETCH_SCALE
	streak.modulate = Color(col, 0.55)
	streak.size = Vector2(900, size * 1.25)
	streak.position = Vector2(-450, -size * 0.62)
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(streak)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", HudStyle.font(true, true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(1200, size * 1.4)
	l.position = Vector2(-600, -size * 0.7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	add_child(box)
	_live.append(box)
	var mid := view.x / 2.0
	box.position = Vector2(mid - 520.0, y)
	box.modulate.a = 0.0
	box.scale = Vector2(1.25, 1.25)
	var tw := box.create_tween()  # each `parallel()` step runs alongside the step before it
	tw.tween_property(box, "position:x", mid, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(box, "position:x", mid + 26.0, hold)
	tw.tween_property(box, "position:x", mid + 520.0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		_live.erase(box)
		box.queue_free())
	return box


## A dark band across the middle of the screen with a title and a line under it (the battle's start). Returns when it has left.
func banner(title: String, sub := "", hold := 1.15) -> void:
	await get_tree().process_frame  # asked for while the battle is still being built: the layout is ready a frame later
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var band := ColorRect.new()
	band.color = Color(0.02, 0.02, 0.05, 0.78)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(view.x, 190)
	band.position = Vector2(0, view.y * 0.5 - 130)
	band.pivot_offset = band.size / 2.0
	add_child(band)
	for edge in [0.0, 187.0]:
		var line := ColorRect.new()
		line.color = Color(HudStyle.GOLD, 0.9)
		line.size = Vector2(view.x, 3)
		line.position = Vector2(0, edge)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(line)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", HudStyle.font(true, true))
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", Color("#f6e2a8"))
	t.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size = Vector2(view.x, 110)
	t.position = Vector2(0, 14 if sub != "" else 40)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 28)
		s.add_theme_color_override("font_color", Color("#e8e2d0"))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.size = Vector2(view.x, 40)
		s.position = Vector2(0, 126)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(s)
	band.scale = Vector2(1.0, 0.05)
	t.modulate.a = 0.0
	t.position.x = -140.0
	var tw := band.create_tween()
	tw.tween_property(band, "scale:y", 1.0, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(t, "position:x", 0.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(t, "position:x", 30.0, hold)
	tw.tween_property(t, "position:x", 240.0, 0.18).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(band, "modulate:a", 0.0, 0.2)
	tw.tween_callback(band.queue_free)
	await tw.finished


## Washes the whole picture with `col` for an instant.
func flash(col := Color(1, 1, 1, 0.55), secs := 0.28) -> void:
	if reduce_flash or HitFeedback.reduce_flash:
		return
	_flash.color = col
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, secs).set_ease(Tween.EASE_OUT)


static var _streak: GradientTexture2D


static func _streak_texture() -> Texture2D:
	if _streak == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		_streak = GradientTexture2D.new()
		_streak.gradient = g
		_streak.width = 256
		_streak.height = 4
	return _streak

