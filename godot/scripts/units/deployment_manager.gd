class_name DeploymentManager
extends Node
## One side's deployment on a TacticalGrid.
##
## Who is on the field: exactly 1 King (required to start) and the chosen party (owner, Nov 2026: up to PartyRoster.PARTY_SIZE members picked in the
## Formation pop-up and placed at the start; nobody is summoned, there are no summon stones and no relics on the field). `deploy_king`,
## `deploy_co_captain` and `deploy_party_member` put units on the grid; `end_battle` takes everyone off.

signal unit_deployed(unit: BattleUnit)
const MAX_KINGS := 1
const MAX_CO_CAPTAINS := 1
@export var team := 0

var grid: TacticalGrid
var king: BattleUnit
var co_captain: BattleUnit
var extra_captains: Array[BattleUnit] = []  ## party Co-Captains after the first (the party can hold several)
var vessels: Array[BattleUnit] = []  ## on the field now


func setup(board: TacticalGrid) -> void:
	grid = board


# ---------- humans ----------

## Why a King or Co-Captain cannot be deployed at `cell` right now, or "" if they can.
func deploy_error(unit: UnitData, cell: Vector2i) -> String:
	if grid == null:
		return "no grid"
	if not grid.can_stand(cell):
		return "tile is blocked or occupied"
	if is_deployed(unit):
		return "already on the field"
	match unit.role():
		UnitData.Role.KING:
			if king != null:
				return "only %d King" % MAX_KINGS
		UnitData.Role.CO_CAPTAIN:
			if co_captain != null:
				return "only %d Co-Captain" % MAX_CO_CAPTAINS
	return ""


func deploy_king(unit: KingData, cell: Vector2i) -> BattleUnit:
	return _deploy_human(unit, cell)


func deploy_co_captain(unit: CoCaptainData, cell: Vector2i) -> BattleUnit:
	return _deploy_human(unit, cell)


func _deploy_human(unit: UnitData, cell: Vector2i) -> BattleUnit:
	var err := deploy_error(unit, cell)
	if err != "":
		push_warning("DeploymentManager: cannot deploy %s: %s" % [unit.display_name, err])
		return null
	var bu := _put(unit, cell)
	if unit.role() == UnitData.Role.KING:
		king = bu
	else:
		co_captain = bu
	unit_deployed.emit(bu)
	return bu


## Puts one member of the chosen party on the field at the start (owner, Nov 2026: the party is picked in the Formation pop-up and placed on the map,
## nobody is summoned). A Co-Captain stands as one (the first is `co_captain`); a vessel is kept in `vessels` until the vessel type goes (overhaul stage 3).
## Returns the unit, or null when the tile cannot take it.
func deploy_party_member(unit: UnitData, cell: Vector2i) -> BattleUnit:
	if grid == null or not grid.can_stand(cell) or is_deployed(unit):
		push_warning("DeploymentManager: cannot place %s at %s" % [unit.display_name, cell])
		return null
	var bu := _put(unit, cell)
	if unit is VesselData:
		vessels.append(bu)
	elif co_captain == null:
		co_captain = bu
	else:
		extra_captains.append(bu)
	unit_deployed.emit(bu)
	return bu


## The battle may start only with exactly one King deployed.
func ready_to_start() -> bool:
	return king != null


# ---------- shared ----------

func is_deployed(unit: UnitData) -> bool:
	return unit_of(unit) != null


func unit_of(unit: UnitData) -> BattleUnit:
	for bu in field_units():
		if bu.data == unit:
			return bu
	return null


func field_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	if king:
		out.append(king)
	if co_captain:
		out.append(co_captain)
	out.append_array(extra_captains)
	out.append_array(vessels)
	return out


## Moves a deployed unit on the grid (the walking rules are checked by the caller).
func move_unit(bu: BattleUnit, cell: Vector2i) -> bool:
	if not grid.move_occupant(bu, cell):
		return false
	bu.cell = cell
	return true


func _put(unit: UnitData, cell: Vector2i) -> BattleUnit:
	var bu := BattleUnit.new(unit, team)
	grid.place(bu, cell, team)
	bu.cell = cell
	bu.on_field = true
	return bu


func _take_off(bu: BattleUnit) -> void:
	grid.remove(bu)
	bu.on_field = false
	bu.cell = TacticalGrid.NO_CELL


# ---------- end of battle ----------

## Ends the battle: everyone leaves the field. Returns the relics that came home (none: nothing on the field carries a relic any more).
func end_battle() -> Array[RelicItem]:
	for v in vessels.duplicate():
		_take_off(v)
	vessels.clear()
	var none: Array[RelicItem] = []
	return none
