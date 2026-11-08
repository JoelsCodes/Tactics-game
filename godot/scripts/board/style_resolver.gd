class_name StyleResolver
extends RefCounted
## Where a weapon attack (or Physical skill) can be aimed and what it hits, for each weapon style (geometry) and stance. The rules are
## in StanceRules' header. Plain functions over a TacticalGrid.
##
## Aiming: `targetable` is every tile the player may click. For the line styles (Rook, Bishop, Queen) clicking any tile on a line picks
## that direction; the Pawn picks one of its front tiles; the Knight one of its jumps; the King one of the tiles around it. Styles that
## hit everything at once (the King's and Pawn's all-round hits) still need a click on one of their tiles to confirm.

const HIGH_REACH := 1  ## every attack and skill can also hit one level higher than the attacker (owner, Nov 2026); two or more is blocked
const KNIGHT_CLIMB := 2  ## levels higher than itself a Knight can land (plus HIGH_REACH)
const QUEEN_IMPACT_RANGE := 2
const MAP_WIDE := 99
const G := TacticalMath.Geometry


## Whether `c` stops a line from a tile at height `oh`: void, an obstacle, or ground more than HIGH_REACH higher than the attacker's level.
static func blocks(grid: TacticalGrid, c: Vector2i, oh: int) -> bool:
	return grid.is_void(c) or grid.is_obstacle(c) or grid.height(c) > oh + HIGH_REACH


## The directions a line style may use from a facing (cardinal).
static func directions(geometry: G, facing: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var side := Vector2i(-facing.y, facing.x)
	match geometry:
		G.ROOK:
			out.append(facing)
		G.BISHOP:
			out.append(facing + side)
			out.append(facing - side)
		G.QUEEN:
			out.assign(TacticalMath.ORTHOGONAL + TacticalMath.DIAGONAL)
	return out


## The tiles along `dir` from `origin`, nearest first, up to `max_steps`, ending before the first blocking tile. Units do not block.
static func line(grid: TacticalGrid, origin: Vector2i, dir: Vector2i, max_steps: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var oh := grid.height(origin)
	for i in range(1, max_steps + 1):
		var c := origin + dir * i
		if blocks(grid, c, oh):
			break
		out.append(c)
	return out


## A tile around the King or in front of the Pawn that can be aimed at: standing ground, no higher than the attacker.
static func _near_ok(grid: TacticalGrid, c: Vector2i, oh: int) -> bool:
	return not blocks(grid, c, oh)


static func _front_tiles(facing: Vector2i) -> Array[Vector2i]:
	var side := Vector2i(-facing.y, facing.x)
	return [facing, facing + side, facing - side]


static func _steps(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(b.x - a.x), absi(b.y - a.y))


## Every tile the attack can be aimed at.
static func targetable(grid: TacticalGrid, origin: Vector2i, geometry: G, stance: WeaponStyle.Stance, facing: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var oh := grid.height(origin)
	match geometry:
		G.ROOK, G.BISHOP, G.QUEEN:
			var reach := QUEEN_IMPACT_RANGE if geometry == G.QUEEN and stance == WeaponStyle.Stance.IMPACT else MAP_WIDE
			for d in directions(geometry, facing):
				out.append_array(line(grid, origin, d, reach))
		G.KNIGHT:
			for j in TacticalMath.KNIGHT_JUMPS:
				var c: Vector2i = origin + j
				if grid.is_void(c) or grid.is_obstacle(c) or grid.height(c) - oh > KNIGHT_CLIMB + HIGH_REACH:
					continue
				out.append(c)
		G.KING:
			for d in TacticalMath.ORTHOGONAL + TacticalMath.DIAGONAL:
				if _near_ok(grid, origin + d, oh):
					out.append(origin + d)
		G.PAWN:
			var tiles := _front_tiles(facing)
			if stance == WeaponStyle.Stance.IMPACT:
				tiles = [facing]
			for t in tiles:
				if _near_ok(grid, origin + t, oh):
					out.append(origin + t)
	return out


## What an attack aimed at `aim` hits, and the damage percent on each tile. Empty if `aim` is not targetable.
static func affected(grid: TacticalGrid, origin: Vector2i, geometry: G, stance: WeaponStyle.Stance, facing: Vector2i, aim: Vector2i) -> TargetArea:
	var area := TargetArea.new()
	area.origin = origin
	area.aim = aim
	var aimable := targetable(grid, origin, geometry, stance, facing)
	if not aimable.has(aim):
		return area
	var pierce := stance == WeaponStyle.Stance.PIERCE
	match geometry:
		G.ROOK, G.BISHOP, G.QUEEN:
			var dir := Vector2i(signi(aim.x - origin.x), signi(aim.y - origin.y))
			var reach := QUEEN_IMPACT_RANGE if geometry == G.QUEEN and not pierce else MAP_WIDE
			var tiles := line(grid, origin, dir, reach)
			if pierce:
				for t in tiles:
					_add(area, t, StanceRules.distance_percent(_steps(origin, t)))
			else:
				var hit := aim
				for t in tiles:  # Impact stops at the first unit on the line, ally or foe
					if grid.is_occupied(t):
						hit = t
						break
				var pct := 50 if geometry == G.QUEEN else StanceRules.distance_percent(_steps(origin, hit))
				_add(area, hit, pct)
		G.KNIGHT:
			_add(area, aim, 50 if pierce else 100)
			if pierce:  # the two tiles the L passes through
				var j := aim - origin
				var long_dir := Vector2i(signi(j.x), 0) if absi(j.x) == 2 else Vector2i(0, signi(j.y))
				for k in [1, 2]:
					var p: Vector2i = origin + long_dir * k
					if not grid.is_void(p) and not grid.is_obstacle(p):
						_add(area, p, 25)
		G.KING:
			if pierce:
				for t in aimable:
					_add(area, t, 33)
			else:
				_add(area, aim, 100)
		G.PAWN:
			match stance:
				WeaponStyle.Stance.AXE:
					for t in aimable:
						_add(area, t, 33)
				WeaponStyle.Stance.PIERCE:
					_add(area, aim, 50)
				_:
					_add(area, aim, 100)
	for t in area.tiles:
		if t != origin and grid.is_occupied(t):
			area.occupants.append(grid.occupant(t))
	return area


static func _add(area: TargetArea, t: Vector2i, percent: int) -> void:
	if not area.tiles.has(t):
		area.tiles.append(t)
	area.percents[t] = percent
