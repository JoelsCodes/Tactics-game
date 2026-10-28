class_name CharacterStats
extends Resource
## A character's core numbers. Classless: there are no jobs, only stats, a level and proficiencies.
##
## Scale (kept small and readable on purpose):
##   Max HP  = base_max_hp x (1 + 0.02 x level)            base 25-100, so 25..100 at level 0, up to 300
##   Max SP  = (SP_BASE + will / 2 + magic / 4) x (same)    about 10 at level 0, 15-20 mid-game, 30 at most
##   Attack, Defense, Magic, Resistance, Speed, Will: single or low double digits, not scaled by level
##   Move 3-6 tiles, Jump 1-4 levels
## SP is a fixed pool derived from stats. It does not regenerate on its own; what is spent stays spent.
## Equipment changes final values through StatModifiers; every final value is clamped to
## StatModifier.LIMITS (HP 300, SP 30 at most).

const SP_BASE := 5.0

@export var display_name := ""
@export_range(0, 99) var level := 0

@export_group("Attributes")
@export_range(25, 100) var base_max_hp := 60
@export_range(0, 30) var attack := 6
@export_range(0, 30) var defense := 5
@export_range(0, 30) var magic := 5
@export_range(0, 30) var resistance := 5
@export_range(1, 30) var speed := 6
@export_range(0, 30) var will := 6  ## the main source of SP
@export_range(1, 8) var move := 4
@export_range(0, 6) var jump := 2
## Multiplies every proficiency gain (1.0 = normal, 1.25 = learns a quarter faster).
@export_range(0.5, 1.5, 0.05) var proficiency_efficiency := 1.0

@export_group("Proficiencies")
@export var proficiencies: Array[ProficiencyTrack] = []


## A stat before equipment. HP and SP scale with level; everything else is the raw value.
func base_stat(stat: StatModifier.Stat) -> float:
	match stat:
		StatModifier.Stat.MAX_HP: return base_max_hp * TacticalMath.multiplier(level)
		StatModifier.Stat.MAX_SP: return sp_from_stats()
		StatModifier.Stat.ATTACK: return attack
		StatModifier.Stat.DEFENSE: return defense
		StatModifier.Stat.MAGIC: return magic
		StatModifier.Stat.RESISTANCE: return resistance
		StatModifier.Stat.SPEED: return speed
		StatModifier.Stat.WILL: return will
		StatModifier.Stat.MOVE: return move
		StatModifier.Stat.JUMP: return jump
		StatModifier.Stat.PROF_EFFICIENCY: return proficiency_efficiency
	return 0.0


## SP pool from stats alone: (SP_BASE + will / 2 + magic / 4) x level multiplier.
func sp_from_stats() -> float:
	return (SP_BASE + will * 0.5 + magic * 0.25) * TacticalMath.multiplier(level)


## A whole-number stat after equipment, clamped to its limits. Pass null for no equipment.
func final_stat(stat: StatModifier.Stat, loadout: EquipmentLoadout = null) -> int:
	return roundi(_final(stat, loadout))


func _final(stat: StatModifier.Stat, loadout: EquipmentLoadout) -> float:
	var v := base_stat(stat)
	if loadout != null:
		# Will and Magic feed SP, so their equipment changes count toward SP too.
		if stat == StatModifier.Stat.MAX_SP:
			v = (SP_BASE + _final(StatModifier.Stat.WILL, loadout) * 0.5 + _final(StatModifier.Stat.MAGIC, loadout) * 0.25) * TacticalMath.multiplier(level)
		v = TacticalMath.apply_modifiers(v, stat, loadout.all_modifiers())
	return StatModifier.clamp_stat(stat, v)


func max_hp(loadout: EquipmentLoadout = null) -> int:
	return final_stat(StatModifier.Stat.MAX_HP, loadout)


func max_sp(loadout: EquipmentLoadout = null) -> int:
	return final_stat(StatModifier.Stat.MAX_SP, loadout)


## Proficiency efficiency after equipment (a multiplier, not rounded).
func efficiency(loadout: EquipmentLoadout = null) -> float:
	return _final(StatModifier.Stat.PROF_EFFICIENCY, loadout)


# ---------- proficiencies ----------

func proficiency(id: StringName) -> ProficiencyTrack:
	for p in proficiencies:
		if p.id == id:
			return p
	return null


## Returns the proficiency, adding it at the given rank (level 0) if the character does not have it yet.
func ensure_proficiency(id: StringName, rank := TacticalMath.Rank.C) -> ProficiencyTrack:
	var p := proficiency(id)
	if p == null:
		p = ProficiencyTrack.make(id, rank)
		proficiencies.append(p)
	return p


func proficiency_level(id: StringName) -> int:
	var p := proficiency(id)
	return p.level if p != null else 0


## Records uses of a proficiency at the character's efficiency. Returns levels gained.
func train(id: StringName, uses := 1, loadout: EquipmentLoadout = null) -> int:
	return ensure_proficiency(id).gain(efficiency(loadout), uses)
