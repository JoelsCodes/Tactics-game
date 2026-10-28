class_name SkillData
extends Resource
## An active skill as data: what it costs and how strong it is. How it targets and resolves belongs
## to the combat layer (not written yet). Power scales with the level of its proficiency category.
## SP cost is fixed: nothing (stance, level, equipment) changes it. Physical skills follow the unit's
## stance footprint and stance damage scaling; the other five categories ignore stance.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export_range(0, 30) var sp_cost := 3  ## SP pools are 15-30, so every cast matters
@export_range(0, 50) var base_power := 6
## The proficiency this skill belongs to, uses and trains.
@export var category: Proficiency.Category = Proficiency.Category.PHYSICAL


func is_physical() -> bool:
	return category == Proficiency.Category.PHYSICAL


## Track id of its proficiency, e.g. &"elemental".
func proficiency_id() -> StringName:
	return Proficiency.id(category)


## Power at a proficiency level: base power x (1 + 0.02 x level), rounded.
func power_at(proficiency_level: int) -> int:
	return TacticalMath.scale(base_power, proficiency_level)
