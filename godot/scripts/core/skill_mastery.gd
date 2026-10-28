class_name SkillMastery
extends Resource
## One skill a human is studying or has mastered. Mastery has two levels:
##   0  unlearned / progressing: the study bar fills (0-100 points)
##   1  mastered: the skill is permanently in the human's personal tree
## A full bar becomes level 1 only once the human's proficiency in the skill's category reaches the
## skill's required_level (see SkillTree.try_complete).

const STUDY_POINTS := 100

@export var skill: SkillData
@export var mentor_name := ""  ## the vessel it was studied from, for display
@export_range(0, 100) var progress := 0
@export_range(0, 1) var level := 0


static func make(s: SkillData, mentor := "") -> SkillMastery:
	var m := SkillMastery.new()
	m.skill = s
	m.mentor_name = mentor
	return m


func is_mastered() -> bool:
	return level >= 1


## The study bar is full; mastery waits only on the proficiency threshold.
func is_studied() -> bool:
	return progress >= STUDY_POINTS


func fill() -> float:
	return 1.0 if is_mastered() else float(progress) / STUDY_POINTS


## Adds study points (capped at a full bar). Does nothing once mastered.
func add_progress(points: int) -> void:
	if not is_mastered():
		progress = mini(STUDY_POINTS, progress + maxi(points, 0))
