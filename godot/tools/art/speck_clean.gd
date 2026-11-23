extends RefCounted
## Removes stray specks from a sprite frame: opaque islands (8-connected) smaller than MAX_PX that sit at least MIN_GAP pixels outside the bounding box of the
## frame's largest island (the body). Bigger pieces and pieces next to the body (a detached fist, a lifted boot) stay. Rex's 5-view prototype (Nov 2026) had
## 1-11 px bits of the neighbouring view cut into its side and three-quarter frames, 8+ px from the body; its punch patch is 218 px, its boot bits overlap the body.
const MAX_PX := 20
const MIN_GAP := 4


## Cleans `img` (RGBA8) in place: far specks, then the white fringe (clean_fringe). Returns how many pixels were changed.
static func clean(img: Image) -> int:
	return _clean_specks(img) + clean_fringe(img)


## A near-white pixel (luminance over FRINGE_LUM, saturation under FRINGE_SAT): what is left of a white backdrop the art was cut from.
static func _whitish(c: Color) -> bool:
	return c.a >= 0.5 and c.get_luminance() > FRINGE_LUM and c.s < FRINGE_SAT


const FRINGE_LUM := 0.8
const FRINGE_SAT := 0.2
const LONE_LUM := 0.6  ## a lone light dot: any pixel this bright with no light neighbour


static func _touches_clear(img: Image, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = Vector2i(x, y) + d
		if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or img.get_pixelv(q).a < 0.5:
			return true
	return false


## Removes the white fringe a backdrop leaves: near-white pixels on the outline (touching transparency, 4-neighbour) are cleared, repeated while
## any remain; then any lone light dot (luminance over LONE_LUM with no neighbour over 0.45: hair, skin) is cleared on the outline or takes the
## average of its neighbours inside the figure. Hair highlights and eye glints sit among light pixels and stay. Rex (Nov 2026) had a 1 px #e8dacf
## rim, stray #e8dacf dots on coat and boots, and lone tan dots on his outline in every frame. Returns how many pixels were changed.
static func clean_fringe(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var changed := 0
	var dirs4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for _pass in 3:
		var drop := []
		for y in h:
			for x in w:
				if not _whitish(img.get_pixel(x, y)):
					continue
				for d in dirs4:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or img.get_pixelv(q).a < 0.5:
						drop.append(Vector2i(x, y))
						break
		for p in drop:
			img.set_pixelv(p, Color(0, 0, 0, 0))
		changed += drop.size()
		if drop.is_empty():
			break
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			var me := src.get_pixel(x, y)
			if me.a < 0.5 or me.get_luminance() < LONE_LUM:
				continue
			var sum := Color(0, 0, 0, 0)
			var n := 0
			var lit := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := Vector2i(x + dx, y + dy)
					if (dx == 0 and dy == 0) or q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var c := src.get_pixelv(q)
					if c.a < 0.5:
						continue
					if c.get_luminance() > 0.45:
						lit = true
					sum += c
					n += 1
			if lit:
				continue
			var edge := n < 8 and _touches_clear(src, x, y)
			if edge or n == 0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var avg := sum / n
				avg.a = 1.0
				img.set_pixel(x, y, avg)
			changed += 1
	return changed


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
