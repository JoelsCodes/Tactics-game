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


var ok := false
var error := ""  ## why it was refused
var action: BattleAction
var area: TargetArea
var sp_spent := 0
var hits: Array[Hit] = []
var skill_levels_gained := 0
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
