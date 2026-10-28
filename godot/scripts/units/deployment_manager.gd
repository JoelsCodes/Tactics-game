class_name DeploymentManager
extends Node
## One side's deployment on a TacticalGrid, and the relic tether cycle.
##
## Limits on the field at once: exactly 1 King (required to start), at most 1 Co-Captain, up to 6
## Vessels.
##
## Relics and vessels:
##   - Field relics lie on tiles as RelicProps (placed with place_relic at battle start; which relics and
##     where comes from the map later). No unit can pick them up. Inventory relics never become props.
##   - The King summons a vessel onto a prop: the vessel is tethered to that relic. Its sprite replaces
##     the prop on that tile and the relic goes into the vessel's Temp-Relic slot. Needs the King standing,
##     the tile within 30% of the map's longer side of him (straight-line), and nobody on the tile.
##   - A vessel's Fade Clock (VesselData.fade_turns, 5) goes down by 1 every time that vessel ends its
##     turn. While the vessel is knocked out the clock is paused; it resumes once revived. At 0 the
##     vessel is untethered automatically; this is the only way a vessel is untethered. Each untether
##     adds 1 to the vessel's permanent Sever Count (VesselData.sever_count). Each summon adds 1 to
##     its permanent Tether Count (VesselData.tether_count).
##   - A vessel removed from the field cannot be summoned again this battle.
##   - On untether, 25% (UNTETHER_RETURN_CHANCE): the relic goes home to the permanent inventory.
##     Otherwise it reappears as a prop on the vessel's tile, ready for another vessel.
##   - At the end of battle each vessel still on the field has 10% (END_RETURN_CHANCE) to take its
##     relic home; otherwise the relic is lost. Props still on the field are lost.
##
## The combat layer calls: deploy_king / deploy_co_captain / summon_vessel, end_turn(unit) when each
## unit ends its turn, end_battle() at the end. Relics sent home are collected in `secured`.

signal unit_deployed(unit: BattleUnit)
## A vessel's Fade Clock ran out; `went_home` says whether its relic reached the inventory.
signal vessel_untethered(vessel: BattleUnit, went_home: bool)
signal relic_placed(prop: RelicProp)
signal relic_secured(relic: RelicItem)
signal relic_lost(relic: RelicItem)

const MAX_KINGS := 1
const MAX_CO_CAPTAINS := 1
const MAX_VESSELS := 6
## Summon radius as a share of the map's longer side, measured from the King.
const SUMMON_RANGE_SHARE := 0.30
## Chance an untethered vessel (Fade Clock at 0) takes its relic home.
const UNTETHER_RETURN_CHANCE := 0.25
## Chance a vessel still on the field when the battle ends takes its relic home.
const END_RETURN_CHANCE := 0.10

@export var team := 0
## Scene for relic props (its root must extend RelicProp); empty uses a bare RelicProp.
@export var prop_scene: PackedScene
## Where relic props are added; empty adds them to this node.
@export var prop_parent: NodePath

var grid: TacticalGrid
var king: BattleUnit
var co_captain: BattleUnit
var vessels: Array[BattleUnit] = []  ## on the field now
var removed: Array[VesselData] = []  ## vessels removed this battle; they cannot be summoned again
var props := {}  ## Vector2i -> RelicProp (one relic per tile)
var secured: Array[RelicItem] = []  ## relics sent home to the permanent inventory this battle
var rng := RandomNumberGenerator.new()  ## seed it for repeatable results


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
		UnitData.Role.VESSEL:
			return "vessels are summoned onto relics (summon_vessel)"
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


## The battle may start only with exactly one King deployed.
func ready_to_start() -> bool:
	return king != null


# ---------- relic props ----------

## Puts a relic on the field as a prop (battle setup, or a relic reappearing). One relic per tile.
func place_relic(relic: RelicItem, cell: Vector2i) -> RelicProp:
	if not grid.in_bounds(cell) or props.has(cell):
		push_warning("DeploymentManager: cannot place a relic at %s" % cell)
		return null
	var p: RelicProp = prop_scene.instantiate() if prop_scene else RelicProp.new()
	p.relic = relic
	p.cell = cell
	p.name = "Relic_%d_%d" % [cell.x, cell.y]
	var parent := get_node_or_null(prop_parent) if not prop_parent.is_empty() else self
	(parent if parent else self).add_child(p)
	props[cell] = p
	relic_placed.emit(p)
	return p


func prop_at(cell: Vector2i) -> RelicProp:
	return props.get(cell)


# ---------- vessels ----------

## Why the King cannot summon `vessel` onto the relic prop on `cell` right now, or "" if he can.
func summon_error(vessel: VesselData, cell: Vector2i) -> String:
	if prop_at(cell) == null:
		return "no relic on that tile"
	if king == null or king.is_down():
		return "the King must be on the field to summon"
	if removed.has(vessel):
		return "removed this battle"
	if is_deployed(vessel):
		return "already on the field"
	if vessels.size() >= MAX_VESSELS:
		return "only %d Vessels" % MAX_VESSELS
	if not in_summon_range(cell):
		return "too far from the King"
	if not grid.can_stand(cell):
		return "tile is blocked or occupied"
	return ""


func can_summon(vessel: VesselData, cell: Vector2i) -> bool:
	return summon_error(vessel, cell) == ""


## The King summons `vessel` onto the relic on `cell` and tethers it: the prop is removed (the vessel
## stands in its place) and the relic goes into the vessel's Temp-Relic slot. The Fade Clock starts at
## VesselData.fade_turns.
func summon_vessel(vessel: VesselData, cell: Vector2i) -> BattleUnit:
	var err := summon_error(vessel, cell)
	if err != "":
		push_warning("DeploymentManager: cannot summon %s at %s: %s" % [vessel.display_name, cell, err])
		return null
	var p: RelicProp = props[cell]
	props.erase(cell)
	p.queue_free()
	if vessel.loadout == null:
		vessel.loadout = EquipmentLoadout.new()
	vessel.loadout.tether_relic(p.relic)
	vessel.tether_count += 1
	var bu := _put(vessel, cell)
	bu.anchor = king
	bu.fade_clock = FadeClock.new(vessel.fade_turns)
	vessels.append(bu)
	unit_deployed.emit(bu)
	return bu


## Summon radius in tiles: 30% of the map's longer side.
func summon_radius() -> float:
	return SUMMON_RANGE_SHARE * maxi(grid.width, grid.depth)


## Whether `cell` is within the summon radius of the King (straight-line distance between tile centres).
func in_summon_range(cell: Vector2i) -> bool:
	return king != null and Vector2(cell - king.cell).length() <= summon_radius() + 0.001


func vessel_slots_left() -> int:
	return MAX_VESSELS - vessels.size() if king != null and not king.is_down() else 0


## Call when a unit ends its turn. A vessel's Fade Clock goes down by 1; at 0 it is untethered.
## A knocked-out vessel's clock is paused. Returns true if the unit was untethered.
func end_turn(bu: BattleUnit) -> bool:
	if not bu.is_vessel() or not bu.on_field or bu.is_down():
		return false
	if bu.fade_clock.tick():
		_untether(bu)
		return true
	return false


## Fade Clock ran out: the vessel leaves the field for the rest of the battle, its Sever Count goes up
## by 1, and its relic either goes home (UNTETHER_RETURN_CHANCE) or reappears as a prop on its tile.
func _untether(bu: BattleUnit) -> void:
	var cell := bu.cell
	_remove_vessel(bu)
	(bu.data as VesselData).sever_count += 1
	var relic: RelicItem = bu.data.loadout.release_temp_relic()
	var home := rng.randf() < UNTETHER_RETURN_CHANCE
	if relic != null:
		if home:
			_secure(relic)
		else:
			place_relic(relic, cell)
	vessel_untethered.emit(bu, home)


func _remove_vessel(bu: BattleUnit) -> void:
	_take_off(bu)
	vessels.erase(bu)
	removed.append(bu.data as VesselData)


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


func _secure(relic: RelicItem) -> void:
	secured.append(relic)
	relic_secured.emit(relic)


# ---------- end of battle ----------

## Ends the battle. Each vessel still on the field leaves (not an untether, so no Sever Count) and
## takes its Temp-Relic home with END_RETURN_CHANCE; otherwise the relic is lost. Relic props still on
## the field are lost. Inventory relics in Relic Slots 1 and 2 are permanent and stay equipped.
## Returns every relic sent home this battle (from untethers and from the end roll).
func end_battle() -> Array[RelicItem]:
	for v in vessels.duplicate():
		var relic: RelicItem = v.data.loadout.release_temp_relic()
		if relic != null:
			if rng.randf() < END_RETURN_CHANCE:
				_secure(relic)
			else:
				relic_lost.emit(relic)
		_take_off(v)
	vessels.clear()
	removed.clear()
	for cell in props:
		relic_lost.emit(props[cell].relic)
		props[cell].queue_free()
	props.clear()
	var haul := secured.duplicate()
	secured.clear()
	return haul
