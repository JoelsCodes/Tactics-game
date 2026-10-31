class_name OutsideCastle
extends RefCounted
## The castle around a story map, made up from the map's size alone and the same every time: a lattice of wall
## lines (the map's own outer walls are two of them in each direction, so the map is one room of the lattice) with
## rooms between them, each at its own level and kind (plain flagstone, overgrown, pillared, dais, solid keep, carved
## cross), doorways in the walls, towers where walls cross, and the dark behind the map's far doors. A cell is
## {"t": a tile code of Terrain.LOOK, "h": level}. Scenery for Board3D, never part of the map's grid.
## Toward the camera (x < 0) blocks are kept low so they never hide the map.

const SPAN_MIN := 7  ## tiles between two wall lines: at least this ...
const SPAN_VAR := 6  ## ... and up to this many more
const DOOR_CHANCE := 0.55  ## how many wall stretches have a two-tile doorway
const DARK_LEN := 5  ## tiles of dark behind each of the map's far doors
const PLAIN := 0
const MOSS := 1
const PILLARS := 2
const DAIS := 3
const KEEP := 4
const CROSS := 5

var w: int  ## the map's size in tiles
var d: int
var xl: Array[int] = []  ## wall line columns, sorted (0 and w - 1 are the map's own walls)
var yl: Array[int] = []  ## wall line rows, sorted (0 and d - 1 are the map's own walls)
var dark_rows: Array[int] = []  ## rows of the map's far doors: the dark runs on behind them
var _memo := {}


## `lo` and `hi` are the corners (in tiles) the lattice must cover.
func _init(map_w: int, map_d: int, lo: Vector2i, hi: Vector2i, p_dark_rows: Array[int]) -> void:
	w = map_w
	d = map_d
	dark_rows = p_dark_rows
	xl = _lines(0, w - 1, lo.x, hi.x, 1)
	yl = _lines(0, d - 1, lo.y, hi.y, 2)


## The cell at (x, y), outside the map.
func cell(x: int, y: int) -> Dictionary:
	var key := Vector2i(x, y)
	if not _memo.has(key):
		_memo[key] = _make(x, y)
	return _memo[key]


func _lines(a: int, b: int, lo: int, hi: int, k: int) -> Array[int]:
	var out: Array[int] = [a, b]
	var cur := a
	var i := 1
	while cur > lo:
		cur -= SPAN_MIN + int(Terrain.hash01(i, k, 11) * SPAN_VAR)
		out.append(cur)
		i += 1
	cur = b
	i = 1
	while cur < hi:
		cur += SPAN_MIN + int(Terrain.hash01(i, k, 12) * SPAN_VAR)
		out.append(cur)
		i += 1
	out.sort()
	return out


## The index i of the stretch between lines[i] and lines[i + 1] that holds v (not on a line), or -1.
func _seg(lines: Array[int], v: int) -> int:
	for i in lines.size() - 1:
		if v > lines[i] and v < lines[i + 1]:
			return i
	return -1


## The most a block at column x may rise: low toward the camera so it does not hide the map behind it.
func _cap(x: int, h: int, floor_level: int) -> int:
	if x >= 0:
		return h
	return mini(h, maxi(floor_level, 2 + int((-x) / 4.0)))


func _make(x: int, y: int) -> Dictionary:
	if x >= w and x < w + DARK_LEN and y in dark_rows:
		return {"t": "v", "h": 0}
	var lx := xl.has(x)
	var ly := yl.has(y)
	if lx or ly:
		return _wall(x, y, lx, ly)
	return _room(x, y)


# ---------- walls ----------

func _wall(x: int, y: int, lx: bool, ly: bool) -> Dictionary:
	if lx and ly:  # a tower where two walls cross
		return {"t": "q", "h": _cap(x, 6 + int(Terrain.hash01(x, y, 3) * 3), 0)}
	var line := x if lx else y  # a wall on a column line runs along y, and the other way round
	var v := y if lx else x
	var lines := yl if lx else xl
	var i := _seg(lines, v)
	if i < 0:
		return {"t": "q", "h": 4}
	var s := lines[i]
	var e := lines[i + 1]
	var a := _room_level(x - 1, y) if lx else _room_level(x, y - 1)  # the rooms on either side
	var b := _room_level(x + 1, y) if lx else _room_level(x, y + 1)
	var span := e - s - 1
	if span >= 4 and Terrain.hash01(line, s, 5) < DOOR_CHANCE:
		var k := int(Terrain.hash01(line, s, 6) * (span - 1))
		if v == s + 1 + k or v == s + 2 + k:  # a doorway: floor at the lower room's level
			return {"t": "f", "h": mini(a, b)}
	var h := 3 + int(Terrain.hash01(line, s, 4) * 4)
	h = maxi(h, maxi(a, b) + 2)
	return {"t": "q", "h": _cap(x, h, 0)}


# ---------- rooms ----------

func _is_ante(x0: int, y0: int, x1: int, y1: int) -> bool:  # the room in front of the map's entrance wall
	return x1 == -1 and y0 == 1 and y1 == d - 2


func _is_back(x0: int, y0: int, x1: int, y1: int) -> bool:  # the room behind the map's far doors
	return x0 == w and y0 == 1 and y1 == d - 2


## The floor level of the room around (x, y); 1 inside the map.
func _room_level(x: int, y: int) -> int:
	if x >= 0 and y >= 0 and x < w and y < d:
		return 1
	var ix := _seg(xl, x)
	var iy := _seg(yl, y)
	if ix < 0 or iy < 0:
		return 1
	return _level(xl[ix] + 1, yl[iy] + 1, xl[ix + 1] - 1, yl[iy + 1] - 1)


func _level(x0: int, y0: int, x1: int, y1: int) -> int:
	if _is_ante(x0, y0, x1, y1):
		return 1
	var r := Terrain.hash01(x0, y0, 8)
	return 0 if r < 0.15 else (1 if r < 0.5 else (2 if r < 0.8 else 3))


func _kind(x0: int, y0: int, x1: int, y1: int) -> int:
	if _is_ante(x0, y0, x1, y1):
		return PLAIN
	if _is_back(x0, y0, x1, y1):
		return KEEP
	var r := Terrain.hash01(x0, y0, 7)
	if r < 0.30:
		return PLAIN
	if r < 0.45:
		return MOSS
	if r < 0.60:
		return PILLARS
	if r < 0.75:
		return DAIS
	if r < 0.88:
		return KEEP
	return CROSS


func _room(x: int, y: int) -> Dictionary:
	var ix := _seg(xl, x)
	var iy := _seg(yl, y)
	if ix < 0 or iy < 0:
		return {"t": "f", "h": 1}
	var x0 := xl[ix] + 1
	var y0 := yl[iy] + 1
	var x1 := xl[ix + 1] - 1
	var y1 := yl[iy + 1] - 1
	var lvl := _level(x0, y0, x1, y1)
	var kind := _kind(x0, y0, x1, y1)
	var ox := x - x0
	var oy := y - y0
	var floor_cell := {"t": "f", "h": lvl}
	if kind == KEEP:  # a solid mass: a tower or a keep seen from above
		return {"t": "q", "h": _cap(x, 5 + int(Terrain.hash01(x0, y0, 9) * 4), 0)}
	if kind == DAIS:  # a stepped platform: carved top on a framed step on the floor
		var de := mini(mini(ox, oy), mini(x1 - x, y1 - y))
		if de >= 2:
			return {"t": "e", "h": _cap(x, lvl + 2, lvl)}
		if de == 1:
			return {"t": "o", "h": _cap(x, lvl + 1, lvl)}
		return floor_cell
	if kind == CROSS:  # a carved path across the middle
		if x == int((x0 + x1) / 2.0) or y == int((y0 + y1) / 2.0):
			return {"t": "e", "h": lvl}
		return floor_cell
	if kind == PILLARS and ox % 3 == 1 and oy % 3 == 1 and x < x1 and y < y1:
		return {"t": "q", "h": _cap(x, lvl + 3, lvl)}
	if kind == MOSS or (kind == PILLARS and Terrain.hash01(x, y, 13) < 0.25):
		floor_cell = {"t": "h", "h": lvl}
	if Terrain.hash01(x, y, 14) < 0.02:  # a fallen block
		return {"t": "q", "h": _cap(x, lvl + 1, lvl)}
	return floor_cell
