class_name StatBar
extends Control
## "HP 74/74" with a beveled bar, FFT-style.

var label := "HP"
var value := 0
var maximum := 1
var color := Color("#5fd36a")


static func make(lbl: String, v: int, mx: int, col: Color) -> StatBar:
	var b := StatBar.new()
	b.label = lbl
	b.value = v
	b.maximum = max(1, mx)
	b.color = col
	b.custom_minimum_size = Vector2(0, 17)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _draw() -> void:
	var font := get_theme_default_font()
	var fs := 13
	draw_string(font, Vector2(0, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#c9d4f2"))
	var num := "%d/%d" % [value, maximum]
	var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(size.x - nw, 13), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fff6e0"))
	var x0 := 24.0
	var w := size.x - x0 - nw - 6
	var r := Rect2(x0, 5, w, 7)
	draw_rect(r.grow(1), Color(0.02, 0.03, 0.06))
	draw_rect(r, Color(0.12, 0.14, 0.22))
	var f := Rect2(r.position, Vector2(w * clampf(float(value) / maximum, 0, 1), r.size.y))
	draw_rect(f, color)
	draw_rect(Rect2(f.position, Vector2(f.size.x, 2)), color.lightened(.4))
	draw_rect(Rect2(f.position + Vector2(0, f.size.y - 2), Vector2(f.size.x, 2)), color.darkened(.3))
