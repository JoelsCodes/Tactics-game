class_name StatModifier
extends Resource
## One change to one stat: a flat amount and/or a percent. Used by accessories, relic passives,
## relic drawbacks and weapon styles. Negative values are penalties (e.g. Move -1, Max SP -20%).

enum Stat { MAX_HP, MAX_SP, ATTACK, DEFENSE, MAGIC, RESISTANCE, SPEED, WILL, MOVE, JUMP, PROF_EFFICIENCY }

## Hard limits on final stat values, after every modifier. Keeps the numbers small and readable.
## PROF_EFFICIENCY is a multiplier (1.0 = normal), the rest are whole numbers.
const LIMITS := {
	Stat.MAX_HP: Vector2(1, 300),
	Stat.MAX_SP: Vector2(0, 30),
	Stat.ATTACK: Vector2(0, 99),
	Stat.DEFENSE: Vector2(0, 99),
	Stat.MAGIC: Vector2(0, 99),
	Stat.RESISTANCE: Vector2(0, 99),
	Stat.SPEED: Vector2(1, 99),
	Stat.WILL: Vector2(0, 99),
	Stat.MOVE: Vector2(1, 10),
	Stat.JUMP: Vector2(0, 8),
	Stat.PROF_EFFICIENCY: Vector2(.25, 2.0),
}

@export var stat: Stat = Stat.ATTACK
@export_range(-99, 99) var flat := 0  ## added before percent
@export_range(-90, 200) var percent := 0  ## e.g. -20 = 20% less


static func make(s: Stat, flat_amount := 0, percent_amount := 0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = s
	m.flat = flat_amount
	m.percent = percent_amount
	return m


static func stat_name(s: Stat) -> String:
	return Stat.keys()[s].capitalize()


static func clamp_stat(s: Stat, value: float) -> float:
	var lim: Vector2 = LIMITS[s]
	return clampf(value, lim.x, lim.y)


func is_penalty() -> bool:
	return flat < 0 or percent < 0


## Short label for tooltips, e.g. "Move -1", "Max SP -20%", "Attack +2 +10%".
func describe() -> String:
	var parts: Array[String] = [stat_name(stat)]
	if flat != 0:
		parts.append("%+d" % flat)
	if percent != 0:
		parts.append("%+d%%" % percent)
	return " ".join(parts)
