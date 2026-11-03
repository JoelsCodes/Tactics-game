class_name NpcLook
extends RefCounted
## The villagers and the mechanic: characters that only fill cutscenes, the base and towns. They are not battle units (no stats, no
## attacks), just a sheet with four-direction idle and walk (running plays the walk), cut by tools/art/npc_idle_walk.py from the
## owner's sheets and drawn as tall as the King like every character. Put one in a scene like any sheet:
## `Cutscene3D.make_unit(NpcLook.MAN, cell)`, then `walk`, `look`, `say(text, sheet)` (the portrait is a crop of its idle).

const MAN := "villager_man"
const GIRL := "villager_girl"
const KID := "villager_kid"
const MECHANIC := "mechanic"
## In the order the owner sent them, with how they are named on screen.
const SHEETS: Array[String] = [MAN, GIRL, KID, MECHANIC]
const NAMES := {MAN: "Villager", GIRL: "Villager", KID: "Villager", MECHANIC: "Mechanic"}


static func is_npc(sheet: String) -> bool:
	return SHEETS.has(sheet)
