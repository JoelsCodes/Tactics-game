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


## Adds study points to the active study, then tries to complete it. Returns true if a skill was
## mastered by this call.
func add_study_progress(points: int, stats: CharacterStats) -> bool:
	var m := active_study()
	if m == null:
		return false
	m.add_progress(points)
	return try_complete(stats)


## Masters every fully studied skill whose proficiency threshold `stats` now meets (e.g. after a
## proficiency level-up). Returns true if any skill was mastered.
func try_complete(stats: CharacterStats) -> bool:
	var any := false
	for m in masteries:
		if m.is_mastered() or not m.is_studied():
			continue
		if threshold_met(m.skill, stats):
			m.level = 1
			if masteries.find(m) == active_index:
				active_index = -1
			any = true
			skill_mastered.emit(m.skill)
	if any:
		emit_changed()
	return any


static func threshold_met(skill: SkillData, stats: CharacterStats) -> bool:
	return stats != null and stats.proficiency_level(skill.proficiency_id()) >= skill.required_level
