class_name CampaignState
extends RefCounted
## Lifetime campaign tracking, saved with the game. The per-vessel `tether_count` and `sever_count`
## live on each VesselData; the totals here also cover vessels no longer in the roster.

const COUNTERS: Array[String] = [
	"battles_fought", "battles_won", "battles_lost", "vessels_tethered", "vessels_severed",
	"relics_secured", "relics_lost", "skills_learned",
]

var battles_fought := 0  ## every finished battle, including ones ended early
var battles_won := 0
var battles_lost := 0
var vessels_tethered := 0  ## total summons across the campaign
var vessels_severed := 0  ## total untethers (Fade Clock ran out) across the campaign
var relics_secured := 0  ## relics that reached the permanent inventory
var relics_lost := 0
var skills_learned := 0  ## skills taken to level 1
var missions_completed: Array[StringName] = []
## World map progress (see WorldData): the places the story has unlocked, and the maps whose story mission has been played
## (cleared) once. A map is locked until then; replaying one unlocks nothing.
var areas_unlocked: Array[StringName] = []
var maps_cleared: Array[StringName] = []


## Adds one finished battle (see BattleController.finish). A mission is completed only by a win.
func record_battle(summary: BattleSummary, mission_id: StringName = &"") -> void:
	battles_fought += 1
	match summary.outcome:
		BattleController.Outcome.WON:
			battles_won += 1
			if mission_id != &"" and not missions_completed.has(mission_id):
				missions_completed.append(mission_id)
		BattleController.Outcome.LOST:
			battles_lost += 1
	for bu in summary.lines:
		var l: BattleSummary.UnitLine = summary.lines[bu]
		vessels_tethered += l.tethers
		vessels_severed += l.severs
	relics_secured += summary.relics_secured.size()
	relics_lost += summary.relics_lost.size()
	skills_learned += summary.skills_learned.size()


func is_completed(mission_id: StringName) -> bool:
	return missions_completed.has(mission_id)


func is_area_unlocked(id: StringName) -> bool:
	return areas_unlocked.has(id)


## Opens a place on the world map (the story does this, one at a time). Returns true when it was new.
func unlock_area(id: StringName) -> bool:
	if areas_unlocked.has(id):
		return false
	areas_unlocked.append(id)
	return true


## A map's story mission was won: the map opens on the world map for replays. Returns true when it was new.
func mark_cleared(map_id: String) -> bool:
	if maps_cleared.has(StringName(map_id)):
		return false
	maps_cleared.append(StringName(map_id))
	return true


func is_map_cleared(map_id: String) -> bool:
	return maps_cleared.has(StringName(map_id))
