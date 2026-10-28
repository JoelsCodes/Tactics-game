class_name EquipmentLoadout
extends Resource
## A unit's equipment slots, in a fixed order. There is no accessory slot: relics carry the accessory passives.
##   1. Main Weapon    main_weapon   WeaponItem   immutable; set once, then only smithing-upgraded
##   2. Weapon Style   weapon_style  WeaponStyle  chess vector geometry (Rook/Bishop/Knight...) and stance
##   3. Relic Slot 1   relic_slot_1  RelicItem    skill conduit + active accessory passive + negative trade-off
##   4. Relic Slot 2   relic_slot_2  RelicItem    same as Relic Slot 1
##   5. Temp-Relic     temp_relic    RelicItem    vessels only: the field relic the vessel is tethered to
## Slots 2-4 are set in the menus before battle from the permanent inventory. The Temp-Relic is never
## set by the player: only tethering in battle fills it (tether_relic / release_temp_relic), and only
## vessels are tethered. The same relic resource cannot sit in two relic slots.

signal loadout_changed

enum Slot { MAIN_WEAPON, WEAPON_STYLE, RELIC_SLOT_1, RELIC_SLOT_2, TEMP_RELIC }
const SLOT_COUNT := 5
const SLOT_NAMES: Array[String] = ["Main Weapon", "Weapon Style", "Relic Slot 1", "Relic Slot 2", "Temp-Relic"]

## Can only be set while empty (when the unit is created or loaded). Use WeaponItem.smith_upgrade to improve it.
@export var main_weapon: WeaponItem:
	set(value):
		if main_weapon != null and value != main_weapon:
			push_error("EquipmentLoadout: the main weapon is bound to the unit and cannot be changed")
			return
		main_weapon = value
		loadout_changed.emit()
@export var weapon_style: WeaponStyle:
	set(value):
		weapon_style = value
		loadout_changed.emit()
@export var relic_slot_1: RelicItem:
	set(value):
		relic_slot_1 = value
		loadout_changed.emit()
@export var relic_slot_2: RelicItem:
	set(value):
		relic_slot_2 = value
		loadout_changed.emit()
## Vessels only, battle only. Use tether_relic / release_temp_relic.
@export var temp_relic: RelicItem:
	set(value):
		temp_relic = value
		loadout_changed.emit()


static func make(weapon: WeaponItem, style: WeaponStyle = null) -> EquipmentLoadout:
	var l := EquipmentLoadout.new()
	l.main_weapon = weapon
	l.weapon_style = style
	return l


func get_slot(slot: Slot) -> ItemResource:
	match slot:
		Slot.MAIN_WEAPON: return main_weapon
		Slot.WEAPON_STYLE: return weapon_style
		Slot.RELIC_SLOT_1: return relic_slot_1
		Slot.RELIC_SLOT_2: return relic_slot_2
		Slot.TEMP_RELIC: return temp_relic
	return null


## Which item type a slot takes.
static func slot_type(slot: Slot) -> ItemResource.ItemType:
	match slot:
		Slot.MAIN_WEAPON: return ItemResource.ItemType.WEAPON
		Slot.WEAPON_STYLE: return ItemResource.ItemType.WEAPON_STYLE
	return ItemResource.ItemType.RELIC


## Whether the player may put `item` (or null, to empty it) into `slot` right now.
func can_equip(slot: Slot, item: ItemResource) -> bool:
	if slot == Slot.MAIN_WEAPON:
		return false  # bound to the unit
	if slot == Slot.TEMP_RELIC:
		return false  # filled only by tethering in battle
	if item == null:
		return true
	if item.item_type() != slot_type(slot):
		return false
	if item in relics():
		return false  # already in another relic slot
	return true


## Puts an item in a player-changeable slot (Weapon Style or a relic slot). Returns the item it replaced,
## or null. Refuses (and returns null, changing nothing) when can_equip is false.
func equip(slot: Slot, item: ItemResource) -> ItemResource:
	if not can_equip(slot, item):
		push_warning("EquipmentLoadout: cannot put %s in slot %s" % [item.display_name if item else "nothing", SLOT_NAMES[slot]])
		return null
	var old := get_slot(slot)
	match slot:
		Slot.WEAPON_STYLE: weapon_style = item as WeaponStyle
		Slot.RELIC_SLOT_1: relic_slot_1 = item as RelicItem
		Slot.RELIC_SLOT_2: relic_slot_2 = item as RelicItem
	return old


func unequip(slot: Slot) -> ItemResource:
	return equip(slot, null)


## Tethers a field relic into the Temp-Relic slot (DeploymentManager calls this for vessels).
func tether_relic(relic: RelicItem) -> void:
	temp_relic = relic


## Empties the Temp-Relic slot and returns what was in it.
func release_temp_relic() -> RelicItem:
	var r := temp_relic
	temp_relic = null
	return r


## Every relic this loadout holds: Relic Slot 1, Relic Slot 2 and the Temp-Relic. Their skills,
## passives, drawbacks and drains all apply.
func relics() -> Array[RelicItem]:
	var out: Array[RelicItem] = []
	for r in [relic_slot_1, relic_slot_2, temp_relic]:
		if r != null:
			out.append(r)
	return out


## Every stat modifier from every slot, in slot order.
func all_modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for slot in SLOT_COUNT:
		var item := get_slot(slot)
		if item != null:
			out.append_array(item.modifiers())
	return out


## Active skills the loadout gives (one per relic).
func skills() -> Array[SkillData]:
	var out: Array[SkillData] = []
	for r in relics():
		if r.skill != null:
			out.append(r.skill)
	return out


func weapon_power() -> int:
	return main_weapon.power() if main_weapon != null else 0


func sp_drain_per_turn() -> int:
	var n := 0
	for r in relics():
		n += r.sp_drain_per_turn
	return n


func hp_drain_per_turn() -> int:
	var n := 0
	for r in relics():
		n += r.hp_drain_per_turn
	return n
