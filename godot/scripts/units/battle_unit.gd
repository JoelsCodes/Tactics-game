class_name BattleUnit
extends RefCounted
## A unit during one battle: its UnitData plus what changes in battle (HP, SP, cell, Fade Clock).
## This is what stands on the TacticalGrid (as the occupant). Unit nodes for drawing come later and
## will hold one of these.

var data: UnitData
## The stance, copied from the weapon style when the unit enters the battle. Styles and stances are set
## in the loadout menus before battle; nothing changes them during a battle.
var _stance: WeaponStyle.Stance = WeaponStyle.Stance.IMPACT
var team := 0
var hp := 0
var sp := 0
var cell := TacticalGrid.NO_CELL
var on_field := false
var fade_clock: FadeClock  ## vessels only: in-battle countdown, set when summoned
var anchor: BattleUnit  ## the King this vessel is bound to
var facing := Vector2i(0, 1)  ## board direction it faces (Pawn footprints, sprites)
var ct := 0  ## charge time for the turn order (TurnManager)
var guarding := false  ## chose Defend: takes half damage until its next turn starts


func _init(unit: UnitData, unit_team := 0) -> void:
	data = unit
	team = unit_team
	hp = max_hp()
	sp = max_sp()
	if unit.loadout and unit.loadout.weapon_style:
		_stance = unit.loadout.weapon_style.stance


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


## A final stat with equipment (see CharacterStats.final_stat).
func stat(s: StatModifier.Stat) -> int:
	return data.stats.final_stat(s, data.loadout) if data.stats else 0


## The unit's stance for this battle (fixed; see _stance).
func stance() -> WeaponStyle.Stance:
	return _stance


func style() -> WeaponStyle:
	return data.loadout.weapon_style if data.loadout else null


## The field relic this vessel is tethered to (its Temp-Relic), or null.
func temp_relic() -> RelicItem:
	return data.loadout.temp_relic if data.loadout else null
