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


static var _physical: Array[SkillData] = []  ## loaded once: the same objects every time (units compare them)
static var _healing: Array[SkillData] = []
static var _elemental: Array[SkillData] = []
static var _tactical: Array[SkillData] = []
static var _status: Array[SkillData] = []
static var _void: Array[SkillData] = []


static func physical() -> Array[SkillData]:
	if _physical.is_empty():
		_physical = _load("physical.json", Proficiency.Category.PHYSICAL)
	return _physical


## The healing proficiency's skills (data/skills/healing.json).
static func healing() -> Array[SkillData]:
	if _healing.is_empty():
		_healing = _load("healing.json", Proficiency.Category.HEALING)
	return _healing


static func elemental() -> Array[SkillData]:
	if _elemental.is_empty():
		_elemental = _load("elemental.json", Proficiency.Category.ELEMENTAL)
	return _elemental


static func tactical() -> Array[SkillData]:
	if _tactical.is_empty():
		_tactical = _load("tactical.json", Proficiency.Category.TACTICAL)
	return _tactical


static func status() -> Array[SkillData]:
	if _status.is_empty():
		_status = _load("status.json", Proficiency.Category.STATUS)
	return _status


static func void_skills() -> Array[SkillData]:
	if _void.is_empty():
		_void = _load("void.json", Proficiency.Category.VOID)
	return _void


## What an enemy without a list of its own may use: the owner's rank E physical skills.
static func enemy_pool() -> Array[SkillData]:
	return physical().filter(func(s): return s.rank == SkillData.Rank.E and not s.generated)


## The skills of one proficiency.
static func of(cat: Proficiency.Category) -> Array[SkillData]:
	match cat:
		Proficiency.Category.PHYSICAL:
			return physical()
		Proficiency.Category.ELEMENTAL:
			return elemental()
		Proficiency.Category.HEALING:
			return healing()
		Proficiency.Category.TACTICAL:
			return tactical()
		Proficiency.Category.STATUS:
			return status()
	return void_skills()


## Every skill in the game, proficiency by proficiency.
static func all() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for c in Proficiency.all():
		out.append_array(of(c))
	return out


## Every skill of a rank (all six proficiencies).
static func of_rank(rank: SkillData.Rank) -> Array[SkillData]:
	return all().filter(func(s): return s.rank == rank)


## The skill with this display name, or null.
static func find(skill_name: String) -> SkillData:
	for s in all():
		if s.display_name == skill_name:
			return s
	return null


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
		s.base_power = int(row.get("power", 0))  # physical skills use the rank band, not base power
		s.animation = String(row.get("animation", ""))
		s.effect = String(row.get("effect", ""))
		s.allows_move_after = bool(row.get("allows_move_after", false))
		s.push = int(row.get("push", 0))
		s.fixed_multiplier = float(row.get("fixed_multiplier", 0.0))
		s.slow = int(row.get("slow", 0))
		s.retreat = bool(row.get("retreat", false))
		s.spare = bool(row.get("spare", false))
		s.hop = bool(row.get("hop", false))
		s.support = String(row.get("support", ""))
		s.allies_only = bool(row.get("allies_only", false))
		s.enemies_only = bool(row.get("enemies_only", false))
		s.status = String(row.get("status", ""))
		s.status_turns = int(row.get("status_turns", 0))
		s.fx = row.get("fx", {})
		s.generated = bool(row.get("gen", false))
		out.append(s)
	return out
