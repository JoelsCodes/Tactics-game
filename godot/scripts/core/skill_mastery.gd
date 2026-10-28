class_name SkillMastery
extends Resource
## One skill in a human's tree and its level, 0-99.
##   Level 0: being studied (mentorship). Usable while it is the active study, but not kept yet.
##   Level 1: learned, permanently in the human's personal tree.
##   Every level, 0 -> 1 included, comes from use: each use fills a 100-point bar by the character's
##   rank gain in the skill's proficiency (S 20 ... C 10 ... F 4, times efficiency).
## The skill's power scales with its level (SkillData.power_at).

@export var skill: SkillData
@export var mentor_name := ""  ## the vessel it was studied from, for display
@export_range(0, 99) var level := 0
@export_range(0, 99) var progress := 0  ## points in the current bar


static func make(s: SkillData, mentor := "") -> SkillMastery:
	var m := SkillMastery.new()
	m.skill = s
	m.mentor_name = mentor
	return m


## Learned: level 1 or more.
func is_mastered() -> bool:
	return level >= 1


func is_maxed() -> bool:
	return level >= TacticalMath.MAX_LEVEL


func fill() -> float:
	return 1.0 if is_maxed() else float(progress) / TacticalMath.PROGRESS_PER_LEVEL


## Adds bar points; full bars become levels (up to 99). Returns the levels gained.
func add_progress(points: int) -> int:
	var before := level
	var r := TacticalMath.add_progress(level, progress, points)
	level = r.x
	progress = r.y
	return level - before


func power() -> int:
	return skill.power_at(level)
