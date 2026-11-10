class_name DamageFormula
extends RefCounted
## The numbers an action deals, kept small (HP pools are 50-300). One place to tune.
##
##   Basic attack (physical): weapon power + Attack - target Defense, then the stance percent for that tile
##             (aimed tile / other hit tiles)
##   Physical skill: weapon power + (rank multiplier x Attack) x (1 + 0.02 x skill level) x stance percent
##             - target Defense. The rank multiplier is rolled in its band on every use (SkillData.roll).
##   Elemental: skill power + Magic - target Resistance
##   Void:      skill power + Magic (ignores Resistance)
##   Healing:   restores skill power + Magic / 2
##   Tactical, Status: no HP change yet (their effects come with the status system)
## Damage is at least 1. Non-physical skill power = base power x (1 + 0.02 x skill level).

## The Final Fantasy Tactics pace (owner, Nov 2026: "skills and attack should do enough damage that you have to think about your next move; health low enough
## that you cannot just keep getting hit"). Two numbers, both here:
##   DEFENSE_K     Defense and Resistance no longer subtract a flat number (which let a small hit vanish and a big stat make a unit untouchable): they take
##                 off a share, offense x 100 / (100 + DEFENSE_K x defense). Defense 5 takes off 17%, 15 takes off 38%, 30 takes off 55%.
##   DAMAGE_SCALE  every point of HP damage and healing is multiplied by this at the end (percent), after the stance percent and the guard, so a
##                 unit goes down in about three to five good blows and a skill or a critical shortens that. HP itself is CharacterStats.HP_SCALE.
## Both are measured by tests/tension_check (blows to down Alaric / an enemy, every story map) and tools/balance. Fixed-number HP effects (poison, burn,
## regen, the ritual drain) are not scaled.
static var DEFENSE_K := 4.0
static var DAMAGE_SCALE := 220
## An enemy's blows grow with its level on top of its own stats (the party's HP grows 5% a level, the chapters' enemy attack does not keep up): x1 up to level
## RAMP_FROM, then up to x(1 + RAMP_MAX) at level RAMP_TO. Only for units on the enemy's team (not allies, not a confused or berserk party unit).
static var RAMP_FROM := 8
static var RAMP_TO := 60
static var RAMP_MAX := 0.9


static func ramp(user: BattleUnit) -> float:
	if user == null or user.team == 0 or user.data == null or user.data.stats == null:
		return 1.0
	return 1.0 + RAMP_MAX * clampf(float(user.data.stats.level - RAMP_FROM) / float(RAMP_TO - RAMP_FROM), 0.0, 1.0)


static var flat_defense := false  ## the old rule (defense subtracts a flat number); only the checks that read exact old numbers turn it on (`legacy_numbers`)


## The numbers before the FFT-pace tuning (flat defense, no damage scale, HP x0.5, no enemy HP curve), for the checks that were written against exact figures.
## Real play and the tension and balance harnesses use the tuned ones.
static func legacy_numbers(on := true) -> void:
	flat_defense = on
	DAMAGE_SCALE = 100 if on else 220
	CharacterStats.HP_SCALE = 0.5 if on else 0.45
	CharacterStats.enemy_curve_on = not on


## Offense after the target's defense: a share comes off, never below 1.
static func mitigate(offense: int, defense: int) -> int:
	if offense <= 0:
		return 0
	if flat_defense:
		return maxi(1, offense - defense)
	return maxi(1, roundi(float(offense) * 100.0 / (100.0 + DEFENSE_K * maxi(defense, 0))))


enum Effect { DAMAGE, HEAL, NONE }


static func effect_of(category: Proficiency.Category) -> Effect:
	match category:
		Proficiency.Category.PHYSICAL, Proficiency.Category.ELEMENTAL, Proficiency.Category.VOID:
			return Effect.DAMAGE
		Proficiency.Category.HEALING:
			return Effect.HEAL
	return Effect.NONE


## HP change before the stance percent: positive damage or healing amount.
static func base_amount(user: BattleUnit, target: BattleUnit, action: BattleAction, skill_level: int) -> int:
	var power := action.skill.power_at(skill_level) if action.skill else 0
	match action.category():
		Proficiency.Category.PHYSICAL:
			var weapon := user.data.loadout.weapon_power() if user.data.loadout else 0
			return mitigate(weapon + power + user.stat(StatModifier.Stat.ATTACK), target.stat(StatModifier.Stat.DEFENSE))
		Proficiency.Category.ELEMENTAL:
			return mitigate(power + user.stat(StatModifier.Stat.MAGIC), target.stat(StatModifier.Stat.RESISTANCE))
		Proficiency.Category.VOID:
			return maxi(1, power + user.stat(StatModifier.Stat.MAGIC))
		Proficiency.Category.HEALING:
			return power + user.stat(StatModifier.Stat.MAGIC) / 2
	return 0


## A physical skill: the weapon's power is added as it is; the rank multiplier x Attack x skill level term
## x stance percent is the skill's own part. At least 1.
static func skill_physical(user: BattleUnit, target: BattleUnit, skill: SkillData, skill_level: int, mult: float, percent: int) -> int:
	var weapon := user.data.loadout.weapon_power() if user.data.loadout else 0
	var attack_part := roundi(mult * user.stat(StatModifier.Stat.ATTACK) * TacticalMath.multiplier(skill_level))
	return StanceRules.scale_damage(mitigate(weapon + attack_part, target.stat(StatModifier.Stat.DEFENSE)), percent)


## Percent of damage a guarding unit (Defend) still takes.
const GUARD_PERCENT := 50


## Physical damage left by a unit with atk_down (Grip Loosen: 15% less).
const ATK_DOWN_PERCENT := 85


## The healing proficiency's SP Finisher (SupportRules): a physical-style hit with `percent` of Attack (the SP-scaled multiplier),
## then the target's guard and the user's Atk Down apply. At least 1.
static func skill_finisher(user: BattleUnit, target: BattleUnit, skill: SkillData, skill_level: int, percent: int, stance_percent: int) -> int:
	var a := skill_physical(user, target, skill, skill_level, percent / 100.0, stance_percent)
	if user.has_status(BattleUnit.ATK_DOWN):
		a = maxi(1, a * ATK_DOWN_PERCENT / 100)
	if target.guarding:
		a = maxi(1, a * GUARD_PERCENT / 100)
	return scaled(a)


## Final amount on one tile of the area: Physical gets the stance percent (aimed tile / spread); a
## guarding target takes GUARD_PERCENT of any damage (never of healing), at least 1.
## `mult` is the rank multiplier of a physical skill for this use (<= 0: the band's middle, for previews).
static func amount(user: BattleUnit, target: BattleUnit, action: BattleAction, skill_level: int, area: TargetArea, tile: Vector2i, mult := -1.0) -> int:
	var a := 0
	if action.skill != null and action.category() == Proficiency.Category.PHYSICAL:
		a = skill_physical(user, target, action.skill, skill_level, mult if mult > 0.0 else action.skill.band_mid(), StanceRules.damage_percent(user.stance(), area, tile))
	else:
		a = base_amount(user, target, action, skill_level)
		if a > 0 and action.category() == Proficiency.Category.PHYSICAL:
			a = StanceRules.scale_damage(a, StanceRules.damage_percent(user.stance(), area, tile))
	if a > 0 and user.has_status(BattleUnit.ATK_DOWN) and action.category() == Proficiency.Category.PHYSICAL:
		a = maxi(1, a * ATK_DOWN_PERCENT / 100)
	if a > 0 and target.guarding and effect_of(action.category()) == Effect.DAMAGE:
		a = maxi(1, a * GUARD_PERCENT / 100)
	if a > 0 and effect_of(action.category()) == Effect.DAMAGE:
		if target.has_status(BattleUnit.WARD):
			a = maxi(1, a * 75 / 100)
		if target.has_status(BattleUnit.EXPOSED):
			a = a * 125 / 100
	if a > 0 and effect_of(action.category()) != Effect.NONE:
		a = scaled(a)
		if not flat_defense and effect_of(action.category()) == Effect.DAMAGE:
			a = maxi(1, roundi(a * ramp(user)))
	return a


## The final scale on HP damage and healing (DAMAGE_SCALE percent), at least 1.
static func scaled(a: int) -> int:
	return maxi(1, roundi(a * DAMAGE_SCALE / 100.0)) if a > 0 else a
