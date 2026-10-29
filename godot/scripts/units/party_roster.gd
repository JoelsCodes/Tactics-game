class_name PartyRoster
extends Resource
## The player's party between battles: the King (fixed on every mission), the Co-Captains and which one
## is the active Co-Captain for the run, the vessels (the King's vessel_roster; any of them can be
## summoned in battle) and the permanent relic inventory.
##
## A relic is in exactly one place: the inventory (spare), or a Relic Slot 1 / 2 of one unit. Use
## RosterManager to move them, so the rule holds.

@export var king: KingData
@export var co_captains: Array[CoCaptainData] = []
## Spare permanent relics (not equipped by anyone): equipped in Relic Slot 1 or 2 from the menus; never
## placed on the field.
@export var relic_inventory: Array[RelicItem] = []
## The Co-Captain who goes on missions, chosen in the barracks (RosterManager.set_active_co_captain).
## Unset or no longer in the party: the first one.
@export var active_co_captain: CoCaptainData


## The King first, then the Co-Captains.
func humans() -> Array[UnitData]:
	var out: Array[UnitData] = []
	if king:
		out.append(king)
	out.append_array(co_captains)
	return out


func vessels() -> Array[VesselData]:
	var out: Array[VesselData] = []
	if king:
		out.append_array(king.vessel_roster)
	return out


## The Co-Captain deployed on the next mission, or null if the party has none.
func deployed_co_captain() -> CoCaptainData:
	if active_co_captain != null and co_captains.has(active_co_captain):
		return active_co_captain
	return co_captains[0] if not co_captains.is_empty() else null


## Every unit in the party: humans, then vessels.
func all_units() -> Array[UnitData]:
	var out := humans()
	out.append_array(vessels())
	return out


## Problems with the roster's consistency (empty when fine): a relic in two places, an active
## Co-Captain who is not in the party.
func audit() -> Array[String]:
	var out: Array[String] = []
	var where := {}  ## relic -> where it was first found
	for r in relic_inventory:
		if where.has(r):
			out.append("relic '%s' is in the inventory twice" % r.display_name)
		where[r] = "the inventory"
	for u in all_units():
		if u.loadout == null:
			continue
		for r in [u.loadout.relic_slot_1, u.loadout.relic_slot_2]:
			if r == null:
				continue
			if where.has(r):
				out.append("relic '%s' is in %s and on %s" % [r.display_name, where[r], u.display_name])
			where[r] = u.display_name
	if active_co_captain != null and not co_captains.has(active_co_captain):
		out.append("active Co-Captain '%s' is not in the party" % active_co_captain.display_name)
	return out


## Adds relics brought home from a battle (DeploymentManager.end_battle) to the inventory.
func receive_relics(relics: Array[RelicItem]) -> void:
	for r in relics:
		if not relic_inventory.has(r):
			relic_inventory.append(r)
	emit_changed()
