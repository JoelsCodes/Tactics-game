class_name WorldMapArt
extends Control
## The painted-looking sea chart the world map sits on, drawn in code (no art supplied yet: every shape here is
## procedural and a placeholder for the owner's own map art). A dusk sea with slow waves and drifting clouds; each place
## an island with a shallow-water halo, sand and grass, ruins, trees or a river by its kind; routes as dotted gold lines
## between neighbours; places the story has not unlocked sit under fog. Reports which place is at a point (`pick`).

var places: Array = WorldData.PLACES
var unlocked: Callable = func(_id): return true  ## StringName -> bool
var selected: StringName = &""
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func center_of(p: Dictionary) -> Vector2:
	return Vector2(40.0 + p.pos.x * (size.x - 640.0), p.pos.y * size.y)  # the right 600 px belong to the panel


func radius_of(p: Dictionary) -> float:
	var k: float = {"base": 0.055, "keep": 0.095, "river": 0.09, "unknown": 0.075}.get(p.kind, 0.08)
	return k * size.y


## The place under `at` (local position), or &"".
func pick(at: Vector2) -> StringName:
	var best: StringName = &""
	var best_d := INF
	for p in places:
		var d := at.distance_to(center_of(p))
		if d <= radius_of(p) * 1.25 and d < best_d:
			best = p.id
			best_d = d
	return best


func _draw() -> void:
	_sea()
	_routes()
	for p in places:
		_island(p)
	_clouds()
	_vignette()


# ---------- the sea ----------

func _sea() -> void:
	var top := Color("#16284a")
	var mid := Color("#1d4a66")
	var low := Color("#0f2a3f")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y * 0.55), Vector2(0, size.y * 0.55)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.55), Vector2(size.x, size.y * 0.55), size, Vector2(0, size.y)]),
		PackedColorArray([mid, mid, low, low]))
	# slow waves
	var rows := 16
	for i in rows:
		var y := size.y * (float(i) + 0.5) / rows
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= size.x + 24.0:
			pts.append(Vector2(x, y + sin(x * 0.012 + _t * 0.5 + i * 1.7) * 4.0 + sin(x * 0.031 - _t * 0.3 + i) * 2.0))
			x += 24.0
		draw_polyline(pts, Color(0.75, 0.9, 1.0, 0.045 + 0.02 * (i % 3)), 1.5, true)
	# glints on the water
	for i in 60:
		var gx := Terrain.hash01(i, 3, 41) * size.x
		var gy := Terrain.hash01(i, 5, 42) * size.y
		var tw := 0.5 + 0.5 * sin(_t * (0.6 + Terrain.hash01(i, 7, 43)) + i * 2.1)
		draw_circle(Vector2(gx, gy), 1.4, Color(1, 0.95, 0.8, 0.10 * tw))


func _clouds() -> void:
	for i in 7:
		var speed := 6.0 + 4.0 * Terrain.hash01(i, 1, 51)
		var cx := fposmod(Terrain.hash01(i, 2, 52) * size.x * 1.4 + _t * speed, size.x * 1.4) - size.x * 0.2
		var cy := Terrain.hash01(i, 3, 53) * size.y
		var w := 120.0 + 120.0 * Terrain.hash01(i, 4, 54)
		for k in 5:
			var o := Vector2((k - 2) * w * 0.28, sin(k * 1.9 + i) * w * 0.07)
			draw_circle(Vector2(cx, cy) + o, w * (0.20 - absf(k - 2) * 0.03), Color(1, 1, 1, 0.045))


func _vignette() -> void:
	var edge := Color(0.02, 0.04, 0.09, 0.62)
	var none := Color(0.02, 0.04, 0.09, 0.0)
	var m := minf(size.x, size.y) * 0.22
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, m), Vector2(0, m)]), PackedColorArray([edge, edge, none, none]))
	draw_polygon(PackedVector2Array([Vector2(0, size.y - m), Vector2(size.x, size.y - m), size, Vector2(0, size.y)]), PackedColorArray([none, none, edge, edge]))
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(m, 0), Vector2(m, size.y), Vector2(0, size.y)]), PackedColorArray([edge, none, none, edge]))
	draw_polygon(PackedVector2Array([Vector2(size.x - m, 0), Vector2(size.x, 0), size, Vector2(size.x - m, size.y)]), PackedColorArray([none, edge, edge, none]))


# ---------- routes ----------

func _routes() -> void:
	var done := {}
	for p in places:
		for other_id in p.links:
			var key := "%s>%s" % [p.id, other_id] if String(p.id) < String(other_id) else "%s>%s" % [other_id, p.id]
			if done.has(key):
				continue
			done[key] = true
			var q := WorldData.place(other_id)
			if q.is_empty():
				continue
			var lit: bool = unlocked.call(p.id) and unlocked.call(other_id)
			_dashed(center_of(p), center_of(q), lit)


func _dashed(a: Vector2, b: Vector2, lit: bool) -> void:
	var mid := (a + b) * 0.5
	var bend := (b - a).orthogonal().normalized() * (b - a).length() * 0.12
	var pts: Array[Vector2] = []
	for i in 41:
		var t := i / 40.0
		pts.append(a.lerp(mid + bend, t).lerp((mid + bend).lerp(b, t), t))
	var col := Color(0.96, 0.82, 0.45, 0.85) if lit else Color(0.6, 0.7, 0.85, 0.22)
	var walked := 0.0
	var on := true
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if on:
			draw_line(pts[i - 1], pts[i], col, 3.0 if lit else 2.0, true)
		walked += seg
		if walked > (12.0 if on else 9.0):
			walked = 0.0
			on = not on


# ---------- islands ----------

func _shape(p: Dictionary, scale: float, wobble := 1.0) -> PackedVector2Array:
	var c := center_of(p)
	var r := radius_of(p) * scale
	var s := String(p.id).hash() % 997
	var ph1 := Terrain.hash01(s, 1, 61) * TAU
	var ph2 := Terrain.hash01(s, 2, 62) * TAU
	var ph3 := Terrain.hash01(s, 3, 63) * TAU
	var pts := PackedVector2Array()
	for i in 56:
		var a := TAU * i / 56.0
		var k := 1.0 + wobble * (0.13 * sin(2.0 * a + ph1) + 0.09 * sin(3.0 * a + ph2) + 0.05 * sin(5.0 * a + ph3))
		pts.append(c + Vector2(cos(a) * 1.25, sin(a) * 0.86) * r * k)
	return pts


func _island(p: Dictionary) -> void:
	var open: bool = unlocked.call(p.id)
	var c := center_of(p)
	var r := radius_of(p)
	var kind: String = p.kind
	if open or kind != "unknown":
		# shallow water halo, a soft shadow, sand, grass
		draw_colored_polygon(_shape(p, 1.30), Color(0.45, 0.85, 0.9, 0.16 if open else 0.07))
		draw_colored_polygon(_shape(p, 1.14), Color(0.55, 0.9, 0.92, 0.22 if open else 0.10))
		var shadow := PackedVector2Array()
		for v in _shape(p, 1.0):
			shadow.append(v + Vector2(6, 9))
		draw_colored_polygon(shadow, Color(0, 0.05, 0.1, 0.35))
		var tone := 1.0 if open else 0.45
		draw_colored_polygon(_shape(p, 1.0), _tone(Color("#d8c48a"), tone))
		var grass := _tone(_grass(kind), tone)
		draw_colored_polygon(_shape(p, 0.88), grass)
		draw_colored_polygon(_shape(p, 0.60, 0.8), _tone(_grass(kind).lightened(0.12), tone))
		if open:
			_decor(p, c, r, kind)
	if not open:
		_fog(p, c, r)
	if open or kind != "unknown":
		_label(p, c, r, open)
	_marker(p, c, r, open)


func _grass(kind: String) -> Color:
	match kind:
		"keep":
			return Color("#547f43")
		"river":
			return Color("#5c9a52")
		"base":
			return Color("#6aa05a")
	return Color("#4d6a55")


func _tone(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func _decor(p: Dictionary, c: Vector2, r: float, kind: String) -> void:
	var s := String(p.id).hash() % 991
	var trees := 7 if kind != "base" else 4
	for i in trees:  # trees: dark crowns with a lit side
		var a := Terrain.hash01(s, i, 71) * TAU
		var d := (0.25 + 0.5 * Terrain.hash01(s, i, 72)) * r
		var tp := c + Vector2(cos(a) * 1.15, sin(a) * 0.8) * d
		var tr := 7.0 + 5.0 * Terrain.hash01(s, i, 73)
		draw_circle(tp + Vector2(2, 3), tr, Color(0, 0.08, 0.03, 0.35))
		draw_circle(tp, tr, Color("#2f5a33"))
		draw_circle(tp + Vector2(-2, -3), tr * 0.62, Color("#4a8444"))
	match kind:
		"keep":  # a fallen castle: broken walls and a tower
			var wall := Color("#a99f8e")
			var shade := Color("#7a7264")
			draw_rect(Rect2(c + Vector2(-34, -6), Vector2(68, 12)), shade)
			draw_rect(Rect2(c + Vector2(-34, -10), Vector2(68, 8)), wall)
			for i in 5:  # crenels, some broken off
				if i != 2:
					draw_rect(Rect2(c + Vector2(-34 + i * 15, -16), Vector2(9, 7)), wall)
			draw_rect(Rect2(c + Vector2(18, -34), Vector2(20, 34)), shade)
			draw_rect(Rect2(c + Vector2(16, -38), Vector2(20, 34)), wall)
			draw_rect(Rect2(c + Vector2(16, -44), Vector2(7, 6)), wall)
			draw_rect(Rect2(c + Vector2(29, -44), Vector2(7, 6)), wall)
			draw_rect(Rect2(c + Vector2(-26, 8), Vector2(7, 14)), wall)  # a lone column
			draw_rect(Rect2(c + Vector2(-8, 10), Vector2(7, 9)), shade)
		"river":  # a river across the island, one bridge
			var pts := PackedVector2Array()
			for i in 15:
				var t := i / 14.0
				pts.append(c + Vector2(-r * 1.05 + t * r * 2.1, sin(t * 6.0 + 1.0) * r * 0.08 - r * 0.02))
			draw_polyline(pts, Color(0.35, 0.7, 0.9, 0.95), 11.0, true)
			draw_polyline(pts, Color(0.8, 0.95, 1.0, 0.45), 3.0, true)
			draw_rect(Rect2(c + Vector2(-5, -r * 0.2), Vector2(10, r * 0.42)), Color("#8a6a45"))
			draw_rect(Rect2(c + Vector2(-5, -r * 0.2), Vector2(10, 3)), Color("#b08a5a"))
		"base":  # an altar ring glowing among the ruins
			draw_arc(c, 17.0, 0.0, TAU, 28, Color("#a99f8e"), 5.0, true)
			draw_circle(c, 9.0, Color(1.0, 0.85, 0.45, 0.25 + 0.15 * sin(_t * 2.0)))
			for i in 4:
				var a2 := PI * 0.5 * i + 0.4
				draw_rect(Rect2(c + Vector2(cos(a2), sin(a2)) * 26.0 - Vector2(3, 8), Vector2(6, 14)), Color("#a99f8e"))


func _fog(p: Dictionary, c: Vector2, r: float) -> void:
	var s := String(p.id).hash() % 983
	draw_colored_polygon(_shape(p, 1.2), Color(0.1, 0.14, 0.24, 0.55))
	for i in 9:
		var a := Terrain.hash01(s, i, 81) * TAU
		var d := Terrain.hash01(s, i, 82) * r * 0.9
		var drift := Vector2(sin(_t * 0.2 + i), cos(_t * 0.17 + i * 1.3)) * 6.0
		var fp := c + Vector2(cos(a) * 1.2, sin(a) * 0.8) * d + drift
		draw_circle(fp, r * (0.32 + 0.2 * Terrain.hash01(s, i, 83)), Color(0.78, 0.84, 0.95, 0.20))
	draw_circle(c, r * 0.5, Color(0.8, 0.86, 0.96, 0.18))


func _label(p: Dictionary, c: Vector2, r: float, open: bool) -> void:
	var f: Font = HudStyle.font(true, true)
	var text: String = p.name if open else "Not yet reached"
	var pos := c + Vector2(-160, r * 0.86 + 28)
	var col := Color("#f3e6c4") if open else Color(0.7, 0.76, 0.9, 0.7)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 320, 24, 6, Color(0.02, 0.05, 0.1, 0.9))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 320, 24, col)


func _marker(p: Dictionary, c: Vector2, r: float, open: bool) -> void:
	var up := c + Vector2(0, -r * 0.1)
	if not open:
		var f: Font = HudStyle.font(true, true)
		draw_string_outline(f, up + Vector2(-20, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 44, 8, Color(0.02, 0.05, 0.1, 0.9))
		draw_string(f, up + Vector2(-20, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 44, Color(0.85, 0.9, 1.0, 0.85))
		return
	var gold := Color("#f4d27a")
	draw_circle(up, 9.0, Color(0.05, 0.08, 0.14, 0.8))
	draw_arc(up, 9.0, 0.0, TAU, 24, gold, 2.5, true)
	draw_colored_polygon(PackedVector2Array([up + Vector2(0, -5), up + Vector2(5, 0), up + Vector2(0, 5), up + Vector2(-5, 0)]), gold)
	if p.id == selected:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_arc(up, 18.0 + 5.0 * pulse, 0.0, TAU, 40, Color(1.0, 0.9, 0.55, 0.9 - 0.4 * pulse), 3.0, true)
		draw_arc(up, 30.0 + 8.0 * pulse, 0.0, TAU, 48, Color(1.0, 0.9, 0.55, 0.35 - 0.2 * pulse), 2.0, true)
		draw_arc(c, r * 1.32, 0.0, TAU, 64, Color(1.0, 0.9, 0.55, 0.25), 2.0, true)
