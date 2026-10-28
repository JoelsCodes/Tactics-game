class_name BattleSummary
extends RefCounted
## What happened in one battle, for the results screen. BattleController fills it in as the battle
## runs and completes it in finish(). Nothing here changes the game state; the lasting changes
## (skill levels, tether_count, sever_count, relics into the inventory) have already been applied.

## One unit's battle.
class UnitLine:
	var unit: BattleUnit
	var damage_dealt := 0
	var damage_taken := 0
	var healing_done := 0
	var knockouts := 0  ## enemies (or anyone) it knocked out
	var knocked_out := false  ## was down at the end
	var sp_spent := 0
	var skill_uses := {}  ## SkillData -> uses this battle
	var skill_levels := {}  ## SkillData -> levels gained this battle (0 -> 1 means learned)
	var tethers := 0  ## vessels: times summoned this battle (tether_count gained)
	var severs := 0  ## vessels: times untethered this battle (sever_count gained)


var outcome := BattleController.Outcome.ONGOING
var turns := 0
var lines := {}  ## BattleUnit -> UnitLine
var relics_secured: Array[RelicItem] = []  ## went into the permanent inventory
var relics_lost: Array[RelicItem] = []  ## left on the field or failed the end-of-battle roll
var skills_learned: Array[SkillData] = []  ## reached level 1 this battle


func line(bu: BattleUnit) -> UnitLine:
	if not lines.has(bu):
		var l := UnitLine.new()
		l.unit = bu
		lines[bu] = l
	return lines[bu]


## Records one performed action.
func add_action(user: BattleUnit, r: ActionResult) -> void:
	var u := line(user)
	u.sp_spent += r.sp_spent
	if r.action.skill:
		u.skill_uses[r.action.skill] = u.skill_uses.get(r.action.skill, 0) + 1
		if r.skill_levels_gained > 0:
			var before: int = u.skill_levels.get(r.action.skill, 0)
			u.skill_levels[r.action.skill] = before + r.skill_levels_gained
			var tree := user.data.skill_tree
			if tree and tree.skill_level(r.action.skill) - r.skill_levels_gained == 0 and not skills_learned.has(r.action.skill):
				skills_learned.append(r.action.skill)
	for h in r.hits:
		if h.heal:
			u.healing_done += h.amount
		else:
			u.damage_dealt += h.amount
			line(h.target).damage_taken += h.amount
			if h.knocked_out:
				u.knockouts += 1


## One text line per unit, e.g. "Aldric: 24 dealt, 9 taken, 1 KO, Cinder Hymn +1 Lv".
func describe(bu: BattleUnit) -> String:
	var u := line(bu)
	var parts: Array[String] = ["%d dealt" % u.damage_dealt, "%d taken" % u.damage_taken]
	if u.healing_done:
		parts.append("%d healed" % u.healing_done)
	if u.knockouts:
		parts.append("%d KO" % u.knockouts)
	for s in u.skill_levels:
		parts.append("%s +%d Lv" % [s.display_name, u.skill_levels[s]])
	if u.tethers or u.severs:
		parts.append("tethered %d, severed %d" % [u.tethers, u.severs])
	if u.knocked_out:
		parts.append("down")
	return "%s: %s" % [bu.data.display_name, ", ".join(parts)]
