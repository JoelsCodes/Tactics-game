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
			return maxi(1, weapon + power + user.stat(StatModifier.Stat.ATTACK) - target.stat(StatModifier.Stat.DEFENSE))
		Proficiency.Category.ELEMENTAL:
			return maxi(1, power + user.stat(StatModifier.Stat.MAGIC) - target.stat(StatModifier.Stat.RESISTANCE))
		Proficiency.Category.VOID:
			return maxi(1, power + user.stat(StatModifier.Stat.MAGIC))
		Proficiency.Category.HEALING:
			return power + user.stat(StatModifier.Stat.MAGIC) / 2
	return 0


## A physical skill: the weapon's power is added as it is; the rank multiplier x Attack x skill level term
## x stance percent is the skill's own part. At least 1.
static func skill_physical(user: BattleUnit, target: BattleUnit, skill: SkillData, skill_level: int, mult: float, percent: int) -> int:
	var weapon := user.data.loadout.weapon_power() if user.data.loadout else 0
	var attack_part := roundi(mult * user.stat(StatModifier.Stat.ATTACK) * TacticalMath.multiplier(skill_level) * percent / 100.0)
	return maxi(1, weapon + attack_part - target.stat(StatModifier.Stat.DEFENSE))


## Percent of damage a guarding unit (Defend) still takes.
const GUARD_PERCENT := 50


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
	if a > 0 and target.guarding and effect_of(action.category()) == Effect.DAMAGE:
		a = maxi(1, a * GUARD_PERCENT / 100)
	return a
