class_name VesselData
extends UnitData
## A Vessel: a unit the King summons onto a relic prop on the field. It is tethered to that relic
## (held in its Temp-Relic slot) and anchored to the King. It decays: its Fade Clock starts at
## `fade_turns` and goes down by 1 every time it ends its turn (paused while knocked out). At 0 it is
## untethered automatically (the only way a vessel is untethered), which adds 1 to its permanent
## `sever_count`, and it cannot be summoned again that battle.

## Fade Clock start: how many of its own turns the vessel can end before it is untethered.
@export_range(1, 20) var fade_turns := 5
## Permanent record: how many times this vessel has been untethered (Fade Clock ran out), across battles.
@export var sever_count := 0
## Permanent record: how many times this vessel has been summoned and tethered to a relic, across battles.
@export var tether_count := 0


func role() -> Role:
	return Role.VESSEL


func decays() -> bool:
	return true
