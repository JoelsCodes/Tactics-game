class_name CharacterStats
extends Resource
## A character's core numbers. Classless: there are no jobs, only stats, a level and a fixed
## proficiency rank (S-F) in each of the six proficiencies.
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
## Multiplies every skill level gain (1.0 = normal, 1.25 = a quarter faster).
@export_range(0.5, 1.5, 0.05) var proficiency_efficiency := 1.0

## Fixed ranks: they never level up. They set how fast skills of each proficiency level up.
@export_group("Proficiency ranks")
@export var physical_rank: TacticalMath.Rank = TacticalMath.Rank.C
@export var elemental_rank: TacticalMath.Rank = TacticalMath.Rank.C
@export var healing_rank: TacticalMath.Rank = TacticalMath.Rank.C
@export var tactical_rank: TacticalMath.Rank = TacticalMath.Rank.C
@export var status_rank: TacticalMath.Rank = TacticalMath.Rank.C
@export var void_rank: TacticalMath.Rank = TacticalMath.Rank.C


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


# ---------- proficiency ranks ----------

func rank_of(category: Proficiency.Category) -> TacticalMath.Rank:
	match category:
		Proficiency.Category.PHYSICAL: return physical_rank
		Proficiency.Category.ELEMENTAL: return elemental_rank
		Proficiency.Category.HEALING: return healing_rank
		Proficiency.Category.TACTICAL: return tactical_rank
		Proficiency.Category.STATUS: return status_rank
	return void_rank


func set_rank(category: Proficiency.Category, rank: TacticalMath.Rank) -> void:
	match category:
		Proficiency.Category.PHYSICAL: physical_rank = rank
		Proficiency.Category.ELEMENTAL: elemental_rank = rank
		Proficiency.Category.HEALING: healing_rank = rank
		Proficiency.Category.TACTICAL: tactical_rank = rank
		Proficiency.Category.STATUS: status_rank = rank
		Proficiency.Category.VOID: void_rank = rank


## Skill bar points one use of a skill in `category` earns this character (rank gain x efficiency).
func skill_gain(category: Proficiency.Category, loadout: EquipmentLoadout = null) -> int:
	return TacticalMath.proficiency_gain(rank_of(category), efficiency(loadout))
