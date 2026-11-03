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

## The weapon styles and stances this unit has found, as "GEOMETRY:STANCE" keys (PartyRoster.style_key): the swords it ended a turn on.
## The style it holds now always counts too. Only this unit can equip them (loadout menu).
@export var known_styles: Array[String] = []


## Every style key this unit has: the found ones, then the one it holds now. No duplicates.
func known_style_keys() -> Array[String]:
	var out: Array[String] = []
	out.append_array(known_styles)
	var s: WeaponStyle = loadout.weapon_style if loadout else null
	if s != null:
		var k := PartyRoster.style_key(s.geometry, s.stance)
		if not out.has(k):
			out.append(k)
	return out


func knows_style(geometry: TacticalMath.Geometry, stance: WeaponStyle.Stance) -> bool:
	return known_style_keys().has(PartyRoster.style_key(geometry, stance))


## Adds a found style and stance to this unit's collection (stored even when it holds it now, so it stays if it swaps it away).
## Returns true when it was new to the unit.
func learn_style(geometry: TacticalMath.Geometry, stance: WeaponStyle.Stance) -> bool:
	var key := PartyRoster.style_key(geometry, stance)
	var was_known := known_style_keys().has(key)
	if not known_styles.has(key):
		known_styles.append(key)
		emit_changed()
	return not was_known


## Level, XP and XP needed for the next level, read from `stats` (1, 0, 0 without stats).
var level: int:
	get:
		return stats.level if stats else 1
var exp: int:
	get:
		return stats.exp if stats else 0
var exp_to_next_level: int:
	get:
		return stats.exp_to_next_level if stats else 0
var total_exp: int:
	get:
		return stats.total_exp if stats else 0


## Gives the unit experience (see CharacterStats.add_exp). Returns the levels gained.
func add_exp(amount: int) -> Array[LevelUp]:
	return stats.add_exp(amount, loadout) if stats else ([] as Array[LevelUp])


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
