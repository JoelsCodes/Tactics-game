class_name TurnManager
extends RefCounted
## Charge-time turn order. Every tick each standing unit gains its Speed in CT; the first to reach 100
## takes a turn. Ending a turn costs CT by what the unit did: 100 if it moved and acted, 80 if it did
## one of them, 60 if neither, so waiting brings the next turn sooner.
##
## Ties at the same CT go to the higher group (leaders, then vessels, then enemies), then higher Speed,
## then whoever joined the queue first. Knocked-out units gain no CT and are skipped until revived.

## Who a queue entry is, for ordering ties and for the turn-order display.
enum Group { LEADER, VESSEL, ENEMY }

const READY_CT := 100
const COST_FULL := 100  ## moved and acted
const COST_ONE := 80  ## moved or acted
const COST_NONE := 60  ## waited

var units: Array[BattleUnit] = []  ## in joining order


static func group_of(bu: BattleUnit) -> Group:
	if bu.is_vessel():
		return Group.VESSEL
	if bu.data.is_human():
		return Group.LEADER
	return Group.ENEMY


## Adds a unit (at the start, or when a vessel is summoned mid-battle). It starts at CT 0.
func add(bu: BattleUnit) -> void:
	if not units.has(bu):
		bu.ct = 0
		units.append(bu)


## Removes a unit for good (an untethered vessel, a unit thrown off the field...).
func remove(bu: BattleUnit) -> void:
	units.erase(bu)


func can_act(bu: BattleUnit) -> bool:
	return bu.on_field and not bu.is_down()


## Advances time to the next unit's turn and returns it, or null if nobody can act.
func next() -> BattleUnit:
	var cts := {}
	for bu in units:
		cts[bu] = bu.ct
	var who := _advance(cts)
	if who != null:
		for bu in units:
			bu.ct = cts[bu]
	return who


## CT cost for ending a turn.
static func turn_cost(moved: bool, acted: bool) -> int:
	if moved and acted:
		return COST_FULL
	if moved or acted:
		return COST_ONE
	return COST_NONE


func end_turn(bu: BattleUnit, moved: bool, acted: bool) -> void:
	bu.ct = maxi(0, bu.ct - turn_cost(moved, acted))


## The next `count` turns, assuming every unit moves and acts (for the turn-order display).
## Does not change anyone's CT.
func upcoming(count: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var cts := {}
	for bu in units:
		cts[bu] = bu.ct
	while out.size() < count:
		var who := _advance(cts)
		if who == null:
			break
		out.append(who)
		cts[who] = maxi(0, cts[who] - COST_FULL)
	return out


func _advance(cts: Dictionary) -> BattleUnit:
	var active := units.filter(can_act)
	if active.is_empty():
		return null
	while true:
		var best: BattleUnit = null
		for bu in active:
			if cts[bu] >= READY_CT and (best == null or _before(bu, best, cts)):
				best = bu
		if best != null:
			return best
		for bu in active:
			cts[bu] += maxi(1, bu.stat(StatModifier.Stat.SPEED))
	return null


func _before(a: BattleUnit, b: BattleUnit, cts: Dictionary) -> bool:
	if cts[a] != cts[b]:
		return cts[a] > cts[b]
	if group_of(a) != group_of(b):
		return group_of(a) < group_of(b)
	var sa := a.stat(StatModifier.Stat.SPEED)
	var sb := b.stat(StatModifier.Stat.SPEED)
	if sa != sb:
		return sa > sb
	return units.find(a) < units.find(b)
