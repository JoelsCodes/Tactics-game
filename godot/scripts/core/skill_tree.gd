class_name SkillTree
extends Resource
## A human's personal skill tree: skills inherited from vessels through mentorship and their levels.
## Starting a study puts a skill at level 0 and makes it usable at once; using it fills its level bar.
## At level 1 it is learned and kept for good; more use levels it to 99. One skill is the active study
## at a time; switching keeps the progress of the others, but a paused study cannot be used.

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


## Level of a skill in this tree (0 if never studied).
func skill_level(skill: SkillData) -> int:
	var m := mastery_of(skill)
	return m.level if m != null else 0


## Whether the human can use `skill` right now: learned (level 1+) or the active study at level 0.
## A paused study cannot be used until it is the active study again.
func can_use(skill: SkillData) -> bool:
	var m := mastery_of(skill)
	return m != null and (m.is_mastered() or m == active_study())


## Every skill the human can use right now: the learned ones plus the active study.
func usable_skills() -> Array[SkillData]:
	var out := learned_skills()
	var a := active_study()
	if a != null:
		out.append(a.skill)
	return out


## Records `uses` uses of a usable skill: each adds the character's rank gain for the skill's
## proficiency to its level bar. Taking the active study from level 0 to 1 learns it for good and frees
## the study slot. Returns the levels gained (0 if the skill cannot be used now).
func use_skill(skill: SkillData, stats: CharacterStats, uses := 1, loadout: EquipmentLoadout = null) -> int:
	if not can_use(skill) or stats == null:
		return 0
	var m := mastery_of(skill)
	var was_learned := m.is_mastered()
	var gained := m.add_progress(stats.skill_gain(skill.category, loadout) * maxi(uses, 0))
	if not was_learned and m.is_mastered():
		active_index = -1
		skill_mastered.emit(skill)
	if gained > 0:
		emit_changed()
	return gained
