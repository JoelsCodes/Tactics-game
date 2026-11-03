class_name WorldData
extends RefCounted
## The world map's places and their maps (data only; WorldMapScreen draws it). Every place opens when the story unlocks it
## (CampaignState.areas_unlocked), one at a time. A place has maps; a map has levels; a level is a battle.
##
## Every map is locked until the player has done its story mission once (CampaignState.maps_cleared). After that it can be
## replayed from the world map: the same battle, no story beats or tutorial, with the player's real party (every unit at its own
## level, every vessel) and everything the enemies normally give (XP, relics), all kept. A replay unlocks nothing new: places and
## maps open only through the story. The enemies are the map's own set for now (a randomised set may come later).
##
## A map with "mission": true is a story mission with no cutscene yet (the Riverbank's four): until the story is written it can be started
## from the world map as the story's next step, once the map named in "after" is cleared. Winning it clears it, like any story mission.
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
		"blurb": "A river country held by the Ashen Squires: four fights, from a ford to the Warden's Hold. (Placeholder place.)",
		"maps": [
			{"id": "ford", "name": "Level 1: The Ford", "story": true, "mission": true, "after": "", "blurb": "A river with one bridge, a wading ford and a ridge in the way.", "levels": ["The battle"]},
			{"id": "mill", "name": "Level 2: The Mill Race", "story": true, "mission": true, "after": "ford", "blurb": "A mill on an island in a deep moat, and a bluff on each flank.", "levels": ["The battle"]},
			{"id": "bridge", "name": "Level 3: The Broken Bridge", "story": true, "mission": true, "after": "mill", "blurb": "The bridge's middle is gone. Round by the ford or the ridge, under the archers.", "levels": ["The battle"]},
			{"id": "hold", "name": "Level 4: The Warden's Hold", "story": true, "mission": true, "after": "bridge", "blurb": "The enemy's fortress behind its moat. The boss waits on the dais.", "levels": ["The battle"]},
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


## "locked" (its story mission has not been done), "mission" (the story's next mission, startable from here) or "cleared"
## (it can be replayed).
static func map_state(campaign: CampaignState, map_id: String) -> String:
	var p := place_of(map_id)
	if p.is_empty() or not campaign.is_area_unlocked(p.id):
		return "locked"
	if campaign.is_map_cleared(map_id):
		return "cleared"
	var m := map(map_id)
	if m.get("mission", false) and (String(m.get("after", "")) == "" or campaign.is_map_cleared(String(m.after))):
		return "mission"
	return "locked"


## The battle for a level (1-based) of a map: as a replay (the default) its setup with the player's whole party in play (summon stones
## and the Co-Captain on the field, the usual summon limit), no tutorial, and back to the world map afterwards; as a story mission
## (`replay` false) the same battle, which clears the map when it is won.
static func setup_for(map_id: String, level: int, replay := true) -> BattleSetup:
	var s: BattleSetup
	match map_id:
		"hallway":
			s = FirstBattle.hallway_replay()
		"chamber":
			s = FirstBattle.chamber_replay()
		"ford":
			s = Riverbank.setup(1)
		"mill":
			s = Riverbank.setup(2)
		"bridge":
			s = Riverbank.setup(3)
		"hold":
			s = Riverbank.setup(4)
		_:
			return null
	s.map_id = map_id
	s.level = level
	s.replay = replay
	s.world = true
	s.tutorial = false
	s.on_win = "res://scenes/world_map.tscn"
	return s


## The story scene a map plays the first time its first level is picked from the world map ("" when it has none). The scene
## marks itself seen (CampaignState.scenes_seen) and returns to the world map; picking the level again starts the battle.
const CUTSCENES := {"ford": {"id": &"ford_intro", "scene": "res://scenes/ford_intro.tscn"}}


static func cutscene_for(campaign: CampaignState, map_id: String, level: int) -> String:
	var c: Dictionary = CUTSCENES.get(map_id, {})
	if c.is_empty() or level != 1 or campaign.is_scene_seen(c.id):
		return ""
	return c.scene


## Starts a level from the world map, with the real game (what it earns is kept): a replay of a cleared map, or the story's next
## mission. Returns false when the map is locked. A map with a story scene it has not shown yet plays that scene instead (and
## returns true): the battle starts the next time the level is picked.
static func start(tree: SceneTree, game: SaveGame, map_id: String, level: int) -> bool:
	var state := map_state(game.campaign, map_id)
	if state != "cleared" and state != "mission":
		return false
	var s := setup_for(map_id, level, state == "cleared")
	if s == null:
		return false
	var scene := cutscene_for(game.campaign, map_id, level)
	if scene != "":
		GameSession.game = game
		Cutscene3D.carried_game = game
		tree.change_scene_to_file(scene)
		return true
	BattleStage.pending_game = game
	BattleStage.pending_setup = s
	tree.change_scene_to_file("res://scenes/battle.tscn")
	return true
