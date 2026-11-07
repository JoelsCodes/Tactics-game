extends SceneTree
## Rebuilds the five Riverford battle maps with OrganicLayout, keeping each map's size, ground, spawns, waves and decorations.
## godot --headless --path godot --script res://tools/organic/riverford_organic.gd
const SEEDS := [0, 101, 202, 303, 404, 505]
const BLOCK := ["r", "t", "W", "q"]


func _init() -> void:
	for n in range(1, 6):
		var path := "res://samples/riverford_%d.json" % n
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var old_rows: Array = d.rows
		var w := old_rows.size()
		var ground := _ground(old_rows)
		var gen := OrganicLayout.new()
		gen.seed = SEEDS[n]
		gen.width = w
		gen.depth = 16
		gen.base_code = ground
		gen.accent_code = _ground(old_rows, ground)
		var m := gen.build()
		var cells := []  # [code, height] per cell, cells[y][x]
		for r in m.rows:
			cells.append(Array(String(r).split(" ")).map(func(t): return [t.substr(0, 1), int(t.substr(1))]))
		var sp: Dictionary = d.spawns
		if int(sp.king[1]) > w / 2:  # Alaric starts on the right in this map: mirror the layout
			cells.reverse()
		var must: Array = [sp.king, sp.captain] + sp.stones + sp.enemies.map(func(e): return e.at)
		for wv in sp.get("waves", []):
			must += wv.enemies.map(func(e): return e.at)
		for c in must:
			_clear(cells, int(c[0]), int(c[1]), ground)
		d.rows = cells.map(func(row): return " ".join(PackedStringArray(row.map(func(t): return "%s%d" % [t[0], t[1]]))))
		var grid := TacticalGrid.from_rows(d.rows)
		var reach := grid.reachable(Vector2i(int(sp.king[0]), int(sp.king[1])), 999, 3)
		for c in must:  # anything still unreachable gets a ramp of steps to its nearest reachable neighbour
			if not reach.can_reach(Vector2i(int(c[0]), int(c[1]))):
				_ramp_to(cells, Vector2i(int(c[0]), int(c[1])), reach, ground)
		d.rows = cells.map(func(row): return " ".join(PackedStringArray(row.map(func(t): return "%s%d" % [t[0], t[1]]))))
		d.life = d.get("life", []).filter(func(l): return not BLOCK.has(cells[int(l.y)][int(l.x)][0]))
		d.name = String(d.get("name", "")) + " (organic layout)"
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d, "\t"))
		print("rebuilt ", path)
	quit()


func _ground(rows: Array, skip := "") -> String:
	var count := {}
	for r in rows:
		for t in String(r).split(" "):
			var c: String = t.substr(0, 1)
			if not c in ["q", "t", "W", "w", "b", "v", skip]:
				count[c] = int(count.get(c, 0)) + 1
	var best := "g" if skip != "g" else "d"
	for c in count:
		if count[c] > int(count.get(best, 0)):
			best = c
	return best


## A spawn cell becomes open ground at a height its neighbours can step to.
func _clear(cells: Array, x: int, y: int, ground: String) -> void:
	var hs := []
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(x, y) + dd
		if c.y >= 0 and c.y < cells.size() and c.x >= 0 and c.x < 16 and not BLOCK.has(cells[c.y][c.x][0]):
			hs.append(cells[c.y][c.x][1])
	hs.sort()
	cells[y][x] = [ground, hs[hs.size() / 2] if not hs.is_empty() else 1]


func _ramp_to(cells: Array, c: Vector2i, reach: MovementRange, ground: String) -> void:
	var best := Vector2i(-1, -1)
	for cell in reach.cells():
		if best.x < 0 or cell.distance_to(c) < best.distance_to(c):
			best = cell
	var p := best
	var hgt: int = cells[p.y][p.x][1]
	while p != c:
		p += Vector2i(signi(c.x - p.x), 0) if p.x != c.x else Vector2i(0, signi(c.y - p.y))
		hgt += clampi(int(cells[c.y][c.x][1]) - hgt, -1, 1)
		cells[p.y][p.x] = [ground if p == c else "d", hgt]
