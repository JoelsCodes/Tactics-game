class_name EquipmentLoadout
extends Resource
## A unit's four slots, in a fixed order:
##   1. main_weapon  WeaponItem   bound to the unit; set once, then only smithed, never swapped
##   2. style        WeaponStyle  chess geometry (Rook/Bishop/Knight...) and stance (Impact/Pierce/Axe)
##   3. relic_1      RelicItem    skill conduit + passives + drawbacks
##   4. relic_2      RelicItem    a second relic for dual skill learning / stacking passives
## The same relic resource cannot sit in both relic slots.

signal loadout_changed

enum Slot { MAIN_WEAPON, STYLE, RELIC_1, RELIC_2 }
const SLOT_COUNT := 4

## Can only be set while empty (when the unit is created or loaded). Use WeaponItem.smith_upgrade to improve it.
@export var main_weapon: WeaponItem:
	set(value):
		if main_weapon != null and value != main_weapon:
			push_error("EquipmentLoadout: the main weapon is bound to the unit and cannot be changed")
			return
		main_weapon = value
		loadout_changed.emit()
@export var style: WeaponStyle:
	set(value):
		style = value
		loadout_changed.emit()
@export var relic_1: RelicItem:
	set(value):
		relic_1 = value
		loadout_changed.emit()
@export var relic_2: RelicItem:
	set(value):
		relic_2 = value
		loadout_changed.emit()


static func make(weapon: WeaponItem, weapon_style: WeaponStyle = null) -> EquipmentLoadout:
	var l := EquipmentLoadout.new()
	l.main_weapon = weapon
	l.style = weapon_style
	return l


func get_slot(slot: Slot) -> ItemResource:
	match slot:
		Slot.MAIN_WEAPON: return main_weapon
		Slot.STYLE: return style
		Slot.RELIC_1: return relic_1
		Slot.RELIC_2: return relic_2
	return null


## Which item type a slot takes.
static func slot_type(slot: Slot) -> ItemResource.ItemType:
	match slot:
		Slot.MAIN_WEAPON: return ItemResource.ItemType.WEAPON
		Slot.STYLE: return ItemResource.ItemType.STYLE
	return ItemResource.ItemType.RELIC


## Whether the player may put `item` (or null, to empty it) into `slot` right now.
func can_equip(slot: Slot, item: ItemResource) -> bool:
	if slot == Slot.MAIN_WEAPON:
		return false  # bound to the unit
	if item == null:
		return true
	if item.item_type() != slot_type(slot):
		return false
	if slot == Slot.RELIC_1 and item == relic_2 or slot == Slot.RELIC_2 and item == relic_1:
		return false
	return true


## Puts an item in a player-changeable slot (style or a relic slot). Returns the item it replaced,
## or null. Refuses (and returns null, changing nothing) when can_equip is false.
func equip(slot: Slot, item: ItemResource) -> ItemResource:
	if not can_equip(slot, item):
		push_warning("EquipmentLoadout: cannot put %s in slot %s" % [item.display_name if item else "nothing", Slot.keys()[slot]])
		return null
	var old := get_slot(slot)
	match slot:
		Slot.STYLE: style = item as WeaponStyle
		Slot.RELIC_1: relic_1 = item as RelicItem
		Slot.RELIC_2: relic_2 = item as RelicItem
	return old


func unequip(slot: Slot) -> ItemResource:
	return equip(slot, null)


func relics() -> Array[RelicItem]:
	var out: Array[RelicItem] = []
	for r in [relic_1, relic_2]:
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


## Drops battle-only relics (call when a battle ends). Returns what was removed.
func clear_battle_relics() -> Array[RelicItem]:
	var gone: Array[RelicItem] = []
	if relic_1 != null and relic_1.battle_only:
		gone.append(relic_1)
		relic_1 = null
	if relic_2 != null and relic_2.battle_only:
		gone.append(relic_2)
		relic_2 = null
	return gone
