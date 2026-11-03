class_name SupportRules
extends RefCounted
## The healing proficiency's own rules (data/skills/healing.json, SkillData.support). Each support skill has a kind:
##   heal          restores 30 HP, plus or minus 10% (rolled per use)
##   pray          50% to cure every status ailment (marked, mild blind, attack down, poison) of the target
##   roulette      50%: full heal; otherwise half of the target's current HP is taken away (never below 1 HP)
##   poison_spit   50% per enemy hit: poisoned (5% of max HP at the end of each of its turns, 3 to 5 of its turns)
##   venom_removal cures poison
##   chance        a random stat of the target up 10% for 5 of its turns (or until the battle ends); named on screen
##   sp_finisher   spends ALL remaining SP on one enemy: 110% of Attack, +5% for every 10% of its total SP still left
## Targeting: allies_only = same team only, enemies_only = other team only (both in the skill's data).
## The nominal amounts (`preview`) are what the AI and the aim preview see; the rolls happen in `roll`, when the action is performed.

const HEAL_BASE := 30
const HEAL_SPREAD := 0.10
const PRAY_CHANCE := 0.5
const ROULETTE_FULL_CHANCE := 0.5
const POISON_CHANCE := 0.5
const POISON_PERCENT := 5
const POISON_TURNS := [3, 5]
const CHANCE_PERCENT := 10
const CHANCE_TURNS := 5
const CHANCE_STATS := [StatModifier.Stat.ATTACK, StatModifier.Stat.DEFENSE, StatModifier.Stat.MAGIC, StatModifier.Stat.RESISTANCE,
	StatModifier.Stat.SPEED, StatModifier.Stat.WILL]
const FINISHER_BASE := 110  ## percent of Attack when no SP is left
const FINISHER_STEP := 5  ## percent more for every 10% of total SP still left
const AILMENTS := [BattleUnit.MARKED, BattleUnit.MILD_BLIND, BattleUnit.ATK_DOWN, BattleUnit.POISON]


static func is_support(s: SkillData) -> bool:
	return s != null and s.support != ""


## Whether `skill` may target `target` from `user`'s side.
static func may_target(user: BattleUnit, target: BattleUnit, skill: SkillData) -> bool:
	if skill == null:
		return true
	if skill.allies_only and target.team != user.team:
		return false
	if skill.enemies_only and target.team == user.team:
		return false
	return true


## Whether a support hit heals (never misses, applies no damage roll).
static func is_heal_kind(s: SkillData) -> bool:
	return s.support in ["heal", "pray", "roulette", "venom_removal", "chance"]


## The finisher's multiplier (percent of Attack) for `user` right now: 110, +5 for every 10% of its SP left.
static func finisher_percent(user: BattleUnit) -> int:
	var m := maxi(1, user.max_sp())
	var steps := clampi(user.sp * 100 / m / 10, 0, 10)
	return FINISHER_BASE + FINISHER_STEP * steps


## The nominal hit for a support skill on `target` (no rolls). Sets amount/heal on `h` and returns it.
static func preview(user: BattleUnit, target: BattleUnit, skill: SkillData, h: ActionResult.Hit, area: TargetArea, tile: Vector2i, skill_level: int) -> ActionResult.Hit:
	h.heal = is_heal_kind(skill)
	h.amount = 0
	match skill.support:
		"heal":
			h.amount = HEAL_BASE
		"sp_finisher":
			var pct := finisher_percent(user)
			h.amount = DamageFormula.skill_finisher(user, target, skill, skill_level, pct, StanceRules.damage_percent(user.stance(), area, tile))
			h.knocked_out = h.amount >= target.hp
	return h


## Rolls the outcome of a performed support action (before the HP changes are applied): sets the heal or damage amount, and the
## statuses, buffs and cures on each target that was not missed. Notes say what happened, for the screen.
static func roll(user: BattleUnit, r: ActionResult, skill: SkillData, rng: RandomNumberGenerator) -> void:
	for h in r.hits:
		if h.missed or h.target.is_down():
			continue
		var t := h.target
		match skill.support:
			"heal":
				h.amount = roundi(HEAL_BASE * rng.randf_range(1.0 - HEAL_SPREAD, 1.0 + HEAL_SPREAD))
			"pray":
				if rng.randf() < PRAY_CHANCE:
					var cured := _cure_all(t)
					h.notes.append("Cured" if cured else "No ailments")
				else:
					h.notes.append("Pray failed")
			"venom_removal":
				if t.has_status(BattleUnit.POISON):
					t.statuses.erase(BattleUnit.POISON)
					h.notes.append("Poison cured")
				else:
					h.notes.append("Not poisoned")
			"roulette":
				if rng.randf() < ROULETTE_FULL_CHANCE:
					h.heal = true
					h.amount = t.max_hp() - t.hp
					h.notes.append("Full heal")
				else:
					h.heal = false
					h.amount = mini(maxi(1, t.hp / 2), t.hp - 1)  # half of its HP, never the last point
					h.notes.append("Half HP taken")
			"chance":
				var s: StatModifier.Stat = CHANCE_STATS[rng.randi() % CHANCE_STATS.size()]
				t.add_buff(s, CHANCE_PERCENT, CHANCE_TURNS)
				h.notes.append("%s +%d%%" % [StatModifier.Stat.keys()[s].capitalize(), CHANCE_PERCENT])
			"poison_spit":
				if rng.randf() < POISON_CHANCE:
					t.add_status(BattleUnit.POISON, rng.randi_range(POISON_TURNS[0], POISON_TURNS[1]))
					h.notes.append("Poisoned")
				else:
					h.notes.append("Resisted")


## Poison at the end of a poisoned unit's turn: 5% of its max HP, never below 1 HP (it does not finish a unit off).
static func poison_tick(bu: BattleUnit) -> int:
	if not bu.has_status(BattleUnit.POISON) or bu.is_down():
		bu.last_poison = 0
		return 0
	var dmg := maxi(1, bu.max_hp() * POISON_PERCENT / 100)
	dmg = mini(dmg, maxi(0, bu.hp - 1))
	bu.hp -= dmg
	bu.last_poison = dmg
	return dmg


static func _cure_all(t: BattleUnit) -> bool:
	var had := false
	for a in AILMENTS:
		if t.has_status(a):
			t.statuses.erase(a)
			had = true
	return had
