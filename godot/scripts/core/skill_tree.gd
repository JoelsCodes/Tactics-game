class_name SkillTree
extends Resource
## A human's personal skill tree: skills inherited from vessels through mentorship and their levels.
## Studying takes a skill from level 0 to 1 (learned); using it levels it up to 99. One skill is the
## active study at a time; switching keeps the progress of the others.

signal skill_mastered(skill: SkillData)

@export var masteries: Array[SkillMastery] = []
@export var active_index := -1  ## index into masteries of the active study, -1 = none


func mastery_of(skill: SkillData) -> SkillMastery:
	for m in masteries:
		if m.skill == skill:
			return m
	return null


func is_learned(skill: SkillData) -> bool:
	var m := mastery_of(skill)
	return m != null and m.is_mastered()


## Every skill permanently inherited (mastery level 1).
func learned_skills() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for m in masteries:
		if m.is_mastered():
			out.append(m.skill)
	return out


func active_study() -> SkillMastery:
	return masteries[active_index] if active_index >= 0 and active_index < masteries.size() else null


## Makes `skill` the active study (resuming earlier progress if it was studied before).
## Returns its mastery, or null if it is already learned.
func start_study(skill: SkillData, mentor := "") -> SkillMastery:
	var m := mastery_of(skill)
	if m != null and m.is_mastered():
		return null
	if m == null:
		m = SkillMastery.make(skill, mentor)
		masteries.append(m)
	elif mentor != "":
		m.mentor_name = mentor
	active_index = masteries.find(m)
	emit_changed()
	return m


func stop_study() -> void:
	active_index = -1
	emit_changed()


## Adds study points to the active study. When its bar fills it goes from level 0 to level 1: the
## skill is learned and the study slot is freed. Returns true if a skill was learned by this call.
func add_study_progress(points: int) -> bool:
	var m := active_study()
	if m == null:
		return false
	m.add_progress(mini(points, TacticalMath.PROGRESS_PER_LEVEL - m.progress))  # study stops at level 1
	if not m.is_mastered():
		return false
	active_index = -1
	skill_mastered.emit(m.skill)
	emit_changed()
	return true


## Level of a skill in this tree (0 if never studied).
func skill_level(skill: SkillData) -> int:
	var m := mastery_of(skill)
	return m.level if m != null else 0


## Records `uses` uses of a learned skill: each adds the character's rank gain for the skill's
## proficiency. Returns the levels gained (0 if the skill is not learned).
func use_skill(skill: SkillData, stats: CharacterStats, uses := 1, loadout: EquipmentLoadout = null) -> int:
	var m := mastery_of(skill)
	if m == null or not m.is_mastered() or stats == null:
		return 0
	var gained := m.add_progress(stats.skill_gain(skill.category, loadout) * maxi(uses, 0))
	if gained > 0:
		emit_changed()
	return gained
