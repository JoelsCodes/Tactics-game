class_name VesselData
extends UnitData
## A Vessel: a summoned entity anchored to the King. It decays: from the moment it is summoned its
## Fade Clock counts down one per turn of its own, and at zero it fades from the field, dropping the
## relics it holds where it stood. A vessel still on the field when the battle ends has a 10% chance to
## bring its relics home to the permanent inventory.

## Turns on the field before the vessel fades.
@export_range(1, 20) var fade_turns := 6


func role() -> Role:
	return Role.VESSEL


func decays() -> bool:
	return true
