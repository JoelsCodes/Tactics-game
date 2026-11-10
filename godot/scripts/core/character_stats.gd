class_name CharacterStats
extends Resource
## A character's core numbers. Classless: there are no jobs, only stats, a level (1-99, earned with
## experience) and a fixed proficiency rank (S-F) in each of the six proficiencies.
##
## Scale (kept small and readable on purpose):
##   Max HP  = base_max_hp x (1 + 0.02 x level)            base 25-100, so 25..100 at the start, up to 300
##   Max SP  = (SP_BASE + will / 2 + magic / 4) x (same)    about 10 at the start, 15-20 mid-game, 30 at most
##   Attack, Defense, Magic, Resistance, Speed, Will: single or low double digits, not scaled by level
##   Move 3-6 tiles, Jump 1-4 levels
## SP is a fixed pool derived from stats. It does not regenerate on its own; what is spent stays spent.
## Equipment changes final values through StatModifiers; every final value is clamped to
## StatModifier.LIMITS (HP 300, SP 30 at most).

const SP_BASE := 5.0

@export var display_name := ""
## Character level, 1-99. Raised by add_exp; each level adds 2% to the HP and SP pools.
@export_range(1, 99) var level := 1:
	set(value):
		level = ExperienceCurve.clamp_level(value)
## Experience toward the next level (0 up to exp_to_next_level - 1; always 0 at the cap).
@export var exp := 0
## Lifetime experience earned. Never goes down; levels set by hand do not change it.
@export var total_exp := 0
## XP still needed for the next level when `exp` is empty (see ExperienceCurve); 0 at level 99.
var exp_to_next_level: int:
	get:
		return ExperienceCurve.to_next(level)

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


## Adds experience, levelling up as many times as it allows: leftover XP carries into the next level,
## and at level 99 it is dropped (total_exp still counts it). Returns one LevelUp per level gained,
## with the HP and SP pools (with `loadout`) before and after.
func add_exp(amount: int, loadout: EquipmentLoadout = null) -> Array[LevelUp]:
	var ups: Array[LevelUp] = []
	amount = maxi(amount, 0)
	total_exp += amount
	if level >= ExperienceCurve.MAX_LEVEL:
		exp = 0
		return ups
	exp += amount
	while level < ExperienceCurve.MAX_LEVEL and exp >= exp_to_next_level:
		var up := LevelUp.new()
		up.from_level = level
		up.hp_before = max_hp(loadout)
		up.sp_before = max_sp(loadout)
		var before := {}
		for st in GROWN:
			before[st] = final_stat(st, loadout)
		exp -= exp_to_next_level
		level += 1
		up.to_level = level
		up.hp_after = max_hp(loadout)
		up.sp_after = max_sp(loadout)
		for st in GROWN:
			var d := final_stat(st, loadout) - int(before[st])
			if d != 0:
				up.gains[st] = d
		ups.append(up)
	if level >= ExperienceCurve.MAX_LEVEL:
		exp = 0
	return ups


## Growth on level-up (owner, Nov 2026: "levels everything up like a normal tactics game"). For a unit that grows (the King, the Co-Captains,
## vessels), each level adds this share of the stat's starting value: a unit's strengths grow fastest, so a mage stays a mage. Move, Jump
## and SP do not grow (skill costs are fixed). Enemies do not grow (`grows` false, set in BattleController.add_enemy): their stats are
## written for their chapter's level already (the chapter KINDS and TUNE), keeping HP's old 2% a level.
const GROWTH := {
	StatModifier.Stat.MAX_HP: 0.05,
	StatModifier.Stat.ATTACK: 0.05,
	StatModifier.Stat.DEFENSE: 0.05,
	StatModifier.Stat.MAGIC: 0.05,
	StatModifier.Stat.RESISTANCE: 0.05,
	StatModifier.Stat.WILL: 0.05,
	StatModifier.Stat.SPEED: 0.015,
}
const GROWN := [StatModifier.Stat.MAX_HP, StatModifier.Stat.ATTACK, StatModifier.Stat.DEFENSE, StatModifier.Stat.MAGIC,
	StatModifier.Stat.RESISTANCE, StatModifier.Stat.SPEED, StatModifier.Stat.WILL]
## False for enemies (see GROWTH).
@export var grows := true
## Enemies keep the old 300 HP cap (the cap was raised to 999 for the growing party; enemy numbers were tuned under it).
const ENEMY_HP_CAP := 300.0


## How much `stat` has grown with level: 1.0 at level 1.
func growth(stat: StatModifier.Stat) -> float:
	if not grows:
		return TacticalMath.multiplier(level) if stat == StatModifier.Stat.MAX_HP else 1.0
	var g := 1.0 + float(GROWTH.get(stat, 0.0)) * (level - 1)
	return g + TacticalMath.LEVEL_STEP if stat == StatModifier.Stat.MAX_HP else g  # HP at level 1 is the old x1.02


## A stat before equipment, grown with level (growth). SP scales by the old 2% a level.
func base_stat(stat: StatModifier.Stat) -> float:
	match stat:
		StatModifier.Stat.MAX_HP: return base_max_hp * growth(stat)
		StatModifier.Stat.MAX_SP: return sp_from_stats()
		StatModifier.Stat.ATTACK: return attack * growth(stat)
		StatModifier.Stat.DEFENSE: return defense * growth(stat)
		StatModifier.Stat.MAGIC: return magic * growth(stat)
		StatModifier.Stat.RESISTANCE: return resistance * growth(stat)
		StatModifier.Stat.SPEED: return speed * growth(stat)
		StatModifier.Stat.WILL: return will * growth(stat)
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
			# SP uses the starting Will and Magic plus equipment, not their level growth (SP keeps its old 2% a level)
			var wv := will + _final(StatModifier.Stat.WILL, loadout) - base_stat(StatModifier.Stat.WILL)
			var mv := magic + _final(StatModifier.Stat.MAGIC, loadout) - base_stat(StatModifier.Stat.MAGIC)
			v = (SP_BASE + wv * 0.5 + mv * 0.25) * TacticalMath.multiplier(level)
		v = TacticalMath.apply_modifiers(v, stat, loadout.all_modifiers())
	if not grows and stat == StatModifier.Stat.MAX_HP:
		v = minf(v, ENEMY_HP_CAP)
	return StatModifier.clamp_stat(stat, v)


## Every unit's HP is scaled down (owner, Nov 2026, twice: halved, then "health low enough that you cannot just keep getting hit": Final Fantasy Tactics pace).
## Applied here, on the final value, for everyone. Static vars so tests/tension_check can try other values.
static var HP_SCALE := 0.4

## An enemy's HP follows a curve by its level on top of its own number (the chapters wrote their enemies' HP without a shared yardstick: the first
## fights' enemies were paper and the last chapters' were walls). Points are [level, multiplier], blended between; measured with tests/tension_check so
## that Alaric at the enemies' level needs about the same number of blows (three to five) all the way through. Only units that do not grow (enemies).
static var ENEMY_HP_CURVE: Array = [[1, 5.0], [7, 3.6], [13, 3.0], [18, 2.1], [22, 1.9], [28, 1.1], [35, 0.9], [60, 0.9]]


static func enemy_hp_mult(lv: int) -> float:
	var pts := ENEMY_HP_CURVE
	if lv <= int(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		if lv <= int(pts[i][0]):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			var t := float(lv - int(a[0])) / float(int(b[0]) - int(a[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	return float(pts[-1][1])


func max_hp(loadout: EquipmentLoadout = null) -> int:
	var v := _final(StatModifier.Stat.MAX_HP, loadout) * HP_SCALE
	if not grows:
		v *= enemy_hp_mult(level)
	return maxi(1, roundi(v))


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


## Most skill bar points one use of a skill in `category` can earn this character (rank gain x
## efficiency). Each use rolls up to TacticalMath.USE_VARIANCE less (roll_skill_gain).
func skill_gain(category: Proficiency.Category, loadout: EquipmentLoadout = null) -> int:
	return TacticalMath.proficiency_gain(rank_of(category), efficiency(loadout))


## Points one use actually earns: skill_gain minus a roll of 0..3, at least 1.
func roll_skill_gain(category: Proficiency.Category, loadout: EquipmentLoadout = null, rng: RandomNumberGenerator = null) -> int:
	return TacticalMath.roll_gain(rank_of(category), efficiency(loadout), rng)
