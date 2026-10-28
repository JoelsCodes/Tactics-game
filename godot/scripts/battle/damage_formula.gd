class_name DamageFormula
extends RefCounted
## The numbers an action deals, kept small (HP pools are 50-300). One place to tune.
##
##   Physical (attacks and Physical skills): weapon power + skill power + Attack - target Defense,
##             then the stance percent for that tile (aimed tile / other hit tiles)
##   Elemental: skill power + Magic - target Resistance
##   Void:      skill power + Magic (ignores Resistance)
##   Healing:   restores skill power + Magic / 2
##   Tactical, Status: no HP change yet (their effects come with the status system)
## Damage is at least 1. Skill power = base power x (1 + 0.02 x skill level).

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


## Final amount on one tile of the area: Physical gets the stance percent (aimed tile / spread).
static func amount(user: BattleUnit, target: BattleUnit, action: BattleAction, skill_level: int, area: TargetArea, tile: Vector2i) -> int:
	var a := base_amount(user, target, action, skill_level)
	if a > 0 and action.category() == Proficiency.Category.PHYSICAL:
		a = StanceRules.scale_damage(a, StanceRules.damage_percent(user.stance, area, tile))
	return a
