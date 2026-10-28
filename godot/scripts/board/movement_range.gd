class_name MovementRange
extends RefCounted
## The result of a walking search (TacticalGrid.reachable): every cell a unit can end its move on,
## the cost to get there, and the paths.

var origin: Vector2i
var costs := {}  ## Vector2i -> int, only cells the unit may end on (origin included, cost 0)
var came_from := {}  ## Vector2i -> Vector2i, for every visited cell (including pass-through cells)


func can_reach(cell: Vector2i) -> bool:
	return costs.has(cell)


func cost_to(cell: Vector2i) -> int:
	return costs.get(cell, -1)


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(costs.keys())
	return out


## Steps from the origin (excluded) to `cell` (included). Empty if unreachable or `cell` is the origin.
func path_to(cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not can_reach(cell):
		return path
	var c := cell
	while c != origin:
		path.push_front(c)
		c = came_from[c]
	return path
