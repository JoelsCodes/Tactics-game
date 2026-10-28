class_name EnemyData
extends UnitData
## An opposing unit. Minimal for now (stats, loadout, the skills it can use); enemy design and AI come
## later.

## Skills it can use in battle, besides any on its loadout's relics.
@export var skills: Array[SkillData] = []


func role() -> Role:
	return Role.ENEMY
