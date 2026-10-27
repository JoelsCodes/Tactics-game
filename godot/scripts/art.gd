class_name Art
extends RefCounted
## Procedural art, ported from js/render.js: a tiny canvas-like layer (save/restore,
## translate, scale, alpha) over a CanvasItem's draw_* calls, plus the unit sprites.
## Used by the battle view and by portraits. Call only from the target's _draw().

var ci: CanvasItem
var t := 0.0  ## animation clock in ms
var alpha := 1.0
var _xf := Transform2D.IDENTITY
var _stack := []


func _init(target: CanvasItem) -> void:
	ci = target


static func hexc(hex: String) -> Color:
	return Color.html(hex)


## js shade(): f > 0 lightens toward white, f < 0 darkens.
static func shade(c: Variant, f: float) -> Color:
	var col: Color = Color.html(c) if c is String else c
	if f > 0:
		return Color(col.r + (1 - col.r) * f, col.g + (1 - col.g) * f, col.b + (1 - col.b) * f, col.a)
	return Color(col.r * (1 + f), col.g * (1 + f), col.b * (1 + f), col.a)


# ---------- canvas-like state ----------
func begin(clock_ms: float) -> void:
	t = clock_ms
	alpha = 1.0
	_xf = Transform2D.IDENTITY
	_stack.clear()
	ci.draw_set_transform_matrix(_xf)


func save() -> void:
	_stack.push_back([_xf, alpha])


func restore() -> void:
	var s: Array = _stack.pop_back()
	_xf = s[0]
	alpha = s[1]
	ci.draw_set_transform_matrix(_xf)


func translate(x: float, y: float) -> void:
	_xf = _xf.translated_local(Vector2(x, y))
	ci.draw_set_transform_matrix(_xf)


func scale(sx: float, sy: float) -> void:
	_xf = _xf.scaled_local(Vector2(sx, sy))
	ci.draw_set_transform_matrix(_xf)


func c(col: Variant) -> Color:
	var k: Color = Color.html(col) if col is String else col
	return Color(k, k.a * alpha)


# ---------- primitives ----------
func poly(pts: Array, col: Variant) -> void:
	var p := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		p.append(Vector2(pts[i], pts[i + 1]))
	ci.draw_colored_polygon(p, c(col))


func polyv(p: PackedVector2Array, col: Variant) -> void:
	ci.draw_colored_polygon(p, c(col))


func stroke(pts: Array, col: Variant, w: float, closed := false) -> void:
	var p := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		p.append(Vector2(pts[i], pts[i + 1]))
	if closed:
		p.append(p[0])
	ci.draw_polyline(p, c(col), w, true)


func line(x0: float, y0: float, x1: float, y1: float, col: Variant, w: float) -> void:
	ci.draw_line(Vector2(x0, y0), Vector2(x1, y1), c(col), w, true)


func rect(x: float, y: float, w: float, h: float, col: Variant) -> void:
	ci.draw_rect(Rect2(x, y, w, h).abs(), c(col))


func circle(x: float, y: float, r: float, col: Variant) -> void:
	ci.draw_circle(Vector2(x, y), r, c(col))


static func ellipse_pts(x: float, y: float, rx: float, ry: float, rot := 0.0, n := 24) -> PackedVector2Array:
	var p := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / n
		var ex := cos(a) * rx
		var ey := sin(a) * ry
		p.append(Vector2(x + ex * cr - ey * sr, y + ex * sr + ey * cr))
	return p


func ellipse(x: float, y: float, rx: float, ry: float, rot: float, col: Variant) -> void:
	ci.draw_colored_polygon(ellipse_pts(x, y, rx, ry, rot), c(col))


func ellipse_line(x: float, y: float, rx: float, ry: float, col: Variant, w: float) -> void:
	var p := ellipse_pts(x, y, rx, ry, 0.0, 32)
	p.append(p[0])
	ci.draw_polyline(p, c(col), w, true)


## Filled arc segment (canvas arc + fill: the chord closes it).
func arc_fill(x: float, y: float, r: float, a0: float, a1: float, col: Variant) -> void:
	var p := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		p.append(Vector2(x + cos(a) * r, y + sin(a) * r))
	ci.draw_colored_polygon(p, c(col))


func arc_line(x: float, y: float, r: float, a0: float, a1: float, col: Variant, w: float) -> void:
	ci.draw_arc(Vector2(x, y), r, a0, a1, 16, c(col), w, true)


## Quadratic curve points from p0 through control q to p1 (p0 excluded).
static func quad(p0: Vector2, q: Vector2, p1: Vector2, n := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, n + 1):
		var s := float(i) / n
		out.append(p0.lerp(q, s).lerp(q.lerp(p1, s), s))
	return out


func rrect(x: float, y: float, w: float, h: float, r: float, col: Variant) -> void:
	var p := PackedVector2Array()
	for corner in [[x + w - r, y + r, -PI / 2], [x + w - r, y + h - r, 0.0], [x + r, y + h - r, PI / 2], [x + r, y + r, PI]]:
		for i in 5:
			var a: float = corner[2] + PI / 2 * i / 4
			p.append(Vector2(corner[0] + cos(a) * r, corner[1] + sin(a) * r))
	ci.draw_colored_polygon(p, c(col))


# ---------- unit sprites (js sprite/weaponSprite/monsterSprite) ----------
## Draws a unit facing screen-right, feet at (0,0), about 36 px tall.
## `bu` needs: u (unit), race, job, mon, id, s.wt, x; walk optional.
func sprite(bu: Dictionary, back: bool) -> void:
	if bu.mon:
		monster_sprite(bu, back)
		return
	var j: Dictionary = Data.JOBS[bu.job]
	var race: String = bu.race
	var skin := hexc(Data.RACES[race].skin)
	var col := hexc(j.col)
	var dark := shade(col, -.35)
	var eq: Dictionary = bu.u.eq
	var k := .78 if race == "mossling" else 1.1 if race == "saurian" else 1.0
	save()
	scale(k, k)
	var step := sin(t / 70.0) * 2 if bu.get("walk") else 0.0
	# legs
	if race != "nuwa":
		rect(-5, -10 + step * .3, 4, 10 - step * .3, "#2c2a30")
		rect(1, -10 - step * .3, 4, 10 + step * .3, "#2c2a30")
	if race == "saurian":
		var tail := PackedVector2Array([Vector2(-5, -10)])
		tail.append_array(quad(Vector2(-5, -10), Vector2(-16, -6), Vector2(-18, 0)))
		tail.append(Vector2(-14, 0))
		tail.append_array(quad(Vector2(-14, 0), Vector2(-11, -5), Vector2(-4, -6)))
		polyv(tail, shade(skin, -.2))
	if back:
		weapon_sprite(bu)
	# body
	if race == "nuwa":
		poly([-6, -24, 6, -24, 9, 0, -9, 0], col)
	else:
		rrect(-7, -24, 14, 15, 4, col)
	rect(-7, -12, 14, 2.5, dark)
	if j.body and j.body[0] == "heavy":
		rect(-6, -23, 12, 3, Color(1, 1, 1, .25))
	# head
	var hy := -31.0 if race == "mossling" else -30.0
	var hr := 8.0 if race == "mossling" else 6.5 if race == "saurian" else 6.0
	if race == "sylph":
		poly([-3, hy - 4, -6, hy - 17, 0, hy - 5], skin)
		poly([1, hy - 4, 3, hy - 18, 4, hy - 4], skin)
	if race == "nuwa":
		ellipse(-6, hy + 3, 3, 9, .3, shade(skin, -.15))
	circle(0, hy, hr, skin)
	if race == "saurian" and not back:
		ellipse(6, hy + 1.5, 6, 3.5, 0, skin)
	if race == "mossling":
		line(0, hy - hr, 1, hy - hr - 6, "#3a2a2a", 1)
		circle(1, hy - hr - 7, 2.5, "#e04a5a")
	# hair / hat
	if race == "human" or race == "sylph":
		var hair := hexc("#e8e0d0") if race == "sylph" else hair_col(bu)
		arc_fill(0, hy - 1, hr + .5, PI * .95, PI * 2.05, hair)
		if back:
			circle(0, hy, hr, hair)
	if j.head and j.head[0] == "hat" and eq.get("h"):
		poly([-8, hy - 3, 8, hy - 3, 1, hy - 15], dark)
	if eq.get("h") and Data.ITEMS[eq.h].t == "helm":
		arc_fill(0, hy - 1, hr + 1, PI, PI * 2, "#b8bcc4")
	# face
	if not back:
		rect(2.5, hy - 1.5, 1.8, 2.4, "#1a1a1a")
		if race == "mossling":
			rect(-1.5, hy - 1.5, 1.8, 2.4, "#1a1a1a")
	# arm + weapon
	rect(4, -21, 3.5, 9, skin)
	if not back:
		weapon_sprite(bu)
	if eq.get("o") and not back:
		ellipse(-7, -16, 4, 6, 0, "#8a6a3a")
		var e := ellipse_pts(-7, -16, 4, 6)
		e.append(e[0])
		ci.draw_polyline(e, c("#d8c070"), 1, true)
	restore()


static func hair_col(bu: Dictionary) -> Color:
	var cols := ["#3a2a1a", "#7a4a2a", "#c09050", "#2a2a2a", "#a04030"]
	var id: String = bu.id
	return hexc(cols[(id.unicode_at(1) if id.length() > 1 else 0) % cols.size()])


func weapon_sprite(bu: Dictionary) -> void:
	var wt: String = bu.s.wt
	save()
	translate(6, -13)
	if wt == "bow" or wt == "greatbow":
		arc_line(2, -4, 9 if wt == "bow" else 12, -1.3, 1.3, "#8a5a2a", 2)
		line(2 + 9 * cos(-1.3), -4 + 9 * sin(-1.3), 2 + 9 * cos(1.3), -4 + 9 * sin(1.3), "#dddddd", .7)
	elif wt == "gun":
		rect(0, -3, 14, 3.5, "#4a3a2a")
		rect(8, -3.5, 9, 2, "#888888")
	elif wt == "staff" or wt == "rod":
		line(0, 8, 3, -18, "#8a6a3a" if wt == "staff" else "#5a4a6a", 2)
		circle(3, -19, 3, "#e0f0ff" if wt == "staff" else "#ff9a5a")
	elif wt == "spear":
		line(-4, 6, 8, -22, "#7a5a3a", 2)
		poly([8, -22, 11, -29, 6, -24], "#ccccdd")
	elif wt == "instrument":
		ellipse(3, -3, 4, 5, .4, "#c8a050")
	elif wt == "mace":
		line(0, 2, 4, -12, "#7a5a3a", 2)
		circle(4, -13, 3.5, "#aaaabb")
	elif wt == "fist":
		circle(2, 0, 3, "#aa8a5a")
	else:
		var len := 22.0 if wt == "greatsword" else 9.0 if wt == "knife" else 18.0 if wt == "rapier" else 15.0
		line(1, 0, 5, -len, "#dfe4ea", 3.5 if wt == "greatsword" else 1.3 if wt == "rapier" else 2.5)
		line(-2, -1, 4, 1, "#c0a050", 2)
		var wid = bu.u.eq.get("w")
		if wid and Data.ITEMS[wid].get("el"):
			var a0 := alpha
			alpha = a0 * .5
			line(2, -3, 5, -len, Data.ELEMENTS[Data.ITEMS[wid].el], 4)
			alpha = a0
	restore()


func monster_sprite(bu: Dictionary, back: bool) -> void:
	var m: Dictionary = Data.MONSTERS[bu.mon]
	var col := hexc(m.col)
	var d := shade(col, -.3)
	var l := shade(col, .25)
	var wob := sin(t / 250.0 + bu.get("x", 0))
	match m.shape:
		"goblin":
			rect(-4, -8, 3, 8, "#3a3028")
			rect(1, -8, 3, 8, "#3a3028")
			rrect(-6, -19, 12, 12, 3, "#6a4a30")
			circle(0, -24, 7, col)
			poly([-5, -26, -14, -30, -5, -22], col)
			poly([5, -26, 13, -31, 5, -22], col)
			if not back:
				rect(2, -26, 2, 2, "#ffde5a")
			line(6, -12, 10, -22, "#8a7a6a", 2.5)
		"wolf":
			rect(-10, -9, 3, 9, d)
			rect(6, -9, 3, 9, d)
			ellipse(-1, -12, 13, 6, 0, col)
			poly([-12, -13, -19, -18 + wob, -13, -10], col)
			ellipse(12, -17, 6, 5, -.3, col)
			poly([16, -17, 21, -15, 16, -14], col)
			poly([9, -21, 10, -27, 13, -21], col)
			if not back:
				rect(14, -19, 2, 2, "#ff5a3a")
		"ooze":
			var a0 := alpha
			alpha = a0 * .9
			var body := PackedVector2Array([Vector2(-13, 0)])
			body.append_array(quad(Vector2(-13, 0), Vector2(-13 - wob, -20), Vector2(0, -21 + wob)))
			body.append_array(quad(Vector2(0, -21 + wob), Vector2(13 + wob, -20), Vector2(13, 0)))
			polyv(body, col)
			ellipse(-4, -14, 3, 5, -.4, l)
			if not back:
				rect(2, -12, 2.5, 3.5, "#1a2a2a")
				rect(7, -12, 2.5, 3.5, "#1a2a2a")
			alpha = a0
		"bug":
			for i in range(-1, 2):
				rect(i * 7 - 1, -6, 2, 6, d)
			ellipse(-2, -9, 14, 7, 0, col)
			ellipse(-4, -12, 8, 3, 0, l)
			circle(12, -10, 5, col)
			var m1 := PackedVector2Array([Vector2(15, -12)])
			m1.append_array(quad(Vector2(15, -12), Vector2(22, -14 + wob), Vector2(20, -8)))
			ci.draw_polyline(m1, c(d), 2, true)
			var m2 := PackedVector2Array([Vector2(15, -8)])
			m2.append_array(quad(Vector2(15, -8), Vector2(22, -6 - wob), Vector2(20, -3)))
			ci.draw_polyline(m2, c(d), 2, true)
		"hag":
			poly([-9, 0, 9, 0, 5, -26, -5, -26], "#2a2a24")
			poly([-10, 0, 10, 0, 4, -22, -6, -22], col)
			circle(1, -29, 6, "#a0b090")
			if not back:
				poly([6, -29, 11, -26, 6, -27], "#a0b090")
				rect(3, -31, 2, 2, "#ffd040")
			poly([-10, -32, 11, -32, -2, -48 + wob], "#1e1e1a")
			line(10, 0, 12, -30, "#6a5a3a", 2)
			var a0 := alpha
			alpha = a0 * .8
			circle(12, -32, 3 + wob * .5, "#7ef08a")
			alpha = a0
