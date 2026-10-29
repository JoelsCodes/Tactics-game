class_name SkillLibrary
extends RefCounted
## The skill database as data: data/skills/<proficiency>.json, one entry per skill:
##   name, rank (E, D, C, B, A, S), sp (SP cost; default 3 for E ranks as the owner set),
##   description, shape ("stance": the footprint comes only from the weapon stance), effect_implemented,
##   animation ("attack", "heavy" or "cast"), effect (an effect on the user's sheet: slash, streak, circle,
##   burst, eruption, smoke, rend, swirl, shard), allows_move_after (true: the unit may walk again after the
##   skill, e.g. Quick Jab).
## Physical skills take their damage from the rank band (see SkillData, DamageFormula); a skill's
## effect text that is not implemented yet is kept in the data with effect_implemented = false.

const DIR := "res://data/skills/"


static func physical() -> Array[SkillData]:
	return _load("physical.json", Proficiency.Category.PHYSICAL)


static func _load(file: String, cat: Proficiency.Category) -> Array[SkillData]:
	var out: Array[SkillData] = []
	var rows = JSON.parse_string(FileAccess.get_file_as_string(DIR + file))
	for row in rows:
		var s := SkillData.new()
		s.display_name = row.name
		s.id = StringName(String(row.name).to_lower().replace(" ", "_").replace("'", ""))
		s.description = row.description
		s.category = cat
		s.sp_cost = int(row.sp)
		s.rank = SkillData.Rank.keys().find(row.rank) as SkillData.Rank
		s.base_power = 0  # physical skills use the rank band, not base power
		s.animation = String(row.get("animation", ""))
		s.effect = String(row.get("effect", ""))
		s.allows_move_after = bool(row.get("allows_move_after", false))
		out.append(s)
	return out
