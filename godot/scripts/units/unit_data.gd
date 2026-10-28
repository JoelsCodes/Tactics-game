class_name UnitData
extends Resource
## A unit's lasting definition: who it is, its stats and its loadout. Saved between battles.
## Subclasses set the role: KingData (the Commander), CoCaptainData (permanent human officers) and
## VesselData (summoned entities anchored to the King) and EnemyData (opposing units). In battle a
## unit is wrapped in a BattleUnit.

enum Role { KING, CO_CAPTAIN, VESSEL, ENEMY }

@export var id: StringName
@export var display_name := ""
@export var stats: CharacterStats
@export var loadout: EquipmentLoadout
## Humans only: skills inherited from vessels through mentorship (see Mentorship).
@export var skill_tree: SkillTree


func role() -> Role:
	push_error("UnitData.role() must be overridden")
	return Role.VESSEL


## The King and Co-Captains.
func is_human() -> bool:
	return role() == Role.KING or role() == Role.CO_CAPTAIN


## Whether the unit runs a Fade Clock in battle. Only vessels decay.
func decays() -> bool:
	return false


func role_name() -> String:
	return Role.keys()[role()].capitalize()
