class_name RosterManager
extends RefCounted
## The rules for organizing the party between battles. No UI: the barracks screens call these.
##
##   - Relics: a relic is spare (in the inventory) or equipped in Relic Slot 1 / 2 of one unit, never
##     both. Equipping moves it out of the inventory; the relic it replaces goes back in. A unit carries one relic per skill.
##   - The Main Weapon is bound to its unit and there are no spare Weapon Styles yet, so those cannot be changed here.
##   - The King goes on every mission; the Formation pop-up picks the companions who go with him (PartyRoster.party).


## The unit that has `relic` equipped, or null (spare or unknown).
static func holder_of(roster: PartyRoster, relic: RelicItem) -> UnitData:
	for u in roster.all_units():
		if u.loadout and (u.loadout.relic_slot_1 == relic or u.loadout.relic_slot_2 == relic):
			return u
	return null


## Why `relic` (null = empty the slot) cannot go into `slot` of `unit`, or "" if it can.
static func equip_error(roster: PartyRoster, unit: UnitData, slot: EquipmentLoadout.Slot, relic: RelicItem) -> String:
	if unit == null or not roster.all_units().has(unit):
		return "that unit is not in the party"
	if unit.loadout == null:
		return "that unit has no equipment"
	match slot:
		EquipmentLoadout.Slot.MAIN_WEAPON:
			return "the main weapon is bound to its unit (smithing upgrades it)"
		EquipmentLoadout.Slot.WEAPON_STYLE:
			return "there are no other weapon styles to swap in yet"
	if relic != null:
		if not roster.relic_inventory.has(relic):
			return "that relic is not in the inventory"
		if relic in unit.loadout.relics():
			return "that relic is already in the other relic slot"
		if unit.loadout.duplicates_skill(slot, relic):
			return "that unit already carries a relic with that skill"
		if not unit.loadout.can_equip(slot, relic):
			return "that relic cannot go there"
	return ""


## Puts a spare relic into a relic slot (or empties the slot with null). The replaced relic goes back to
## the inventory. Returns "" or the reason it was refused (nothing changes then).
static func equip_relic(roster: PartyRoster, unit: UnitData, slot: EquipmentLoadout.Slot, relic: RelicItem) -> String:
	var err := equip_error(roster, unit, slot, relic)
	if err != "":
		return err
	var old := unit.loadout.get_slot(slot) as RelicItem
	if relic != null:
		roster.relic_inventory.erase(relic)
	if slot == EquipmentLoadout.Slot.RELIC_SLOT_1:
		unit.loadout.relic_slot_1 = relic
	else:
		unit.loadout.relic_slot_2 = relic
	if old != null and not roster.relic_inventory.has(old):
		roster.relic_inventory.append(old)
	roster.emit_changed()
	return ""
