class_name BattleUnit
extends RefCounted
## A unit during one battle: its UnitData plus what changes in battle (HP, SP, cell, Fade Clock).
## This is what stands on the TacticalGrid (as the occupant). Unit nodes for drawing come later and
## will hold one of these.

var data: UnitData
var team := 0
var hp := 0
var sp := 0
var cell := TacticalGrid.NO_CELL
var on_field := false
var fade_clock: FadeClock  ## vessels only, set when summoned
## Turns this vessel has left: -1 at the end of each of its turns, severed at 0. 0 for humans.
var sever_count: int:
	get:
		return fade_clock.turns_left if fade_clock else 0
var anchor: BattleUnit  ## the King this vessel is bound to


func _init(unit: UnitData, unit_team := 0) -> void:
	data = unit
	team = unit_team
	hp = max_hp()
	sp = max_sp()


func role() -> UnitData.Role:
	return data.role()


func is_king() -> bool:
	return role() == UnitData.Role.KING


func is_vessel() -> bool:
	return role() == UnitData.Role.VESSEL


func max_hp() -> int:
	return data.stats.max_hp(data.loadout) if data.stats else 1


func max_sp() -> int:
	return data.stats.max_sp(data.loadout) if data.stats else 0


func is_down() -> bool:
	return hp <= 0


## Relics this unit holds.
func held_relics() -> Array[RelicItem]:
	if data.loadout == null:
		return [] as Array[RelicItem]
	return data.loadout.relics()
