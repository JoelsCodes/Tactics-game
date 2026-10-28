class_name PartyRoster
extends Resource
## The player's party between battles: the King, the Co-Captains, the vessels (the King's
## vessel_roster), the active squad of vessels and the permanent relic inventory.
##
## A relic is in exactly one place: the inventory (spare), or a Relic Slot 1 / 2 of one unit. Use
## RosterManager to move them, so the rule holds.

@export var king: KingData
@export var co_captains: Array[CoCaptainData] = []
## Spare permanent relics (not equipped by anyone): equipped in Relic Slot 1 or 2 from the menus; never
## placed on the field.
@export var relic_inventory: Array[RelicItem] = []
## The vessels brought to battle (a subset of the vessel roster, at most DeploymentManager.MAX_VESSELS).
## Only these can be summoned (see CampaignFlow.prepare_deployment).
@export var active_vessels: Array[VesselData] = []


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


## Every unit in the party: humans, then vessels.
func all_units() -> Array[UnitData]:
	var out := humans()
	out.append_array(vessels())
	return out


## Problems with the roster's consistency (empty when fine): a relic in two places, an active vessel
## that is not in the roster, a repeated or oversized squad.
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
	var roster_vessels := vessels()
	for v in active_vessels:
		if not roster_vessels.has(v):
			out.append("active vessel '%s' is not in the vessel roster" % v.display_name)
		elif active_vessels.count(v) > 1:
			out.append("active vessel '%s' is listed twice" % v.display_name)
	if active_vessels.size() > DeploymentManager.MAX_VESSELS:
		out.append("more than %d active vessels" % DeploymentManager.MAX_VESSELS)
	return out


## Adds relics brought home from a battle (DeploymentManager.end_battle) to the inventory.
func receive_relics(relics: Array[RelicItem]) -> void:
	for r in relics:
		if not relic_inventory.has(r):
			relic_inventory.append(r)
	emit_changed()
