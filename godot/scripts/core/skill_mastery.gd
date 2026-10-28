class_name SkillMastery
extends Resource
## One skill a human is studying or has mastered. Mastery has two levels:
##   0  unlearned / progressing: set when the human starts studying it; the study bar fills (0-100)
##   1  mastered: the bar is full; the skill is learned, permanently in the human's personal tree
## Learning a skill means taking it from level 0 to level 1. Nothing else is required.

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


func fill() -> float:
	return 1.0 if is_mastered() else float(progress) / STUDY_POINTS


## Adds study points; a full bar raises the skill to level 1 (learned). Returns true if this call
## completed it. Does nothing once mastered.
func add_progress(points: int) -> bool:
	if is_mastered():
		return false
	progress = mini(STUDY_POINTS, progress + maxi(points, 0))
	if progress >= STUDY_POINTS:
		level = 1
		return true
	return false
