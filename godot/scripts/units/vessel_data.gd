class_name VesselData
extends UnitData
## A Vessel: a summoned entity anchored to the King. It decays: when summoned its Sever Count starts at
## `sever_count`, loses 1 every time this vessel ends its turn, and at 0 the vessel is severed (fades)
## from the field, dropping the relics it holds where it stood. A vessel still on the field when the battle ends has a 10% chance to
## bring its relics home to the permanent inventory.

## Starting Sever Count: how many of its own turns the vessel can end before it is severed.
@export_range(1, 20) var sever_count := 6


func role() -> Role:
	return Role.VESSEL


func decays() -> bool:
	return true
