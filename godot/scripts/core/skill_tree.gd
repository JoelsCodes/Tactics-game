class_name SkillTree
extends Resource
## A human's personal skill tree: skills inherited from vessels through mentorship (mastered), and the
## ones still being studied. One skill is the active study at a time; switching keeps the progress of
## the others.

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
	if m == null or not m.add_progress(points):
		return false
	active_index = -1
	skill_mastered.emit(m.skill)
	emit_changed()
	return true
