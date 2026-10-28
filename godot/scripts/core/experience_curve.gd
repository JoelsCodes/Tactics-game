class_name ExperienceCurve
extends RefCounted
## How much experience each character level takes. Low, readable numbers: 100 to leave level 1, then
## 10 more for every level after it.
##
##   level 1 -> 2: 100     level 10 -> 11: 190     level 50 -> 51: 590     level 98 -> 99: 1070
##
## Reaching level 99 from level 1 takes 57,330 XP in all. Level 99 is the cap: nothing more to earn.

const MIN_LEVEL := 1
const MAX_LEVEL := 99
const BASE := 100  ## XP to leave level 1
const PER_LEVEL := 10  ## extra XP for each level after 1


static func clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


## XP needed to go from `level` to the next level; 0 at the cap.
static func to_next(level: int) -> int:
	level = clamp_level(level)
	return 0 if level >= MAX_LEVEL else BASE + PER_LEVEL * (level - 1)


## Total XP from the start of level 1 to the start of `level`.
static func total_to_reach(level: int) -> int:
	var n := clamp_level(level) - 1
	return BASE * n + PER_LEVEL * n * (n - 1) / 2


## The level a lifetime XP total corresponds to, and the XP into it: Vector2i(level, exp).
static func at_total(total_exp: int) -> Vector2i:
	var level := MIN_LEVEL
	var left := maxi(total_exp, 0)
	while level < MAX_LEVEL and left >= to_next(level):
		left -= to_next(level)
		level += 1
	return Vector2i(level, 0 if level >= MAX_LEVEL else left)
