class_name VesselData
extends UnitData
## A Vessel: the unit a relic manifests into when the King summons it from a relic prop (see
## RelicItem.vessel). It is anchored to the King and decays: its Fade Clock starts at `fade_turns`
## and goes down by 1 every time it ends its turn. At 0 it is untethered automatically (the only way a
## vessel is untethered), which adds 1 to its permanent `sever_count`.

## Fade Clock start: how many of its own turns the vessel can end before it is untethered.
@export_range(1, 20) var fade_turns := 5
## Permanent record: how many times this vessel has been untethered (Fade Clock ran out), across battles.
@export var sever_count := 0


func role() -> Role:
	return Role.VESSEL


func decays() -> bool:
	return true
