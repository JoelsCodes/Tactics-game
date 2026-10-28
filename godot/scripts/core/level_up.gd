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


func describe() -> String:
	return "Lv %d → %d  (HP %d → %d, SP %d → %d)" % [from_level, to_level, hp_before, hp_after, sp_before, sp_after]
