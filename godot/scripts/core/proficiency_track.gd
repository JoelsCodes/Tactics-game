class_name ProficiencyTrack
extends Resource
## One proficiency a character is building: an aptitude rank (S-F), a level 0-99 and a 100-point bar.
## Each use adds rank gain x efficiency to the bar (TacticalMath.proficiency_gain); a full bar is a level.

signal leveled_up(new_level: int)

@export var id: StringName  ## e.g. &"pierce", &"impact", &"axe"
@export var rank: TacticalMath.Rank = TacticalMath.Rank.C
@export_range(0, 99) var level := 0
@export_range(0, 99) var progress := 0  ## points in the current bar (0..99)


static func make(track_id: StringName, track_rank := TacticalMath.Rank.C, start_level := 0) -> ProficiencyTrack:
	var t := ProficiencyTrack.new()
	t.id = track_id
	t.rank = track_rank
	t.level = TacticalMath.clamp_level(start_level)
	return t


func is_maxed() -> bool:
	return level >= TacticalMath.MAX_LEVEL


func multiplier() -> float:
	return TacticalMath.multiplier(level)


## Records `uses` uses at the given efficiency. Returns how many levels were gained.
func gain(efficiency := 1.0, uses := 1) -> int:
	var before := level
	var r := TacticalMath.add_progress(level, progress, TacticalMath.proficiency_gain(rank, efficiency) * maxi(uses, 0))
	level = r.x
	progress = r.y
	if level > before:
		leveled_up.emit(level)
		emit_changed()
	return level - before


## Bar fill 0..1, for a progress bar.
func fill() -> float:
	return 0.0 if is_maxed() else float(progress) / TacticalMath.PROGRESS_PER_LEVEL
