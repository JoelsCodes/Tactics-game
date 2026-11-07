class_name StonePlacement
extends RefCounted
## Where the summon stones lie (owner, Nov 2026): not next to Alaric, but on the edge of his summon range (DeploymentManager.summon_radius,
## measured from his starting tile), spread apart; on some maps one stone lies a little outside it (1-2 tiles), so he has to walk to use it.
## Applied to every world-map battle (WorldData.setup_for). The tutorial battles (hallway, chamber) keep their own stones.
## The layout is fixed per map (seeded by the map path), so a map always looks the same.

const OUTSIDE_CHANCE := 0.35  ## a map's chance of one stone just outside the range
const BAND := 1.0  ## "on the edge": within this many tiles inside the radius


static func place(s: BattleSetup) -> void:
	if s.relics.is_empty():
		return
	var grid := TacticalGrid.from_map(Terrain.load_map(s.map_path))
	var r := DeploymentManager.SUMMON_RANGE_SHARE * maxi(grid.width, grid.depth)
	var taken := {s.king_cell: true}
	if s.captain_cell != TacticalGrid.NO_CELL:
		taken[s.captain_cell] = true
	var foes: Array[Vector2i] = []
	for e in s.enemies:
		taken[e[1]] = true
		foes.append(e[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(s.map_path.hash())
	var outside := rng.randf() < OUTSIDE_CHANCE
	var ring: Array[Vector2i] = []
	var near_out: Array[Vector2i] = []
	for x in grid.width:
		for y in grid.depth:
			var c := Vector2i(x, y)
			if taken.has(c) or not grid.can_stand(c) or _near_foe(c, foes):
				continue
			var d := Vector2(c - s.king_cell).length()
			if d <= r + 0.001 and d >= r - BAND:
				ring.append(c)
			elif d > r + 0.001 and d <= r + 2.0:
				near_out.append(c)
	var chosen: Array[Vector2i] = []
	for i in s.relics.size():
		var pool := near_out if (outside and i == s.relics.size() - 1 and not near_out.is_empty()) else ring
		if pool.is_empty():
			pool = near_out
		if pool.is_empty():
			continue  # nowhere on the edge (a tiny map): the stone keeps its old place
		var best := _spread(pool, chosen, rng)
		chosen.append(best)
		pool.erase(best)
		s.relics[i] = [s.relics[i][0], best]


## Not right next to an enemy's starting tile.
static func _near_foe(c: Vector2i, foes: Array[Vector2i]) -> bool:
	for f in foes:
		if absi(f.x - c.x) + absi(f.y - c.y) <= 3:
			return true
	return false


## Of a few random candidates, the one farthest from the stones already placed.
static func _spread(pool: Array[Vector2i], chosen: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	var best := pool[rng.randi() % pool.size()]
	var best_d := -1.0
	for k in 12:
		var c := pool[rng.randi() % pool.size()]
		var d := 999.0
		for o in chosen:
			d = minf(d, Vector2(c - o).length())
		if d > best_d:
			best_d = d
			best = c
	return best
