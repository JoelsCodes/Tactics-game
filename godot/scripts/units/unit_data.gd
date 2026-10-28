class_name UnitData
extends Resource
## A unit's lasting definition: who it is, its stats and its loadout. Saved between battles.
## Subclasses set the role: KingData (the Commander), CoCaptainData (permanent human officers) and
## VesselData (summoned entities anchored to the King). In battle a unit is wrapped in a BattleUnit.

enum Role { KING, CO_CAPTAIN, VESSEL }

@export var id: StringName
@export var display_name := ""
@export var stats: CharacterStats
@export var loadout: EquipmentLoadout
## How many times this unit has been severed from the field (vessel fades, untethers, falls, or the
## King's fall cutting it loose). On the King it counts every sever among the vessels he leads.
@export var sever_count := 0


func role() -> Role:
	push_error("UnitData.role() must be overridden")
	return Role.VESSEL


func is_human() -> bool:
	return role() != Role.VESSEL


## Whether the unit runs a Fade Clock in battle. Only vessels decay.
func decays() -> bool:
	return false


func role_name() -> String:
	return Role.keys()[role()].capitalize()
