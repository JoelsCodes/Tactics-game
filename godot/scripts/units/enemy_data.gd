class_name EnemyData
extends UnitData
## An opposing unit. Minimal for now (stats, loadout, the skills it can use); enemy design and AI come
## later.

## Skills it can use in battle, besides any on its loadout's relics.
@export var skills: Array[SkillData] = []
## True: it only moves and uses the basic attack (no skills at all), like the first battle's squire.
@export var basic_attack_only := false
## True: its skills are exactly the ones in `skills` (not every skill in the database, as an enemy otherwise has).
@export var skills_only := false
## XP it adds to the battle's pool when defeated (shared among the player's units at victory).
@export_range(0, 999) var exp_reward := 30


func role() -> Role:
	return Role.ENEMY
