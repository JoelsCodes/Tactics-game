class_name StonePlacement
extends RefCounted
## Where the summon stones lie (owner, Nov 2026: "not every relic should be near the player; put them where they add strategy").
## Every world-map battle gets five stones in three kinds (the chapter's own three, plus two this adds):
##
##   REACH (2)   on the edge of Alaric's summon range from where he starts (DeploymentManager.summon_radius), spread apart: he can
##               summon onto them at once. Never next to him.
##   FIELD (2)   out in the middle of the map, beyond his starting range, about a third to two thirds of the way to the enemy, one
##               on each flank where the map allows, on the highest ground on offer: he has to advance to use them, and a vessel
##               summoned there holds a flank or a height.
##   PRIZE (1)   deep on the enemy's side (never within PRIZE_GAP tiles of an enemy's start, never usable on the first turn). It
##               carries the best rank among the map's stones, with a skill no other stone on the map has: the reward for pushing
##               Alaric forward. Marked on the relic (`is_prize`) so the stage shows it in gold.
##
## No two stones of a map carry the same skill when the rank has enough skills to choose from. Ranks never go above what the
## chapter's own stones rolled, so a chapter's rank limits hold (stones_check).
## The layout is fixed per map (seeded by the map path), so a map always looks the same and can be learned; the skills are rolled
## anew every battle. The tutorial battles (hallway, chamber) keep their own stones. A map with no stones gets none.

const BAND := 1.0  ## "on the edge": within this many tiles inside the radius
const REACH := 2
const FIELD := 2
const PRIZE := 1
const SAFE_GAP := 6  ## a stone Alaric could summon onto on the first turn is more than this many steps from every enemy (Move plus 1)
const PRIZE_GAP := 4  ## the prize stone is at least this many steps from every enemy's start
const KING_STEP := 5  ## how far Alaric can walk in one turn, for "not usable on the first turn"
const META_KIND := "stone_kind"  ## RelicItem meta: "reach", "field" or "prize"


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
	var king := Vector2(s.king_cell)
	var centre := king
	if not foes.is_empty():
		centre = Vector2.ZERO
		for f in foes:
			centre += Vector2(f)
		centre /= foes.size()
	var axis := centre - king
	var span := maxf(axis.length(), 1.0)
	var dir := axis / span
	var side := Vector2(-dir.y, dir.x)
	# every tile a unit could stand on and walk to from Alaric, with how far along the way to the enemy it is and on which flank
	var walk := grid.reachable(s.king_cell, 999, 2)
	var ring: Array[Vector2i] = []
	var field: Array[Vector2i] = []
	var prize: Array[Vector2i] = []
	var info := {}  # cell -> [progress 0..1, flank (signed tiles), height]
	for x in grid.width:
		for y in grid.depth:
			var c := Vector2i(x, y)
			if taken.has(c) or not grid.can_stand(c):
				continue
			# a vessel summoned there must be able to join the fight: Alaric can walk to the tile, or a unit standing on it can walk down to him
			if not walk.can_reach(c) and grid.find_path(c, s.king_cell, 2).is_empty():
				continue
			var off := Vector2(c) - king
			var d := off.length()
			var gap := _gap(c, foes)
			var t := off.dot(dir) / span
			info[c] = [t, off.dot(side), grid.height(c)]
			var first_turn := d <= r + KING_STEP  # Alaric can summon onto it on turn one (after a walk)
			if d <= r + 0.001 and d >= r - BAND and gap > SAFE_GAP:
				ring.append(c)
			if d > r + 1.0 and t >= 0.3 and t <= 0.68 and (gap > SAFE_GAP or not first_turn) and gap >= PRIZE_GAP:
				field.append(c)
			if t > 0.62 and t <= 1.05 and gap >= PRIZE_GAP and not first_turn:
				prize.append(c)
	# the chapter's own stones first (reach, reach, then a field stone), then the stones this adds
	var kinds: Array[String] = []
	var own := s.relics.size()
	for i in own:
		kinds.append("reach" if i < REACH else "field")
	for i in range(own, REACH + FIELD):
		kinds.append("field")
	for i in PRIZE:
		kinds.append("prize")
	_add_stones(s, kinds.size() - own, rng)
	var chosen: Array[Vector2i] = []
	var flank_used := 0.0
	for i in s.relics.size():
		var kind := kinds[i]
		var pool := ring
		if kind == "field":
			pool = field
		elif kind == "prize":
			pool = prize if not prize.is_empty() else field
		if pool.is_empty():
			pool = ring if not ring.is_empty() else field
		if pool.is_empty():
			continue  # nowhere to put it (a tiny map): the stone keeps its old place
		var best := _pick(pool, chosen, info, kind, flank_used, rng)
		if kind == "field":
			flank_used = signf(float(info[best][1])) if flank_used == 0.0 else 0.0
		chosen.append(best)
		for p in [ring, field, prize]:
			p.erase(best)
		var relic: RelicItem = s.relics[i][0]
		relic.set_meta(META_KIND, kind)
		s.relics[i] = [relic, best]
	_make_prize(s, rng)
	_no_twins(s, rng)


## "reach", "field" or "prize" ("" for a stone this never placed).
static func kind_of(relic: RelicItem) -> String:
	return String(relic.get_meta(META_KIND, "")) if relic != null else ""


static func is_prize(relic: RelicItem) -> bool:
	return kind_of(relic) == "prize"


## Steps (Manhattan) from `c` to the nearest enemy start.
static func _gap(c: Vector2i, foes: Array[Vector2i]) -> int:
	var best := 999
	for f in foes:
		best = mini(best, absi(f.x - c.x) + absi(f.y - c.y))
	return best


## Adds `n` stones to the setup, each of the rank of one of the chapter's own stones (so the chapter's rank limits hold).
static func _add_stones(s: BattleSetup, n: int, rng: RandomNumberGenerator) -> void:
	var own := s.relics.size()
	for i in n:
		var like: RelicItem = s.relics[rng.randi() % own][0]
		var pool := SkillLibrary.of_rank(like.skill.rank) if like.skill != null else SummonStone.e_skills()
		var relic := RelicItem.new()
		relic.display_name = SummonStone.NAME
		relic.skill = pool[randi() % pool.size()]  # the skill is new every battle (only the layout is fixed)
		s.relics.append([relic, s.relics[0][1]])


## The prize stone carries the best rank the map's stones rolled.
static func _make_prize(s: BattleSetup, _rng: RandomNumberGenerator) -> void:
	var top := SkillData.Rank.E
	var prize: RelicItem = null
	for p in s.relics:
		var relic: RelicItem = p[0]
		if relic.skill != null and relic.skill.rank > top:
			top = relic.skill.rank
		if is_prize(relic):
			prize = relic
	if prize == null or prize.skill == null or prize.skill.rank == top:
		return
	var pool := SkillLibrary.of_rank(top)
	if not pool.is_empty():
		prize.skill = pool[randi() % pool.size()]


## No two stones with the same skill, where the rank has another one to give.
static func _no_twins(s: BattleSetup, _rng: RandomNumberGenerator) -> void:
	var seen := {}
	for p in s.relics:
		var relic: RelicItem = p[0]
		if relic.skill == null:
			continue
		if seen.has(relic.skill):
			var pool := SkillLibrary.of_rank(relic.skill.rank).filter(func(k): return not seen.has(k))
			if not pool.is_empty():
				relic.skill = pool[randi() % pool.size()]
		seen[relic.skill] = true


## The best of a few random candidates for a stone of `kind`: far from the stones already placed, and for the field and prize
## stones on high ground, out on a flank (the second field stone on the other flank), the prize as deep as it can go.
static func _pick(pool: Array[Vector2i], chosen: Array[Vector2i], info: Dictionary, kind: String, flank_used: float, rng: RandomNumberGenerator) -> Vector2i:
	var best := pool[rng.randi() % pool.size()]
	var best_score := -INF
	for k in 24:
		var c := pool[rng.randi() % pool.size()]
		var apart := 12.0
		for o in chosen:
			apart = minf(apart, Vector2(c - o).length())
		var score := apart
		if kind != "reach":
			var i: Array = info[c]
			score = minf(apart, 6.0) + float(i[2]) * 1.5 + (2.5 - absf(absf(float(i[1])) - 4.5) * 0.5)  # about four tiles out on a flank, not hugging the map's rim
			if kind == "field" and flank_used != 0.0 and signf(float(i[1])) == flank_used:
				score -= 4.0  # the second field stone belongs on the other flank
			if kind == "prize":
				score += float(i[0]) * 6.0
		if score > best_score:
			best_score = score
			best = c
	return best
