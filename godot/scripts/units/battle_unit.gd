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
var slow := 0  ## movement points lost on its next turn (Hamstring Cut); cleared when that turn ends
const MARKED := "marked"  ## physical hits on it land more often (5% miss instead of 25%)
const MILD_BLIND := "mild_blind"  ## its own attacks miss more often (35% instead of 25%)
const ATK_DOWN := "atk_down"  ## its physical damage is cut (DamageFormula.ATK_DOWN_PERCENT; Grip Loosen)
const POISON := "poison"  ## loses 5% of its max HP at the end of each of its turns (SupportRules; Poison Spit)
const BURN := "burn"  ## loses 6% of its max HP at the end of each of its turns (SkillFx; never the last point)
const REGEN := "regen"  ## regains 8% of its max HP at the end of each of its turns
const WARD := "ward"  ## takes 25% less damage
const EXPOSED := "exposed"  ## takes 25% more damage
const SILENCE := "silence"  ## cannot use skills (the basic attack still works)
const ROOT := "root"  ## cannot walk
## The classic tactics ailments (chapter three):
const SLEEP := "sleep"  ## loses its turns; any damage wakes it
const STUN := "stun"  ## loses its next turn(s), and is not woken by a hit
const CONFUSE := "confuse"  ## acts on its own, at random: it may walk anywhere and hit friend or foe
const BERSERK := "berserk"  ## acts on its own and attacks the nearest unit of either side, with +30% Attack
const DOOM := "doom"  ## a countdown: when it runs out the unit is knocked out
const CURSE := "curse"  ## healing it does half as much
const BLIND := "blind"  ## its own attacks miss 50% of the time
const SLOWED := "slowed"  ## Speed -40%: its turns come later
const HASTE := "haste"  ## Speed +50%: its turns come sooner (not an ailment)
## The statuses that hurt the unit that has one (what a cleanse removes).
const NEGATIVE: Array[String] = [MARKED, MILD_BLIND, ATK_DOWN, POISON, BURN, EXPOSED, SILENCE, ROOT, SLEEP, STUN, CONFUSE, BERSERK, DOOM, CURSE, BLIND, SLOWED]
## What the unit remembers for the AI's flavour: how many times it used each skill, and the last one (EnemyAI).
var ai_used := {}
var ai_last := ""
var fled := false  ## left the fight alive (BattleController.fleeing): counts as beaten, never knocked out
var tick_notes: Array[String] = []  ## what burn and regen did at the end of its last turn (shown on screen)
var statuses := {}  ## status -> turns left; each one ticks down at the end of this unit's own turn
var buffs := {}  ## StatModifier.Stat -> [percent, turns left]: a stat raised for some of its turns (Chance!)
var last_poison := 0  ## HP the poison took at the end of its last turn (shown on screen)


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


func has_status(s: String) -> bool:
	return statuses.get(s, 0) > 0


## Gives a status for `turns` of this unit's turns (a status already on it keeps the longer time).
func add_status(s: String, turns: int) -> void:
	statuses[s] = maxi(statuses.get(s, 0), turns)


## Called at the end of this unit's turn: each status loses one turn and ends at 0.
func tick_statuses() -> void:
	for s in statuses.keys():
		statuses[s] -= 1
		if statuses[s] <= 0:
			statuses.erase(s)
	for k in buffs.keys():
		buffs[k][1] -= 1
		if buffs[k][1] <= 0:
			buffs.erase(k)


## Raises a stat by `percent` for `turns` of this unit's turns (a buff already on that stat is replaced).
func add_buff(s: StatModifier.Stat, percent: int, turns: int) -> void:
	buffs[s] = [percent, turns]


func is_down() -> bool:
	return hp <= 0


## A final stat with equipment (see CharacterStats.final_stat).
func stat(s: StatModifier.Stat) -> int:
	var v := data.stats.final_stat(s, data.loadout) if data.stats else 0
	if buffs.has(s):
		v = v * (100 + int(buffs[s][0])) / 100
	if s == StatModifier.Stat.SPEED:
		if has_status(HASTE):
			v = v * 3 / 2
		if has_status(SLOWED):
			v = maxi(1, v * 3 / 5)
	elif s == StatModifier.Stat.ATTACK and has_status(BERSERK):
		v = v * 13 / 10
	return v


## Whether the unit's turn is lost (asleep or stunned).
func loses_turn() -> bool:
	return has_status(SLEEP) or has_status(STUN)


## Whether the unit acts on its own, whoever it belongs to (confused or berserk).
func is_unruly() -> bool:
	return has_status(CONFUSE) or has_status(BERSERK)


## The unit's stance for this battle (fixed; see _stance).
func stance() -> WeaponStyle.Stance:
	return _stance


func style() -> WeaponStyle:
	return data.loadout.weapon_style if data.loadout else null


## The field relic this vessel is tethered to (its Temp-Relic), or null.
func temp_relic() -> RelicItem:
	return data.loadout.temp_relic if data.loadout else null
