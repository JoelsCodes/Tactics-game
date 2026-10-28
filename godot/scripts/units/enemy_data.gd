class_name EnemyData
extends UnitData
## An opposing unit. Minimal for now (stats, loadout, the skills it can use); enemy design and AI come
## later.

## Skills it can use in battle, besides any on its loadout's relics.
@export var skills: Array[SkillData] = []
## XP it adds to the battle's pool when defeated (shared among the player's units at victory).
@export_range(0, 999) var exp_reward := 30


func role() -> Role:
	return Role.ENEMY
