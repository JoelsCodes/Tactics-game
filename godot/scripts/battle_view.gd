class_name BattleView
extends Control
## Isometric battle view, ported from js/render.js: height-mapped tiles drawn back to
## front, procedural units, hit effects, floating numbers, 4-way rotation, drag to pan,
## pinch or wheel to zoom, tap to pick a tile.

signal tile_tapped(x: int, y: int)

const TW := 26.0  # tile half-width
const TH := 13.0  # tile half-height
const HS := 11.0  # height step (px at zoom 1)
const TEAMCOL := [Color("#5aa8ff"), Color("#ff6a5a")]

var B: Dictionary
var rot := 0
var zoom := 1.0
var min_zoom := .35
var pan := Vector2.ZERO
var hl := {}  ## "x,y" -> Color
var area := {}  ## "x,y" -> true
var active = null
var cursor = null  ## [x, y] or null
var floats := []
var fx := []
var polys := []
var tween_to = null
var art := Art.new(self)
var _clock := 0.0
var _bg: GradientTexture2D
var _touches := {}
var _start = null
var _moved := false
var _pinch = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var g := Gradient.new()
	g.set_color(0, Color("#2a2f38"))
	g.set_color(1, Color("#101216"))
	_bg = GradientTexture2D.new()
	_bg.gradient = g
	_bg.fill = GradientTexture2D.FILL_RADIAL
	_bg.fill_from = Vector2(.5, .4)
	_bg.fill_to = Vector2(.5, 1.25)
	_bg.width = 64
	_bg.height = 64


func setup(battle: Dictionary) -> void:
	B = battle
	floats = []
	fx = []
	hl = {}
	area = {}
	for u in B.units:
		u.vx = float(u.x)
		u.vy = float(u.y)
		u.vh = float(Rules.tile_at(B, u.x, u.y).h)
	var n: float = B.map.w + B.map.d
	var fit: float = min(size.x / (n * TW + 20), size.y / (n * TH + 120))
	min_zoom = max(.35, fit * .9)
	zoom = clamp(max(fit, 1.15), min_zoom, 2.2)
	center_on(B.map.w / 2.0, B.map.d / 2.0, true)


func now() -> float:
	return _clock


func _process(delta: float) -> void:
	_clock += delta * 1000.0
	if tween_to != null:
		pan += (tween_to - pan) * .18
		if (tween_to - pan).length() < .5:
			tween_to = null
	queue_redraw()


# ---------- projection ----------
func rot_xy(x: float, y: float) -> Vector2:
	var w: float = B.map.w
	var d: float = B.map.d
	match rot:
		1: return Vector2(d - 1 - y, x)
		2: return Vector2(w - 1 - x, d - 1 - y)
		3: return Vector2(y, w - 1 - x)
	return Vector2(x, y)


func iso(x: float, y: float, h: float) -> Vector2:
	var r := rot_xy(x, y)
	return Vector2((r.x - r.y) * TW * zoom + pan.x, (r.x + r.y) * TH * zoom - h * HS * zoom + pan.y)


func center_on(x: float, y: float, instant := false) -> void:
	var t = Rules.tile_at(B, roundi(x), roundi(y))
	var h: float = t.h if t != null else 0.0
	var r := rot_xy(x, y)
	var target := Vector2(size.x / 2 - (r.x - r.y) * TW * zoom, size.y * .45 - ((r.x + r.y) * TH - h * HS) * zoom)
	if instant:
		pan = target
		tween_to = null
	else:
		tween_to = target


func zoom_by(f: float, at = null) -> void:
	var p: Vector2 = at if at != null else size / 2
	var s: float = clamp(zoom * f, min_zoom, 2.4)
	var k := s / zoom
	pan = p - (p - pan) * k
	zoom = s
	tween_to = null


func rotate_view(dir: int) -> void:
	var a = active if active != null else {"vx": B.map.w / 2.0, "vy": B.map.d / 2.0}
	rot = (rot + dir + 4) % 4
	center_on(a.vx, a.vy, true)


## Screen direction of a grid facing (sprite mirroring and the facing picker).
func screen_dir(f: int) -> Vector2:
	var d: Array = Rules.DIRS[f]
	var a := rot_xy(0, 0)
	var b := rot_xy(d[0], d[1])
	var r := b - a
	return Vector2(r.x - r.y, (r.x + r.y) / 2)


static func hash01(x: int, y: int, k := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h & 0xffff) / 65535.0


# ---------- drawing ----------
func _draw() -> void:
	if B.is_empty():
		return
	art.begin(_clock)
	draw_texture_rect(_bg, Rect2(Vector2.ZERO, size), false)
	polys = []
	var cells := []
	for y in B.map.d:
		for x in B.map.w:
			var r := rot_xy(x, y)
			cells.append([x, y, r.x + r.y, r.x])
	cells.sort_custom(func(a, b): return a[2] < b[2] or (a[2] == b[2] and a[3] < b[3]))
	var by_tile := {}
	for u in B.units:
		if not u.jailed:
			var k := Rules.key(roundi(u.vx), roundi(u.vy))
			if not by_tile.has(k):
				by_tile[k] = []
			by_tile[k].append(u)
	for cell in cells:
		draw_tile(cell[0], cell[1])
		for u in by_tile.get(Rules.key(cell[0], cell[1]), []):
			draw_unit(u)
	draw_fx()


func _diamond(cx: float, cy: float, tw: float, th: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx, cy - th), Vector2(cx + tw, cy), Vector2(cx, cy + th), Vector2(cx - tw, cy)])


func draw_tile(x: int, y: int) -> void:
	var t: Dictionary = B.map.tiles[y][x]
	var T: Dictionary = Data.TERRAIN[t.t]
	var s := zoom
	var h: float = t.h
	if T.get("water") and t.t == "W":
		h -= .35
	var p := iso(x, y, h)
	var cx := p.x
	var cy := p.y
	var tw := TW * s
	var th := TH * s
	var depth := (h + 1.2) * HS * s
	var v := (hash01(x, y) - .5) * .12
	art.poly([cx - tw, cy, cx, cy + th, cx, cy + th + depth, cx - tw, cy + depth], Art.shade(T.c[1], v))
	art.poly([cx + tw, cy, cx, cy + th, cx, cy + th + depth, cx + tw, cy + depth], Art.shade(T.c[2], v))
	for i in range(1, int(floor(h)) + 1):
		var yy := cy + i * HS * s
		art.stroke([cx - tw, yy, cx, yy + th, cx + tw, yy], Color(0, 0, 0, .18), 1)
	var tv := v
	if T.get("water"):
		tv += sin(_clock / 600 + x * .8 + y * .6) * .06
	if T.get("lava"):
		tv += sin(_clock / 300 + x + y) * .12
	art.polyv(_diamond(cx, cy, tw, th), Art.shade(T.c[0], tv))
	art.stroke([cx - tw, cy, cx, cy - th, cx + tw, cy], Color(1, 1, 1, .10), 1)
	art.stroke([cx - tw, cy, cx, cy + th, cx + tw, cy], Color(0, 0, 0, .25), 1)
	# detail
	var top := Art.hexc(T.c[0])
	if t.t == "g" or t.t == "m":
		var gc := Art.shade(top, -.25 if t.t == "m" else .18)
		for i in 3:
			var px := cx + (hash01(x, y, i) - .5) * tw * 1.1
			var py := cy + (hash01(x, y, i + 9) - .5) * th * 1.1
			art.line(px, py, px - 1.5 * s, py - 3 * s, gc, max(1.0, s))
			art.line(px, py, px + 1.5 * s, py - 3 * s, gc, max(1.0, s))
	elif T.get("water"):
		var o := fmod(_clock / 900 + hash01(x, y), 1.0) - .5
		art.line(cx - tw * .4 + o * tw * .5, cy + o * th, cx + tw * .1 + o * tw * .5, cy + o * th - th * .25, Color(1, 1, 1, .22), max(1.0, s * .8))
	elif t.t == "b":
		for i in range(-2, 3):
			art.line(cx + i * tw * .3 - tw * .25, cy + i * th * .3, cx + i * tw * .3 + tw * .25, cy + i * th * .3, Color(0, 0, 0, .3), 1)
	elif t.t in ["s", "r", "c"]:
		var px := cx + (hash01(x, y, 3) - .5) * tw
		var py := cy + (hash01(x, y, 4) - .5) * th
		art.stroke([px, py, px + 4 * s, py + 2 * s, px + 6 * s, py - 1 * s], Color(0, 0, 0, .2), 1)
	elif T.get("lava"):
		art.circle(cx + sin(_clock / 500 + x) * tw * .3, cy, 2 * s, Color(1, .86, .47, .5))
	# highlights
	var k := Rules.key(x, y)
	if hl.has(k):
		art.polyv(_diamond(cx, cy, tw, th), hl[k])
	if area.has(k):
		art.polyv(_diamond(cx, cy, tw, th), Color(1, .84, .35, .35 + sin(_clock / 150) * .12))
	if cursor != null and cursor[0] == x and cursor[1] == y:
		var d := _diamond(cx, cy, tw, th)
		d.append(d[0])
		draw_polyline(d, Color("#ffe9a0"), 2, true)
	if T.get("tree"):
		draw_tree(cx, cy, s, x, y)
	polys.append({"x": x, "y": y, "pts": PackedVector2Array([Vector2(cx, cy - th), Vector2(cx + tw, cy), Vector2(cx + tw, cy + depth), Vector2(cx, cy + th + depth), Vector2(cx - tw, cy + depth), Vector2(cx - tw, cy)])})


func draw_tree(cx: float, cy: float, s: float, x: int, y: int) -> void:
	var sway := sin(_clock / 1200 + x + y) * 1.2 * s
	art.rect(cx - 2.5 * s, cy - 14 * s, 5 * s, 14 * s, "#5a3f28")
	var greens := ["#2f5a2a", "#3d7034", "#4f8a40"]
	for i in 3:
		art.circle(cx + sway * (i + 1) * .5 + (i - 1) * 3 * s, cy - (18 + i * 7) * s, (12 - i * 2.5) * s, greens[i])


func draw_unit(u: Dictionary) -> void:
	var s := zoom
	var p := iso(u.vx, u.vy, u.vh)
	var cx := p.x
	var t = Rules.tile_at(B, roundi(u.vx), roundi(u.vy))
	var wet := 4 * s if t != null and Data.TERRAIN[t.t].get("water") else 0.0
	var is_active: bool = active != null and is_same(u, active)
	var bob := sin(_clock / 200) * 1.2 * s if is_active else 0.0
	var cy: float = p.y - u.hop * s
	art.ellipse(cx, cy, 11 * s, 5 * s, 0, Color(0, 0, 0, .35))
	art.ellipse_line(cx, cy, 12 * s, 5.5 * s, Color(TEAMCOL[u.team], .9), 2 * s)
	if u.ko:
		draw_ko(u, cx, cy, s)
		return
	var sd := screen_dir(u.f)
	var flip := -1.0 if sd.x < 0 else 1.0
	var back := sd.y < 0
	art.save()
	if _clock - u.flash < 300:
		art.alpha = .4 + .6 * absf(sin((_clock - u.flash) / 40))
	art.translate(cx, cy + wet + bob)
	art.scale(flip * s, s)
	art.sprite(u, back)
	art.restore()
	if wet:
		# water line over the feet (the web version clips the sprite instead)
		art.ellipse(cx, cy + 1 * s, 12 * s, 4.5 * s, 0, Color(Art.hexc(Data.TERRAIN[t.t].c[0]), .85))
	# overhead: active marker, HP bar, statuses
	var top := cy - (26.0 if u.mon in ["sandmaw", "wolfhound", "ooze"] else 40.0) * s
	if is_active:
		var ay := top - 10 * s + sin(_clock / 180) * 2 * s
		art.poly([cx - 5 * s, ay - 6 * s, cx + 5 * s, ay - 6 * s, cx, ay], "#ffd36a")
	var bw := 22 * s
	var bh: float = max(2.0, 3 * s)
	art.rect(cx - bw / 2 - 1, top - 1, bw + 2, bh + 2, Color(0, 0, 0, .6))
	var pct: float = float(u.hp) / u.s.mhp
	art.rect(cx - bw / 2, top, bw * pct, bh, "#6ad06a" if pct > .5 else "#e8c050" if pct > .25 else "#e05a4a")
	var sts: Array = u.st.keys()
	for i in min(5, sts.size()):
		art.circle(cx - bw / 2 + 3 * s + i * 5 * s, top - 4 * s, 2 * s, Data.STATUS[sts[i]].col)
	if u.cards:
		art.rect(cx + bw / 2 + 2 * s, top - 3 * s, 4 * s, 6 * s, "#f0d040")


func draw_ko(u: Dictionary, cx: float, cy: float, s: float) -> void:
	art.save()
	art.alpha = .75
	art.ellipse(cx, cy - 2 * s, 12 * s, 4 * s, -.2, Data.MONSTERS[u.mon].col if u.mon else Data.JOBS[u.job].col)
	art.circle(cx + 11 * s, cy - 4 * s, 4 * s, Art.shade(Data.MONSTERS[u.mon].col, .2) if u.mon else Art.hexc(Data.RACES[u.race].skin))
	art.restore()


# ---------- effects / floating numbers ----------
func float_text(u: Dictionary, text: String, col: Variant) -> void:
	floats.append({"x": u.vx, "y": u.vy, "h": u.vh, "text": text, "col": Art.hexc(col) if col is String else col, "t0": _clock})


func burst(x: int, y: int, col: Variant, kind: String) -> void:
	var t = Rules.tile_at(B, x, y)
	fx.append({"x": x, "y": y, "h": t.h if t != null else 0, "col": Art.hexc(col) if col is String else col, "kind": kind, "t0": _clock})


func draw_fx() -> void:
	var s := zoom
	fx = fx.filter(func(f): return _clock - f.t0 < 600)
	for f in fx:
		var p: float = (_clock - f.t0) / 600.0
		var c := iso(f.x, f.y, f.h)
		art.alpha = 1 - p
		art.ellipse_line(c.x, c.y - 12 * s, (6 + p * 20) * s, (3 + p * 10) * s, f.col, 3 * s)
		if f.kind == "mag":
			for i in 6:
				var a := i / 6.0 * 6.28 + p * 3
				art.circle(c.x + cos(a) * 14 * s * p, c.y - 14 * s - p * 22 * s + sin(a) * 6 * s, 2.5 * s, f.col)
		art.alpha = 1
	floats = floats.filter(func(f): return _clock - f.t0 < 1100)
	var font := ThemeDB.fallback_font
	var fs := roundi(15 * max(.8, s))
	for f in floats:
		var p: float = (_clock - f.t0) / 1100.0
		var c := iso(f.x, f.y, f.h)
		var y := c.y - 44 * s - p * 26
		var a := 1.0 if p < .8 else (1 - p) * 5
		var w := font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - w / 2, y)
		draw_string_outline(font, pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, .8 * a))
		draw_string(font, pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(f.col, a))


# ---------- picking ----------
func pick_tile(pt: Vector2) -> Variant:
	# Units first (their sprites stand above tiles), front-most first.
	var s := zoom
	var hit = null
	var best := -1.0
	for u in B.units:
		if u.jailed:
			continue
		var c := iso(u.vx, u.vy, u.vh)
		if absf(pt.x - c.x) < 11 * s and pt.y < c.y + 4 * s and pt.y > c.y - 40 * s:
			var r := rot_xy(u.x, u.y)
			if r.x + r.y > best:
				best = r.x + r.y
				hit = [u.x, u.y]
	if hit != null:
		return hit
	for i in range(polys.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(pt, polys[i].pts):
			return [polys[i].x, polys[i].y]
	return null


# ---------- input: tap, drag to pan, pinch / wheel to zoom ----------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_start = [e.position, pan]
				_moved = false
			elif _touches.size() == 2:
				var ps: Array = _touches.values()
				_pinch = {"d": max(1.0, ps[0].distance_to(ps[1])), "z": zoom}
				_moved = true
		else:
			_touches.erase(e.index)
			if _touches.size() < 2:
				_pinch = null
			if _touches.is_empty() and _start != null and not _moved:
				_tap(e.position)
			if _touches.is_empty():
				_start = null
		accept_event()
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() == 2 and _pinch != null:
			var ps: Array = _touches.values()
			zoom_by(_pinch.z * ps[0].distance_to(ps[1]) / _pinch.d / zoom, (ps[0] + ps[1]) / 2)
		elif _start != null and _touches.size() == 1:
			var dv: Vector2 = e.position - _start[0]
			if absf(dv.x) + absf(dv.y) > 8:
				_moved = true
			if _moved:
				tween_to = null
				pan = _start[1] + dv
		accept_event()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(1.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else .9, e.position)
		accept_event()


func _tap(pt: Vector2) -> void:
	var t = pick_tile(pt)
	if t != null:
		cursor = t
		tile_tapped.emit(t[0], t[1])
