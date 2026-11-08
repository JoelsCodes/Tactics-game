class_name ActionResult
extends RefCounted
## What an action did (or would do, for a preview).

## One unit's share of an action.
class Hit:
	var target: BattleUnit
	var tile: Vector2i
	var amount := 0  ## HP lost (damage) or gained (heal)
	var heal := false
	var knocked_out := false
	var missed := false  ## rolled a miss: nothing lands on this target
	var resisted := false  ## the miss was a status skill shrugged off (shown as "Resisted"); presentation only
	var blocked := false  ## the target was guarding (Defend) and took reduced damage; presentation only
	var crit := false  ## a critical blow (BattleController.crit_percent_for): 1.5x damage
	var crit_percent := 0.0  ## the chance this hit had to be critical, as shown in a forecast
	var notes: Array[String] = []  ## what else happened to the target (a cure, poison, a buff), shown on screen


## A follow-up basic attack by an ally on the far side of the target (BattleController.flank_followups).
class FollowUp:
	var unit: BattleUnit
	var hit: Hit


var ok := false
var error := ""  ## why it was refused
var action: BattleAction
var area: TargetArea
var sp_spent := 0
var hits: Array[Hit] = []
var skill_levels_gained := 0
var skill_learned: SkillData  ## a vessel took this skill from level 0 to 1: it is learned for good
var followups: Array[FollowUp] = []  ## pincer follow-ups, applied after the hits
var pushed: Array[Dictionary] = []  ## units moved back by the action: {unit, from, to}


static func refused(why: String) -> ActionResult:
	var r := ActionResult.new()
	r.error = why
	return r


func hit_on(bu: BattleUnit) -> Hit:
	for h in hits:
		if h.target == bu:
			return h
	return null
