class_name SkillData
extends Resource
## An active skill as data: what it costs and how strong it is. How it targets and resolves belongs
## to the combat layer (not written yet). Power scales with the skill's level (0-99, kept per
## character in SkillMastery).
## SP cost is fixed: nothing (stance, level, equipment) changes it. Physical skills follow the unit's
## stance footprint and stance damage scaling; the other five categories ignore stance.
##
## Physical skills have a rank. Each use rolls a multiplier inside the rank's band (see BANDS) and that
## multiplier scales the user's Attack (DamageFormula): weapon power + (multiplier x Attack) x skill level
## term x stance percent - Defense. The rank is specified in the skill. S is exactly 3.0.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export_range(0, 30) var sp_cost := 3  ## SP pools are 15-30, so every cast matters
@export_range(0, 50) var base_power := 6
## The proficiency this skill belongs to, uses and trains.
@export var category: Proficiency.Category = Proficiency.Category.PHYSICAL
## Physical skills: the rank whose multiplier band the damage roll is taken from.
enum Rank { E, D, C, B, A, S }
@export var rank: Rank = Rank.D

## Multiplier band per rank: each use rolls a value between the two numbers.
const BANDS := {
	Rank.E: [1.00, 1.20],
	Rank.D: [1.25, 1.50],
	Rank.C: [1.55, 1.85],
	Rank.B: [1.90, 2.25],
	Rank.A: [2.30, 2.80],
	Rank.S: [3.00, 3.00],
}


func is_physical() -> bool:
	return category == Proficiency.Category.PHYSICAL


## Track id of its proficiency, e.g. &"elemental".
func proficiency_id() -> StringName:
	return Proficiency.id(category)


## Power at a skill level: base power x (1 + 0.02 x level), rounded. (Non-physical skills; physical skills
## use the rank band instead.)
func power_at(skill_level: int) -> int:
	return TacticalMath.scale(base_power, skill_level)


## The rank's multiplier band, [low, high].
func band() -> Array:
	return BANDS[rank]


## The middle of the band: what a preview shows.
func band_mid() -> float:
	return (float(BANDS[rank][0]) + float(BANDS[rank][1])) / 2.0


## One use's multiplier: a random value inside the band (rng for repeatable results).
func roll(rng: RandomNumberGenerator = null) -> float:
	var lo: float = BANDS[rank][0]
	var hi: float = BANDS[rank][1]
	return rng.randf_range(lo, hi) if rng else randf_range(lo, hi)
