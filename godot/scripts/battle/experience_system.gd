class_name ExperienceSystem
extends RefCounted
## The end-of-battle XP rule. Nobody gains XP during the fight: defeated enemies only add to the
## battle's XP pool (BattleSummary.exp_pool). At victory the pool is divided evenly among the
## player-side units that were actually used:
##
##   XP_per_unit = pool / participants      (whole numbers; a remainder is dropped)
##
## A participant is a King, Co-Captain or Vessel that started at least one turn this battle (a vessel
## that was summoned and faded after taking a turn counts; one that never got a turn does not). Units
## knocked out later still count. A loss or an unfinished battle gives no XP.
##
## BattleController.finish calls distribute(); the XP lands on the units' CharacterStats, which are the
## same resources the roster saves.


## The player-side units that started at least one turn.
static func participants(summary: BattleSummary) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for bu in summary.lines:
		if bu.data.role() != UnitData.Role.ENEMY and summary.lines[bu].turns > 0:
			out.append(bu)
	return out


## Each participant's share of `pool`.
static func share(pool: int, count: int) -> int:
	return pool / count if count > 0 else 0


## Hands out the pool (once per summary). Fills in the summary: participants, exp_each, and each unit's
## exp_gained, level_before / level_after and level_ups.
static func distribute(summary: BattleSummary) -> void:
	if summary.exp_distributed:
		return
	summary.exp_distributed = true
	summary.participants = participants(summary)
	summary.exp_each = 0
	if summary.outcome != BattleController.Outcome.WON or summary.exp_pool <= 0 or summary.participants.is_empty():
		return
	summary.exp_each = share(summary.exp_pool, summary.participants.size())
	for bu in summary.participants:
		var stats := bu.data.stats
		if stats == null:
			continue
		var l := summary.line(bu)
		l.level_before = stats.level
		l.level_ups = stats.add_exp(summary.exp_each, bu.data.loadout)
		l.level_after = stats.level
		l.exp_gained = summary.exp_each
