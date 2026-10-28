class_name TacticalMath
extends RefCounted
## Core progression and scaling math. Static functions only; nothing here holds state.
##
## Levels run from 0 (unlearned / base) to 99 (max masterwork). Every level adds 2% to whatever it
## scales: multiplier = 1.0 + 0.02 x level, so level 0 = x1.00, level 50 = x2.00, level 99 = x2.98.
## The same curve drives weapon power (smithing level), skill power (proficiency level) and the
## character's HP and SP pools (character level).
##
## Numbers stay small and readable: results are rounded to whole numbers and the hard caps below keep
## HP and SP in the Tactics Ogre / FFT range.

const MIN_LEVEL := 0
const MAX_LEVEL := 99
const LEVEL_STEP := 0.02  ## multiplier gained per level
const PROGRESS_PER_LEVEL := 100  ## a proficiency bar holds 100 points

## Proficiency aptitude: how fast a proficiency fills its bar. S learns fastest, F slowest.
enum Rank { S, A, B, C, D, E, F }

## Bar points gained per use at efficiency 1.0. At C, a level takes 10 uses.
const RANK_GAIN := {
	Rank.S: 20,
	Rank.A: 16,
	Rank.B: 13,
	Rank.C: 10,
	Rank.D: 8,
	Rank.E: 6,
	Rank.F: 4,
}
const RANK_LETTERS := ["S", "A", "B", "C", "D", "E", "F"]

## Chess vector geometry for weapon styles (see WeaponStyle).
## Pawn reaches one step forward and the two forward diagonals, so it depends on facing.
enum Geometry { ROOK, BISHOP, KNIGHT, QUEEN, KING, PAWN }

const ORTHOGONAL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const KNIGHT_JUMPS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
]


# ---------- levels and scaling ----------

static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


## Power / SP multiplier for a level: 1.0 + 0.02 x level (level clamped to 0..99).
static func multiplier(level: int) -> float:
	return 1.0 + LEVEL_STEP * clamp_level(level)


## A base value scaled by a level, rounded to a whole number.
static func scale(base: float, level: int) -> int:
	return roundi(base * multiplier(level))


# ---------- proficiency ----------

static func rank_letter(rank: Rank) -> String:
	return RANK_LETTERS[rank]


static func rank_from_letter(letter: String) -> Rank:
	var i := RANK_LETTERS.find(letter.to_upper())
	assert(i >= 0, "unknown proficiency rank '%s'" % letter)
	return i as Rank


## Bar points one use earns: the rank's gain times the character's proficiency efficiency.
## Always at least 1, so every use counts.
static func proficiency_gain(rank: Rank, efficiency := 1.0) -> int:
	return maxi(1, roundi(RANK_GAIN[rank] * efficiency))


## Adds bar points to a (level, progress) pair and carries full bars into levels.
## Returns Vector2i(new_level, new_progress). At level 99 the bar stays empty.
static func add_progress(level: int, progress: int, points: int) -> Vector2i:
	level = clamp_level(level)
	if level >= MAX_LEVEL:
		return Vector2i(MAX_LEVEL, 0)
	var total := progress + maxi(points, 0)
	level += total / PROGRESS_PER_LEVEL
	progress = total % PROGRESS_PER_LEVEL
	if level >= MAX_LEVEL:
		return Vector2i(MAX_LEVEL, 0)
	return Vector2i(level, progress)


## How many uses a rank needs per level at a given efficiency (for tooltips and balancing).
static func uses_per_level(rank: Rank, efficiency := 1.0) -> int:
	var g := proficiency_gain(rank, efficiency)
	return ceili(float(PROGRESS_PER_LEVEL) / g)


# ---------- stat modifiers ----------

## Applies modifiers for one stat: (base + flat sum) x (1 + percent sum / 100).
## Flat and percent values from every matching modifier add together before applying.
static func apply_modifiers(base: float, stat: StatModifier.Stat, mods: Array[StatModifier]) -> float:
	var flat := 0
	var pct := 0
	for m in mods:
		if m != null and m.stat == stat:
			flat += m.flat
			pct += m.percent
	return (base + flat) * maxf(0.0, 1.0 + pct / 100.0)


# ---------- chess vector geometry ----------

## The rays a geometry reaches along, each an ordered list of grid offsets from the unit (nearest first).
## Sliding pieces (Rook, Bishop, Queen) reach up to `reach` tiles per ray; Knight, King and Pawn take one
## step per ray. `facing` (an orthogonal unit vector) only matters for Pawn. Blocking and terrain are
## handled by GeometryResolver (scripts/board), which walks each ray and stops where needed.
static func geometry_rays(geometry: Geometry, reach: int, facing := Vector2i(0, 1)) -> Array[Array]:
	var dirs: Array[Vector2i] = []
	var steps := maxi(reach, 1)
	match geometry:
		Geometry.ROOK:
			dirs.assign(ORTHOGONAL)
		Geometry.BISHOP:
			dirs.assign(DIAGONAL)
		Geometry.QUEEN:
			dirs.assign(ORTHOGONAL + DIAGONAL)
		Geometry.KING:
			dirs.assign(ORTHOGONAL + DIAGONAL)
			steps = 1
		Geometry.KNIGHT:
			dirs.assign(KNIGHT_JUMPS)
			steps = 1
		Geometry.PAWN:
			var side := Vector2i(-facing.y, facing.x)
			dirs.assign([facing, facing + side, facing - side])
			steps = 1
	var rays: Array[Array] = []
	for d in dirs:
		var ray: Array[Vector2i] = []
		for i in range(1, steps + 1):
			ray.append(d * i)
		rays.append(ray)
	return rays


## Every offset a geometry can reach, ignoring blocking.
static func geometry_offsets(geometry: Geometry, reach: int, facing := Vector2i(0, 1)) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ray in geometry_rays(geometry, reach, facing):
		for o in ray:
			out.append(o)
	return out
