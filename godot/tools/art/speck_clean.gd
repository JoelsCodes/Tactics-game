extends RefCounted
## Removes stray specks from a sprite frame: opaque islands (8-connected) smaller than MAX_PX that sit at least MIN_GAP pixels outside the bounding box of the
## frame's largest island (the body). Bigger pieces and pieces next to the body (a detached fist, a lifted boot) stay. Rex's 5-view prototype (Nov 2026) had
## 1-11 px bits of the neighbouring view cut into its side and three-quarter frames, 8+ px from the body; its punch patch is 218 px, its boot bits overlap the body.
const MAX_PX := 20
const MIN_GAP := 4


## Cleans `img` (RGBA8) in place; returns how many pixels were cleared.
static func clean(img: Image) -> int:
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
