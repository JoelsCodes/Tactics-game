class_name Proficiency
extends RefCounted
## The six proficiencies every skill belongs to. A character's level in each (ProficiencyTrack, 0-99)
## scales the power of its skills and gates inheriting new skills through mentorship.
##
## Only Physical skills (and basic weapon attacks) follow the weapon stance's footprint and damage.

enum Category { PHYSICAL, ELEMENTAL, HEALING, TACTICAL, STATUS, VOID }


## Track id used in CharacterStats.proficiencies: &"physical", &"elemental", ...
static func id(category: Category) -> StringName:
	return StringName(Category.keys()[category].to_lower())


static func display_name(category: Category) -> String:
	return Category.keys()[category].capitalize()


## Three-letter label for tight UI, e.g. "PHY", "ELE".
static func short_name(category: Category) -> String:
	return Category.keys()[category].substr(0, 3)


static func all() -> Array[Category]:
	var out: Array[Category] = []
	for c in Category.values():
		out.append(c)
	return out
