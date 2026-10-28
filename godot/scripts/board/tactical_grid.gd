class_name TacticalGrid
extends RefCounted
## The board's rules: cells, heights, terrain, obstacles and who stands where. No drawing (Terrain
## draws the same map) and no unit logic beyond occupancy.
##
## Cells are Vector2i(x, y), 0 <= x < width, 0 <= y < depth; each has a terrain code and a whole
## height level (the map format of Terrain.parse: rows of "<terrain><height>").
##
## Occupants are any value that can be a Dictionary key (a unit node, a resource, an id). Each has a
## team; units pass through allies and knocked-out bodies of any team while walking, never through
## standing enemies, and never end on anyone (bodies included). An occupant counts as a body when it has
## an is_down() method that returns true (BattleUnit does).

## Terrain no one can stand on or walk through: deep water, lava, trees, open sky.
const IMPASSABLE := ["W", "l", "t", "v"]
## Terrain that blocks targeting lines (and walking). Water, lava and sky do not block lines.
const LINE_BLOCKERS := ["t"]
## Walking cost per terrain; anything not listed costs 1.
const MOVE_COST := {"w": 2, "m": 2}
const NO_CELL := Vector2i(-1, -1)

var width := 0
var depth := 0
var _terrain: Array[String] = []
var _height: PackedInt32Array = []
var _blocked := {}  ## Vector2i -> true: obstacles placed on top of terrain (props, rubble, relic objects)
var _occ := {}  ## Vector2i -> {"ref": occupant, "team": int}
var _cell_of := {}  ## occupant -> Vector2i


## Builds a grid from a parsed map (Terrain.parse / Terrain.load_map): {w, d, tiles[y][x] = {t, h}}.
static func from_map(map: Dictionary) -> TacticalGrid:
	var g := TacticalGrid.new()
	g.width = map.w
	g.depth = map.d
	g._height.resize(g.width * g.depth)
	g._terrain.resize(g.width * g.depth)
	for y in g.depth:
		for x in g.width:
			var t: Dictionary = map.tiles[y][x]
			g._terrain[y * g.width + x] = String(t.t)
			g._height[y * g.width + x] = int(t.h)
	return g


## Builds a grid straight from rows of "<terrain><height>" codes, e.g. ["g0 g1", "W0 g2"].
static func from_rows(rows: Array) -> TacticalGrid:
	return from_map(Terrain.parse({"rows": rows}))


# ---------- cells ----------

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < depth


func terrain(c: Vector2i) -> String:
	return _terrain[c.y * width + c.x] if in_bounds(c) else "v"


func height(c: Vector2i) -> int:
	return _height[c.y * width + c.x] if in_bounds(c) else 0


func is_void(c: Vector2i) -> bool:
	return not in_bounds(c) or terrain(c) == "v"


## An obstacle stands on the cell (a tree or a placed obstacle): blocks walking and targeting lines.
func is_obstacle(c: Vector2i) -> bool:
	return _blocked.has(c) or terrain(c) in LINE_BLOCKERS


## Terrain and obstacles allow standing here (ignores occupants).
func is_passable(c: Vector2i) -> bool:
	return in_bounds(c) and not _blocked.has(c) and not terrain(c) in IMPASSABLE


func add_obstacle(c: Vector2i) -> void:
	if in_bounds(c):
		_blocked[c] = true


func remove_obstacle(c: Vector2i) -> void:
	_blocked.erase(c)


func neighbors4(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in TacticalMath.ORTHOGONAL:
		if in_bounds(c + d):
			out.append(c + d)
	return out


# ---------- occupancy ----------

func is_occupied(c: Vector2i) -> bool:
	return _occ.has(c)


func occupant(c: Vector2i) -> Variant:
	return _occ[c].ref if _occ.has(c) else null


## Team of whoever stands on the cell, or -1.
func team_at(c: Vector2i) -> int:
	return _occ[c].team if _occ.has(c) else -1


func cell_of(ref: Variant) -> Vector2i:
	return _cell_of.get(ref, NO_CELL)


## A knocked-out unit lies here (its occupant has is_down() and it returns true).
func is_body(c: Vector2i) -> bool:
	var o = occupant(c)
	return o is Object and o.has_method("is_down") and o.is_down()


## Free for someone to end a move on: passable and empty.
func can_stand(c: Vector2i) -> bool:
	return is_passable(c) and not is_occupied(c)


## Puts an occupant on a cell. Fails (false) if the cell cannot be stood on or the occupant is already placed.
func place(ref: Variant, c: Vector2i, team := 0) -> bool:
	if not can_stand(c) or _cell_of.has(ref):
		return false
	_occ[c] = {"ref": ref, "team": team}
	_cell_of[ref] = c
	return true


## Moves a placed occupant to another free cell. Rules for whether the move is allowed live elsewhere.
func move_occupant(ref: Variant, to: Vector2i) -> bool:
	var from := cell_of(ref)
	if from == NO_CELL or not can_stand(to):
		return false
	_occ[to] = _occ[from]
	_occ.erase(from)
	_cell_of[ref] = to
	return true


func remove(ref: Variant) -> void:
	var c := cell_of(ref)
	if c != NO_CELL:
		_occ.erase(c)
		_cell_of.erase(ref)


func occupants() -> Array:
	return _cell_of.keys()


# ---------- walking ----------

## Cost of one walking step between neighbouring cells for a unit with this Jump, or -1 if not allowed.
func step_cost(from: Vector2i, to: Vector2i, jump: int) -> int:
	if not is_passable(to):
		return -1
	if absi(height(to) - height(from)) > jump:
		return -1
	return MOVE_COST.get(terrain(to), 1)


## Every cell a unit at `origin` can walk to with `move` points and `jump` levels of climb.
## The unit passes through its own team and through knocked-out bodies, not standing units of other
## teams, and cannot end on an occupied cell.
func reachable(origin: Vector2i, move: int, jump: int, team := 0) -> MovementRange:
	var r := MovementRange.new()
	r.origin = origin
	var best := {origin: 0}
	var open: Array[Vector2i] = [origin]
	while not open.is_empty():
		var bi := 0
		for i in open.size():  # boards are small, so a linear scan for the cheapest open cell is fine
			if best[open[i]] < best[open[bi]]:
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		for n in neighbors4(c):
			var sc := step_cost(c, n, jump)
			if sc < 0:
				continue
			if is_occupied(n) and team_at(n) != team and not is_body(n):
				continue  # standing enemies block the way; bodies do not
			var nc: int = best[c] + sc
			if nc > move or (best.has(n) and best[n] <= nc):
				continue
			best[n] = nc
			r.came_from[n] = c
			if not open.has(n):
				open.append(n)
	for c in best:
		if c == origin or not is_occupied(c):
			r.costs[c] = best[c]
	return r


## Shortest walking path from `from` to `to` (both cells; `to` excluded if occupied), ignoring Move.
## Empty when there is no way.
func find_path(from: Vector2i, to: Vector2i, jump: int, team := 0) -> Array[Vector2i]:
	return reachable(from, width * depth * 2, jump, team).path_to(to)
