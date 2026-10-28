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
var fade_clock: FadeClock  ## vessels only: in-battle countdown, set when summoned
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


## The field relic this vessel is tethered to (its Temp-Relic), or null.
func temp_relic() -> RelicItem:
	return data.loadout.temp_relic if data.loadout else null
