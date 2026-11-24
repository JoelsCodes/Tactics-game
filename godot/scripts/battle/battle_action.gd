class_name BattleAction
extends RefCounted
## One thing a unit can do with its action: a basic weapon attack (skill = null), a skill, or a consumable from the party's bag (item; ITEMS command).

var skill: SkillData  ## null = basic weapon attack (Physical, costs no SP)
var item: ConsumableItem  ## set for an item (skill is null then): BattleController's item path, no SP, never misses


static func attack() -> BattleAction:
	return BattleAction.new()


static func use(s: SkillData) -> BattleAction:
	var a := BattleAction.new()
	a.skill = s
	return a


static func use_item(it: ConsumableItem) -> BattleAction:
	var a := BattleAction.new()
	a.item = it
	return a


func is_attack() -> bool:
	return skill == null and item == null


func is_item() -> bool:
	return item != null


## SP the action costs. Fixed: stance and style never change it. Items cost none.
func sp_cost() -> int:
	return 0 if skill == null else skill.sp_cost


func category() -> Proficiency.Category:
	if item != null:
		return Proficiency.Category.ELEMENTAL if item.effect == ConsumableItem.Effect.DAMAGE else Proficiency.Category.HEALING
	return Proficiency.Category.PHYSICAL if skill == null else skill.category


func display_name() -> String:
	if item != null:
		return item.display_name
	return "Attack" if skill == null else skill.display_name
