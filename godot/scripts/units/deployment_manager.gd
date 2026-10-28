class_name DeploymentManager
extends Node
## One side's deployment on a TacticalGrid and the vessel rules.
##
## Limits on the field at once: exactly 1 King (required to start), at most 1 Co-Captain, up to 6
## Vessels. Vessels need the King on the field to be summoned, run a Fade Clock, and are severed when
## it runs out, when the King untethers them, when they fall, or when the King falls.
##
## Every sever adds 1 to the vessel's sever_count and 1 to the King's. Relics a severed vessel still
## holds (not extracted home through the King) drop as RelicProps on its tile.
##
## The combat layer calls: deploy_king / deploy_co_captain / summon_vessel before or during battle,
## start_turn(unit) at the start of each unit's turn, unit_fell(unit) on KO, extract_relics(vessel) when
## a vessel brings its relics home, end_battle() at the end.

signal unit_deployed(unit: BattleUnit)
signal vessel_severed(vessel: BattleUnit, reason: SeverReason)
signal relic_dropped(prop: RelicProp)
signal relics_extracted(vessel: BattleUnit, relics: Array[RelicItem])

enum SeverReason { FADED, UNTETHERED, FELL, KING_FELL }

const MAX_KINGS := 1
const MAX_CO_CAPTAINS := 1
const MAX_VESSELS := 6

@export var team := 0
## Tiles from the King (Chebyshev distance) where a vessel may be summoned; 0 = anywhere.
@export_range(0, 20) var summon_range := 0
## Whether a vessel severed this battle may be summoned again in the same battle.
@export var allow_resummon := false
## Scene for dropped relics (its root must extend RelicProp); empty uses a bare RelicProp.
@export var prop_scene: PackedScene
## Where dropped relic props are added; empty adds them to this node.
@export var prop_parent: NodePath

var grid: TacticalGrid
var king: BattleUnit
var co_captain: BattleUnit
var vessels: Array[BattleUnit] = []  ## on the field now
var severed: Array[UnitData] = []  ## vessels severed this battle
var extracted: Array[RelicItem] = []  ## relics brought home this battle
var props := {}  ## Vector2i -> Array[RelicProp]


func setup(board: TacticalGrid) -> void:
	grid = board


# ---------- deployment ----------

## Why a unit cannot be deployed or summoned at `cell` right now, or "" if it can.
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
			if king == null or king.is_down():
				return "the King must be on the field to summon"
			if vessels.size() >= MAX_VESSELS:
				return "only %d Vessels" % MAX_VESSELS
			if not allow_resummon and severed.has(unit):
				return "severed this battle"
			if summon_range > 0 and _cheb(cell, king.cell) > summon_range:
				return "too far from the King"
	return ""


func can_deploy(unit: UnitData, cell: Vector2i) -> bool:
	return deploy_error(unit, cell) == ""


func deploy_king(unit: KingData, cell: Vector2i) -> BattleUnit:
	return _deploy(unit, cell)


func deploy_co_captain(unit: CoCaptainData, cell: Vector2i) -> BattleUnit:
	return _deploy(unit, cell)


## Summons a vessel anchored to the King; its Fade Clock starts at the vessel's fade_turns.
func summon_vessel(unit: VesselData, cell: Vector2i) -> BattleUnit:
	return _deploy(unit, cell)


func _deploy(unit: UnitData, cell: Vector2i) -> BattleUnit:
	var err := deploy_error(unit, cell)
	if err != "":
		push_warning("DeploymentManager: cannot deploy %s: %s" % [unit.display_name, err])
		return null
	var bu := BattleUnit.new(unit, team)
	grid.place(bu, cell, team)
	bu.cell = cell
	bu.on_field = true
	match unit.role():
		UnitData.Role.KING:
			king = bu
		UnitData.Role.CO_CAPTAIN:
			co_captain = bu
		UnitData.Role.VESSEL:
			bu.anchor = king
			bu.fade_clock = FadeClock.new((unit as VesselData).fade_turns)
			vessels.append(bu)
	unit_deployed.emit(bu)
	return bu


## The battle may start only with exactly one King deployed.
func ready_to_start() -> bool:
	return king != null


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


func vessel_slots_left() -> int:
	return MAX_VESSELS - vessels.size() if king != null and not king.is_down() else 0


## Moves a deployed unit on the grid (the walking rules are checked by the caller).
func move_unit(bu: BattleUnit, cell: Vector2i) -> bool:
	if not grid.move_occupant(bu, cell):
		return false
	bu.cell = cell
	return true


# ---------- turns, falls and severing ----------

## Call at the start of a unit's turn. Ticks a vessel's Fade Clock and severs it if it runs out.
## Returns true if the unit was severed (its turn does not happen).
func start_turn(bu: BattleUnit) -> bool:
	if not bu.is_vessel() or not bu.on_field:
		return false
	if bu.fade_clock.tick():
		sever(bu, SeverReason.FADED)
		return true
	return false


## The King lets a vessel go. Its relics drop unless extracted first.
func untether(bu: BattleUnit) -> void:
	sever(bu, SeverReason.UNTETHERED)


## Call when a unit is knocked out. A fallen vessel is severed; a fallen King severs every vessel.
## Fallen humans stay on their tile (as bodies) and still count toward the limits; a fallen King
## cannot summon.
func unit_fell(bu: BattleUnit) -> void:
	if bu.is_vessel():
		sever(bu, SeverReason.FELL)
		return
	if bu == king:
		for v in vessels.duplicate():
			sever(v, SeverReason.KING_FELL)


## Removes a vessel from the field, counts the sever and drops its unextracted relics on its tile.
func sever(bu: BattleUnit, reason: SeverReason) -> void:
	if not bu.is_vessel() or not vessels.has(bu):
		return
	var cell := bu.cell
	vessels.erase(bu)
	grid.remove(bu)
	bu.on_field = false
	bu.cell = TacticalGrid.NO_CELL
	bu.data.sever_count += 1
	if king:
		king.data.sever_count += 1
	severed.append(bu.data)
	for r in bu.held_relics():
		_drop(r, cell)
	if bu.data.loadout:
		bu.data.loadout.relic_slot_1 = null
		bu.data.loadout.relic_slot_2 = null
	vessel_severed.emit(bu, reason)


# ---------- relics ----------

## A vessel brings its relics home through the King: they are kept and will not drop.
## Allowed while the vessel stands next to the King (any of the 8 neighbouring tiles).
func extract_relics(bu: BattleUnit) -> Array[RelicItem]:
	var got: Array[RelicItem] = []
	if not bu.on_field or not is_next_to_king(bu):
		return got
	got = bu.held_relics()
	extracted.append_array(got)
	bu.data.loadout.relic_slot_1 = null
	bu.data.loadout.relic_slot_2 = null
	if not got.is_empty():
		relics_extracted.emit(bu, got)
	return got


func is_next_to_king(bu: BattleUnit) -> bool:
	return king != null and king.on_field and not king.is_down() and bu != king and _cheb(bu.cell, king.cell) == 1


func props_at(cell: Vector2i) -> Array[RelicProp]:
	var out: Array[RelicProp] = []
	out.assign(props.get(cell, []))
	return out


## Takes every relic lying on a tile (removes the props). The caller decides who gets them.
func pick_up(cell: Vector2i) -> Array[RelicItem]:
	var got: Array[RelicItem] = []
	for p in props_at(cell):
		got.append(p.relic)
		p.queue_free()
	props.erase(cell)
	return got


func _drop(relic: RelicItem, cell: Vector2i) -> void:
	var p: RelicProp = prop_scene.instantiate() if prop_scene else RelicProp.new()
	p.relic = relic
	p.cell = cell
	p.name = "Relic_%d_%d_%d" % [cell.x, cell.y, props_at(cell).size()]
	var parent := get_node_or_null(prop_parent) if not prop_parent.is_empty() else self
	(parent if parent else self).add_child(p)
	if not props.has(cell):
		props[cell] = []
	props[cell].append(p)
	relic_dropped.emit(p)


# ---------- end of battle ----------

## Ends the battle: every vessel still on the field fades home without a sever (its relics are not
## lost), battle-only relics are dropped from the humans' loadouts, and the per-battle lists reset.
## Returns the relics extracted this battle.
func end_battle() -> Array[RelicItem]:
	var haul := extracted.duplicate()
	for v in vessels:
		grid.remove(v)
		v.on_field = false
	vessels.clear()
	for bu in [king, co_captain]:
		if bu and bu.data.loadout:
			bu.data.loadout.clear_battle_relics()
	severed.clear()
	extracted.clear()
	return haul


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
