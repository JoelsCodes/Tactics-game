extends RefCounted
## Removes stray specks from a sprite frame: opaque islands (8-connected) smaller than MAX_PX that sit at least MIN_GAP pixels outside the bounding box of the
## frame's largest island (the body). Bigger pieces and pieces next to the body (a detached fist, a lifted boot) stay. Rex's 5-view prototype (Nov 2026) had
## 1-11 px bits of the neighbouring view cut into its side and three-quarter frames, 8+ px from the body; its punch patch is 218 px, its boot bits overlap the body.
const MAX_PX := 20
const MIN_GAP := 4


## Cleans `img` (RGBA8) in place: far specks, then the white fringe (clean_fringe). Returns how many pixels were changed.
static func clean(img: Image) -> int:
	return _clean_specks(img) + clean_fringe(img)


const FRINGE_LUM := 0.8  ## near-white: luminance over this, saturation under FRINGE_SAT
const FRINGE_SAT := 0.2
const RIM_LUM := 0.42  ## a pale outline pixel: luminance over this (skin in the head excepted)
const RIM_DARKEN := 0.55  ## a pale grey outline pixel with body behind it is darkened by this
const LONE_LUM := 0.6  ## a lone light dot: any pixel this bright with no light neighbour
const HEAD := 0.35  ## the top this share of the figure is the head, where a near-white pixel by skin is an eye glint


static func _whitish(c: Color) -> bool:
	return c.a >= 0.5 and c.get_luminance() > FRINGE_LUM and c.s < FRINGE_SAT


static func _greyish(c: Color) -> bool:  ## light grey hair
	return c.a >= 0.5 and c.get_luminance() > 0.5 and c.s < 0.25 and not _whitish(c)


static func _skin(c: Color) -> bool:
	return c.a >= 0.5 and c.get_luminance() > 0.55 and c.s >= 0.2 and c.s < 0.5 and c.h > 0.02 and c.h < 0.12


static func _touches_clear(img: Image, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + d
		if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or img.get_pixelv(q).a < 0.5:
			return true
	return false


## The opaque 8-neighbours of (x, y).
static func _around(img: Image, x: int, y: int) -> Array:
	var out := []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := Vector2i(x + dx, y + dy)
			if (dx == 0 and dy == 0) or q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
				continue
			var c := img.get_pixelv(q)
			if c.a >= 0.5:
				out.append(c)
	return out


static func _average(cs: Array) -> Color:
	var sum := Color(0, 0, 0, 0)
	for c in cs:
		sum += c
	var avg: Color = sum / cs.size()
	avg.a = 1.0
	return avg


## Removes the white fringe a white backdrop leaves (Rex, Nov 2026: a 1 px #e8dacf rim, pale grey tips on his hair's outline, and lone white or tan
## dots on coat, bag, boots and outline in every frame, and pinholes where the backdrop was keyed out inside him: eyes, gaps by the arms), in passes:
##   0. holes (transparent pixels the outside can't reach, up to HOLE_PX each) are filled from their neighbours; again after the others;
##   1. near-white pixels on the outline (touching transparency, 4-neighbour) are cleared, repeated while any remain;
##   2. pale outline pixels (not the face's skin) are cleared when they stick out (2 or fewer opaque neighbours), otherwise darkened (RIM_DARKEN) into an outline;
##   3. a near-white pixel inside the figure stays only as a hair highlight (2+ light grey neighbours) or an eye glint (next to skin in the HEAD);
##      otherwise it takes the average of its neighbours that are not near-white;
##   4. any lone light dot (over LONE_LUM with no neighbour over 0.45) is cleared on the outline, or averaged inside.
## Returns how many pixels were changed.
static func clean_fringe(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var changed := fill_holes(img)
	for _pass in 3:
		var drop := []
		for y in h:
			for x in w:
				if _whitish(img.get_pixel(x, y)) and _touches_clear(img, x, y):
					drop.append(Vector2i(x, y))
		for p in drop:
			img.set_pixelv(p, Color(0, 0, 0, 0))
		changed += drop.size()
		if drop.is_empty():
			break
	var src: Image = img.duplicate()
	var top := h
	var bottom := 0
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a >= 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var head_end := top + int((bottom - top) * HEAD)
	for y in h:
		for x in w:
			var me := src.get_pixel(x, y)
			if me.a < 0.5 or me.get_luminance() <= RIM_LUM or (_skin(me) and y <= head_end) or not _touches_clear(src, x, y):
				continue
			if _around(src, x, y).size() <= 2:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(me.r * RIM_DARKEN, me.g * RIM_DARKEN, me.b * RIM_DARKEN, 1.0))
			changed += 1
	src = img.duplicate()
	for y in h:
		for x in w:
			var me := src.get_pixel(x, y)
			if not _whitish(me):
				continue
			var near := _around(src, x, y)
			var grey := near.filter(func(c): return _greyish(c)).size()  # not other near-white pixels: a clump of them on a coat is still a clump of dots
			var skin := near.filter(func(c): return _skin(c)).size()
			if grey >= 2 or (skin > 0 and y <= head_end):
				continue
			var rest := near.filter(func(c): return not _whitish(c))
			img.set_pixel(x, y, _average(rest) if not rest.is_empty() else Color(0, 0, 0, 0))
			changed += 1
	src = img.duplicate()
	for y in h:
		for x in w:
			var me := src.get_pixel(x, y)
			if me.a < 0.5 or me.get_luminance() < LONE_LUM:
				continue
			var near := _around(src, x, y)
			if near.any(func(c): return c.get_luminance() > 0.45):
				continue
			img.set_pixel(x, y, Color(0, 0, 0, 0) if near.is_empty() or _touches_clear(src, x, y) else _average(near))
			changed += 1
	return changed + fill_holes(img)


const HOLE_PX := 24  ## a hole this size or smaller is filled; bigger enclosed gaps (between an arm and the body) are part of the drawing


## Fills holes in the figure: groups (4-connected) of transparent pixels the frame's border can't reach, up to HOLE_PX each, filled from the edge
## inward with the average of their opaque neighbours (not near-white ones). Returns how many pixels were filled.
static func fill_holes(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := []
	for k in w:
		stack.append_array([Vector2i(k, 0), Vector2i(k, h - 1)])
	for k in h:
		stack.append_array([Vector2i(0, k), Vector2i(w - 1, k)])
	while not stack.is_empty():  # mark the outside
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x] == 1 or img.get_pixelv(p).a >= 0.5:
			continue
		seen[p.y * w + p.x] = 1
		stack.append_array([p + Vector2i(1, 0), p - Vector2i(1, 0), p + Vector2i(0, 1), p - Vector2i(0, 1)])
	var filled := 0
	for y in h:
		for x in w:
			if seen[y * w + x] == 1 or img.get_pixel(x, y).a >= 0.5:
				continue
			var hole := []
			stack = [Vector2i(x, y)]
			seen[y * w + x] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				hole.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and seen[q.y * w + q.x] == 0 and img.get_pixelv(q).a < 0.5:
						seen[q.y * w + q.x] = 1
						stack.append(q)
			if hole.size() > HOLE_PX:
				continue
			while not hole.is_empty():  # fill from the rim of the hole inward
				var next := []
				var fills := {}
				for p in hole:
					var near := _around(img, p.x, p.y).filter(func(c): return not _whitish(c))
					if near.is_empty():
						next.append(p)
					else:
						fills[p] = _average(near)
				if fills.is_empty():
					break
				for p in fills:
					img.set_pixelv(p, fills[p])
				filled += fills.size()
				hole = next
	return filled


static func _clean_specks(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var islands := []
	for y in h:
		for x in w:
			if seen[y * w + x] == 1 or img.get_pixel(x, y).a < 0.5:
				continue
			seen[y * w + x] = 1
			var stack := [Vector2i(x, y)]
			var px := []
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				px.append(p)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or seen[q.y * w + q.x] == 1:
							continue
						if img.get_pixel(q.x, q.y).a >= 0.5:
							seen[q.y * w + q.x] = 1
							stack.append(q)
			islands.append(px)
	if islands.size() < 2:
		return 0
	islands.sort_custom(func(a, b): return a.size() > b.size())
	var body := Rect2i(islands[0][0], Vector2i.ONE)
	for p in islands[0]:
		body = body.expand(p)
	body.size += Vector2i.ONE
	var cleared := 0
	for i in range(1, islands.size()):
		var isl: Array = islands[i]
		if isl.size() >= MAX_PX:
			continue
		var b := Rect2i(isl[0], Vector2i.ONE)
		for p in isl:
			b = b.expand(p)
		b.size += Vector2i.ONE
		var gap := maxi(maxi(body.position.x - b.end.x, b.position.x - body.end.x), maxi(body.position.y - b.end.y, b.position.y - body.end.y))
		if gap < MIN_GAP:
			continue
		for p in isl:
			img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		cleared += isl.size()
	return cleared
