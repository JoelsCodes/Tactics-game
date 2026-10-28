class_name PartyRoster
extends Resource
## The player's party between battles: the King, the Co-Captains, the vessels (the King's
## vessel_roster) and the permanent relic inventory.

@export var king: KingData
@export var co_captains: Array[CoCaptainData] = []
## Permanent relics: equipped in Relic Slot 1 or 2 from the menus; never placed on the field.
@export var relic_inventory: Array[RelicItem] = []


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


## Adds relics brought home from a battle (DeploymentManager.end_battle) to the inventory.
func receive_relics(relics: Array[RelicItem]) -> void:
	for r in relics:
		if not relic_inventory.has(r):
			relic_inventory.append(r)
	emit_changed()
