class_name GeometryResolver
extends RefCounted
## Walks a GeometryPattern over a TacticalGrid: which tiles a unit can aim at, what an aimed attack
## hits, which occupants are in reach, and where a chess-style move can land.
##
## Line rules (per ray, nearest tile first):
##   - leaving the board, or open sky, ends the ray;
##   - an obstacle (tree, placed obstacle) or a tile more than `vertical_reach` above the unit is a
##     wall: it ends the ray and cannot be aimed at;
##   - a tile more than `vertical_reach` below the unit cannot be aimed at, but the ray goes on;
##   - the first occupied tile can be aimed at and ends the ray (no shooting through bodies).
## Jumping patterns (Knight) skip all of that between the unit and the landing tile: each ray is
## one tile, checked on its own.


## Every tile the pattern can aim at from `origin`, in ray order, no repeats.
static func targetable(grid: TacticalGrid, origin: Vector2i, p: GeometryPattern) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var oh := grid.height(origin)
	for ray in p.rays:
		for off in ray:
			var c: Vector2i = origin + off
			if grid.is_void(c):
				if p.jumps:
					continue
				break
			if grid.is_obstacle(c) or grid.height(c) - oh > p.vertical_reach:
				if p.jumps:
					continue
				break
			if absi(grid.height(c) - oh) <= p.vertical_reach and not out.has(c):
				out.append(c)
			if grid.is_occupied(c) and not p.jumps:
				break
	return out


## What an attack aimed at `aim` hits. Empty if `aim` cannot be targeted from `origin`.
static func affected(grid: TacticalGrid, origin: Vector2i, p: GeometryPattern, aim: Vector2i) -> TargetArea:
	var area := TargetArea.new()
	area.origin = origin
	area.aim = aim
	if not targetable(grid, origin, p).has(aim):
		return area
	var dir := Vector2i(signi(aim.x - origin.x), signi(aim.y - origin.y))  # line of attack
	area.tiles.append(aim)
	var c := aim
	for i in p.pierce:  # carry on behind the target
		c += dir
		if grid.is_void(c) or grid.is_obstacle(c) or absi(grid.height(c) - grid.height(aim)) > p.vertical_reach:
			break
		area.tiles.append(c)
	var extra: Array[Vector2i] = []
	match p.splash:
		GeometryPattern.Splash.CROSS:
			extra.assign(TacticalMath.ORTHOGONAL)
		GeometryPattern.Splash.CLEAVE:
			var side := Vector2i(-dir.y, dir.x)
			extra.assign([side, -side])
	for e in extra:
		var s := aim + e
		if s == origin or area.tiles.has(s) or grid.is_void(s):
			continue
		if absi(grid.height(s) - grid.height(aim)) > p.vertical_reach:
			continue
		area.tiles.append(s)
	for t in area.tiles:
		if t != origin and grid.is_occupied(t):
			area.occupants.append(grid.occupant(t))
	return area


## Occupants the pattern can aim at directly. `team` >= 0 keeps only that team; `exclude_team` >= 0
## drops that team (e.g. pass the attacker's team to list only foes).
static func in_reach(grid: TacticalGrid, origin: Vector2i, p: GeometryPattern, team := -1, exclude_team := -1) -> Array:
	var out: Array = []
	for c in targetable(grid, origin, p):
		if not grid.is_occupied(c) or c == origin:
			continue
		var t := grid.team_at(c)
		if (team >= 0 and t != team) or (exclude_team >= 0 and t == exclude_team):
			continue
		out.append(grid.occupant(c))
	return out


## Where a chess-style move with this pattern can land: aimable tiles that are free to stand on.
## Pierce and splash do not apply to moving.
static func move_tiles(grid: TacticalGrid, origin: Vector2i, p: GeometryPattern) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in targetable(grid, origin, p):
		if grid.can_stand(c):
			out.append(c)
	return out
