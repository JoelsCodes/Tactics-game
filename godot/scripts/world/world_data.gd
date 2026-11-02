class_name WorldData
extends RefCounted
## The world map's places and their maps (data only; WorldMapScreen draws it). Every place opens when the story unlocks it
## (CampaignState.areas_unlocked), one at a time. A place has maps; a map has levels; a level is a battle.
##
## A story map (the Keep's hallway and chamber) can be played from the world map once the story has cleared it. Any other
## map in an unlocked place can be played from the start. The first time a map is played, the party's levels are written
## down (CampaignState.record_first_play); every replay (a cleared map) carries the units at those levels, with no story
## beats, and keeps nothing it earns. The enemies are the map's own set for now (a randomised set may come later).
## Place and map names marked "placeholder" are Claude's, for the owner to rename.

const BASE := &"base"
## Place id -> what clearing a map unlocks. The story also unlocks places directly (BaseCutscene opens the riverbank).
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
			{"id": "crossing", "name": "The Crossing", "story": false, "blurb": "Take the bridge. The far bank is held. (Placeholder map.)",
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


## Opens what clearing `map_id` unlocks (and marks it cleared). Returns the places that were new.
static func clear_map(campaign: CampaignState, map_id: String) -> Array[StringName]:
	campaign.mark_cleared(map_id)
	var opened: Array[StringName] = []
	for id in UNLOCKED_BY_CLEARING.get(map_id, []):
		if campaign.unlock_area(id):
			opened.append(id)
	return opened


## "locked" (not open yet), "new" (open, not played), "started" (played, not cleared) or "cleared".
static func map_state(campaign: CampaignState, map_id: String) -> String:
	var p := place_of(map_id)
	var m := map(map_id)
	if p.is_empty() or not campaign.is_area_unlocked(p.id):
		return "locked"
	if campaign.is_map_cleared(map_id):
		return "cleared"
	if m.get("story", false):
		return "locked"  # a story map opens by playing it in the story
	return "started" if campaign.has_played(map_id) else "new"


## True when picking the map plays it as a replay (a cleared map).
static func is_replay(campaign: CampaignState, map_id: String) -> bool:
	return campaign.is_map_cleared(map_id)


## The game a level is played with. A replay is a copy of `game` with every unit at the level it had the first time the map was
## played (units that were not there then are left out of the vessels): what it earns is thrown away with the copy. A first
## play uses `game` itself.
static func game_for(game: SaveGame, map_id: String) -> SaveGame:
	if not is_replay(game.campaign, map_id):
		return game
	var copy := SaveCodec.decode(SaveCodec.encode(game)).game
	var levels := game.campaign.first_levels(map_id)
	if levels.is_empty():
		return copy
	var owned: Array[VesselData] = copy.roster.king.vessel_roster
	for v in owned.duplicate():
		if not levels.has(CampaignState.unit_key(v)):
			owned.erase(v)
	for u in copy.roster.all_units():
		var key := CampaignState.unit_key(u)
		if levels.has(key):
			u.stats.level = int(levels[key])
			u.stats.exp = 0
	return copy


## The battle for a level (1-based) of a map: its setup, set up to return to the world map afterwards.
static func setup_for(game: SaveGame, map_id: String, level: int) -> BattleSetup:
	var s: BattleSetup
	match map_id:
		"hallway":
			s = FirstBattle.setup(HallwayCutscene.HALFWAY, HallwayCutscene.ENTRANCE)
		"chamber":
			s = FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, ChamberCutscene.SQUIRES_TO)
		"crossing":
			s = SampleBattle.setup(level)
		_:
			return null
	var replay := is_replay(game.campaign, map_id)
	s.map_id = map_id
	s.level = level
	s.replay = replay
	s.world = true
	s.tutorial = false if replay else s.tutorial
	s.on_win = "res://scenes/world_map.tscn"
	return s


## Starts a level from the world map. Returns false when the map cannot be played.
static func start(tree: SceneTree, game: SaveGame, map_id: String, level: int) -> bool:
	if map_state(game.campaign, map_id) in ["locked", ""]:
		return false
	var s := setup_for(game, map_id, level)
	if s == null:
		return false
	BattleStage.pending_game = game_for(game, map_id)
	BattleStage.pending_setup = s
	tree.change_scene_to_file("res://scenes/battle.tscn")
	return true
