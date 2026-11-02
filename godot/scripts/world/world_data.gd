class_name WorldData
extends RefCounted
## The world map's places and their maps (data only; WorldMapScreen draws it). Every place opens when the story unlocks it
## (CampaignState.areas_unlocked), one at a time. A place has maps; a map has levels; a level is a battle.
##
## Every map is locked until the player has done its story mission once (CampaignState.maps_cleared). After that it can be
## replayed from the world map: the same battle, no story beats or tutorial, with the player's real party (every unit at its own
## level, every vessel) and everything the enemies normally give (XP, relics), all kept. A replay unlocks nothing new: places and
## maps open only through the story. The enemies are the map's own set for now (a randomised set may come later).
## Place and map names marked "placeholder" are Claude's, for the owner to rename.

const BASE := &"base"
## What the story mission on a map unlocks (places; the story also opens places directly: BaseCutscene opens the riverbank).
const UNLOCKED_BY_CLEARING := {"hallway": [&"keep"], "chamber": [&"base"]}

## The places. `pos` is where the place sits on the map screen (0..1 of its width and height); `kind` picks how the island
## is drawn; `links` are the routes to other places.
const PLACES := [
	{"id": &"base", "name": "The Hollow Base", "pos": Vector2(0.12, 0.36), "kind": "base", "links": [&"keep"],
		"blurb": "The altar chamber and the ruins around it. Alaric, Bram and Lyra make their stand here.", "maps": []},
	{"id": &"keep", "name": "The Ruined Keep", "pos": Vector2(0.28, 0.68), "kind": "keep", "links": [&"base", &"riverbank"],
		"blurb": "A castle fallen into the hills. The hunt ended here, and the altar answered.",
		"maps": [
			{"id": "hallway", "name": "The Keep Hallway", "story": true, "blurb": "Alaric limps in with a squire at his heels.",
				"levels": ["Level 1: the squire"]},
			{"id": "chamber", "name": "The Altar Chamber", "story": true, "blurb": "A dead end, an altar, and two spirits to call.",
				"levels": ["Level 1: two squires"]},
		]},
	{"id": &"riverbank", "name": "Riverbank", "pos": Vector2(0.52, 0.40), "kind": "river", "links": [&"keep", &"thornmoor", &"saltglass"],
		"blurb": "A river with one bridge, and the far bank held against you. (Placeholder place.)",
		"maps": [
			{"id": "crossing", "name": "The Crossing", "story": true, "blurb": "Take the bridge. The far bank is held. (Placeholder map: its story mission is not written yet, so it stays locked.)",
				"levels": ["Level 1: the far bank", "Level 2: reinforced", "Level 3: the full garrison"]},
		]},
	{"id": &"thornmoor", "name": "Thornmoor", "pos": Vector2(0.74, 0.72), "kind": "unknown", "links": [&"riverbank"],
		"blurb": "Not yet known. (Placeholder place.)", "maps": []},
	{"id": &"saltglass", "name": "Saltglass Coast", "pos": Vector2(0.86, 0.26), "kind": "unknown", "links": [&"riverbank"],
		"blurb": "Not yet known. (Placeholder place.)", "maps": []},
]


static func place(id: StringName) -> Dictionary:
	for p in PLACES:
		if p.id == id:
			return p
	return {}


## The place a map is in.
static func place_of(map_id: String) -> Dictionary:
	for p in PLACES:
		for m in p.maps:
			if m.id == map_id:
				return p
	return {}


static func map(map_id: String) -> Dictionary:
	for p in PLACES:
		for m in p.maps:
			if m.id == map_id:
				return m
	return {}


## The story mission on `map_id` was won: the map opens for replays and what it unlocks opens. Returns the places that were new.
static func clear_map(campaign: CampaignState, map_id: String) -> Array[StringName]:
	campaign.mark_cleared(map_id)
	var opened: Array[StringName] = []
	for id in UNLOCKED_BY_CLEARING.get(map_id, []):
		if campaign.unlock_area(id):
			opened.append(id)
	return opened


## "locked" (its story mission has not been done) or "cleared" (it can be replayed).
static func map_state(campaign: CampaignState, map_id: String) -> String:
	var p := place_of(map_id)
	if p.is_empty() or not campaign.is_area_unlocked(p.id):
		return "locked"
	return "cleared" if campaign.is_map_cleared(map_id) else "locked"


## The battle for a level (1-based) of a map, as a replay: its setup with the player's whole party in play (summon stones and the
## Co-Captain on the field, the usual summon limit), no tutorial, and back to the world map afterwards.
static func setup_for(map_id: String, level: int) -> BattleSetup:
	var s: BattleSetup
	match map_id:
		"hallway":
			s = FirstBattle.hallway_replay()
		"chamber":
			s = FirstBattle.chamber_replay()
		"crossing":
			s = SampleBattle.setup(level)
		_:
			return null
	s.map_id = map_id
	s.level = level
	s.replay = true
	s.world = true
	s.tutorial = false
	s.on_win = "res://scenes/world_map.tscn"
	return s


## Starts a level from the world map, with the real game (what it earns is kept). Returns false when the map is locked.
static func start(tree: SceneTree, game: SaveGame, map_id: String, level: int) -> bool:
	if map_state(game.campaign, map_id) != "cleared":
		return false
	var s := setup_for(map_id, level)
	if s == null:
		return false
	BattleStage.pending_game = game
	BattleStage.pending_setup = s
	tree.change_scene_to_file("res://scenes/battle.tscn")
	return true
