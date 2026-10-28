class_name BattleAction
extends RefCounted
## One thing a unit can do with its action: a basic weapon attack (skill = null) or a skill.

var skill: SkillData  ## null = basic weapon attack (Physical, costs no SP)


static func attack() -> BattleAction:
	return BattleAction.new()


static func use(s: SkillData) -> BattleAction:
	var a := BattleAction.new()
	a.skill = s
	return a


func is_attack() -> bool:
	return skill == null


## SP the action costs. Fixed: stance and style never change it.
func sp_cost() -> int:
	return 0 if skill == null else skill.sp_cost


func category() -> Proficiency.Category:
	return Proficiency.Category.PHYSICAL if skill == null else skill.category


func display_name() -> String:
	return "Attack" if skill == null else skill.display_name
