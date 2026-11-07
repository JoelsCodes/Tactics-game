class_name LevelUp
extends RefCounted
## One level gained (CharacterStats.add_exp returns one per level), with how the pools changed.
## The pools are what the unit has with its equipment at the time, capped like everywhere else.

var from_level := 0
var to_level := 0
var hp_before := 0
var hp_after := 0
var sp_before := 0
var sp_after := 0
var gains := {}  ## StatModifier.Stat -> points gained this level (only the stats that rose)


func describe() -> String:
	var parts: Array[String] = []
	for st in gains:
		if st != StatModifier.Stat.MAX_HP:
			parts.append("%s +%d" % [StatModifier.stat_name(st), gains[st]])
	return "Lv %d → %d  (HP %d → %d, SP %d → %d)%s" % [from_level, to_level, hp_before, hp_after, sp_before, sp_after, ("  " + ", ".join(parts)) if not parts.is_empty() else ""]
