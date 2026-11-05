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
const UNLOCKED_BY_CLEARING := {"hallway": [&"keep"], "chamber": [&"base"], "wrath": [&"irongate"], "judgment": [&"mountain"]}

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
	{"id": &"riverbank", "name": "Riverford", "pos": Vector2(0.52, 0.40), "kind": "river", "links": [&"keep", &"irongate", &"thornmoor", &"saltglass"],
		"blurb": "A borderland trade town on a river. Chapter two, The Price of Embers: a merchant who spoke too loudly, and a captain who does not forgive.",
		"maps": [
			{"id": "alley", "name": "1: The Back Alleys", "story": true, "mission": true, "after": "", "blurb": "Rot-Hounds in the muddy lanes behind the market, and a merchant running for his life.", "levels": ["The battle"]},
			{"id": "paths", "name": "2: The Tangled Paths", "story": true, "mission": true, "after": "alley", "blurb": "A canal district and a Watch patrol sent to close it.", "levels": ["The battle"]},
			{"id": "interception", "name": "3: The Interception", "story": true, "mission": true, "after": "paths", "blurb": "A walled yard, a dead-end brick wall, and squires with their blades raised.", "levels": ["The battle"]},
			{"id": "stand", "name": "4: The Final Stand", "story": true, "mission": true, "after": "interception", "blurb": "Dusk. The last of the squires hold the lane to the courtyard.", "levels": ["The battle"]},
			{"id": "wrath", "name": "5: Vesper's Wrath", "story": true, "mission": true, "after": "stand", "blurb": "The courtyard, a captain with something to hide, and reinforcements from the drain.", "levels": ["The battle"]},
		]},
	{"id": &"irongate", "name": "The Iron Gate", "pos": Vector2(0.70, 0.52), "kind": "keep", "links": [&"riverbank", &"thornmoor", &"mountain"],
		"blurb": "Chapter three, The Crucible and the Crown: an ancient amphitheater, a snowy pass and a broken terrace on the road to the Iron Spire.",
		"maps": [
			{"id": "phalanx", "name": "1: The Silent Village", "story": true, "mission": true, "after": "", "blurb": "Royal soldiers drag lanterns through the streets, and something inside them is struggling.", "levels": ["The battle"]},
			{"id": "pincer", "name": "2: The Lantern Convoy", "story": true, "mission": true, "after": "phalanx", "blurb": "A convoy of captured souls crosses a snowfield pass. Stop it.", "levels": ["The battle"]},
			{"id": "breaking", "name": "3: The Severing", "story": true, "mission": true, "after": "pincer", "blurb": "A terrace split by lava rifts, and the Soul Warden waiting at the end of it.", "levels": ["The battle"]},
			{"id": "ritual", "name": "4: The Price of a Soul", "story": true, "mission": true, "after": "breaking", "blurb": "A ritual chamber under the fortress. The apparatus holds Lyra and drinks Alaric's life.", "levels": ["The battle"]},
			{"id": "judgment", "name": "5: The Warden's Judgment", "story": true, "mission": true, "after": "ritual", "blurb": "The fortress courtyard, its generators humming, and the Warden's platform at the far end.", "levels": ["The battle"]},
		]},
	{"id": &"mountain", "name": "The Forgotten Mountain", "pos": Vector2(0.90, 0.50), "kind": "keep", "links": [&"irongate"],
		"blurb": "Chapter four, The Mountain That Remembers: a fortress where hundreds of soldiers still fight a siege that ended centuries ago.",
		"maps": [
			{"id": "mpass", "name": "1: The Forgotten Pass", "story": true, "mission": true, "after": "", "blurb": "A narrow road between cliffs, held by soldiers who never stopped guarding it.", "levels": ["The battle"]},
			{"id": "mscout", "name": "2: The Scout Who Never Returned", "story": true, "mission": true, "after": "mpass", "blurb": "Forest ruins, and a scout who knows he is dead.", "levels": ["The battle"]},
			{"id": "msiege", "name": "3: The Endless Siege", "story": true, "mission": true, "after": "mscout", "blurb": "The fortress courtyard, whole again for one more night, and three war standards to break.", "levels": ["The battle"]},
			{"id": "mlast", "name": "4: The Last Commander", "story": true, "mission": true, "after": "msiege", "blurb": "Gideon and his honor guard around the memorial of the fallen.", "levels": ["The battle"]},
			{"id": "mheart", "name": "5: The Mountain's Heart", "story": true, "mission": true, "after": "mlast", "blurb": "The chamber under the fortress, and the thing that feeds on the garrison's grief.", "levels": ["The battle"]},
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
		"alley":
			s = Riverford.setup(1)
		"paths":
			s = Riverford.setup(2)
		"interception":
			s = Riverford.setup(3)
		"stand":
			s = Riverford.setup(4)
		"wrath":
			s = Riverford.setup(5)
		"phalanx":
			s = Crucible.setup(1)
		"pincer":
			s = Crucible.setup(2)
		"breaking":
			s = Crucible.setup(3)
		"ritual":
			s = Crucible.setup(4)
		"judgment":
			s = Crucible.setup(5)
		"mpass":
			s = Mountain.setup(1)
		"mscout":
			s = Mountain.setup(2)
		"msiege":
			s = Mountain.setup(3)
		"mlast":
			s = Mountain.setup(4)
		"mheart":
			s = Mountain.setup(5)
		_:
			return null
	s.map_id = map_id
	s.level = level
	s.replay = replay
	s.world = true
	s.tutorial = false
	s.on_win = "res://scenes/world_map.tscn"
	return s


## The story scenes of chapter two (RiverfordStory). A map's "pre" scene plays the first time it is started from the world map as a story mission
## and then leads straight into its battle; its "post" scene plays after the battle is won the first time, then goes back to the world map. Each
## scene plays once per save (CampaignState.scenes_seen); a replay of a cleared map never plays one.
const SCENES := {
	"alley": {"pre": "rf_market"},
	"paths": {"pre": "rf_paths"},
	"interception": {"pre": "rf_interception"},
	"stand": {"pre": "rf_lane"},
	"wrath": {"pre": "rf_awakening", "post": "rf_escape"},
	# chapter three (rewritten Nov 2026), five battles. The first click on map 1 plays cr_unquiet and
	# returns to the world map; the second plays cr_silent_pre and starts the battle.
	"phalanx": {"pre": ["cr_unquiet", "cr_silent_pre"], "post": "cr_silent_post"},
	"pincer": {"pre": "cr_convoy_pre", "post": "cr_convoy_post"},
	"breaking": {"pre": "cr_severing_pre", "post": "cr_severing_post"},
	"ritual": {"pre": "cr_price_pre", "post": "cr_price_post"},
	"judgment": {"pre": "cr_judgment_pre", "post": "cr_judgment_post"},
	# chapter four (Mountain): the opening on the old road chains into the first battle's scene
	"mpass": {"pre": "mt_road", "post": "mt_pass_post"},
	"mscout": {"pre": "mt_scout_pre", "post": "mt_scout_post"},
	"msiege": {"pre": "mt_siege_pre", "post": "mt_siege_post"},
	"mlast": {"pre": "mt_last_pre", "post": "mt_last_post"},
	"mheart": {"pre": "mt_heart_pre", "post": "mt_heart_post"},
}


## The key of the scene to play at `when` ("pre" or "post") on `map_id`, or "" (it has none, or it has been seen).
static func scene_for(campaign: CampaignState, map_id: String, when: String) -> String:
	var keys: Variant = SCENES.get(map_id, {}).get(when, "")  # one key, or a list played one per click (the first not yet seen)
	for key in (keys if keys is Array else [keys]):
		if key != "" and not campaign.is_scene_seen(StringName(RiverfordStory.scene(String(key)).id)):
			return String(key)
	return ""


## Starts a level from the world map, with the real game (what it earns is kept): a replay of a cleared map, or the story's next
## mission. Returns false when the map is locked. The story mission's opening scene plays first (and then the battle) the first time;
## a win the first time plays the map's closing scene, if it has one, before the world map.
static func start(tree: SceneTree, game: SaveGame, map_id: String, level: int) -> bool:
	var state := map_state(game.campaign, map_id)
	if state != "cleared" and state != "mission":
		return false
	var s := setup_for(map_id, level, state == "cleared")
	if s == null:
		return false
	if state == "mission":
		s.on_win_scene = scene_for(game.campaign, map_id, "post")
	var pre := scene_for(game.campaign, map_id, "pre") if state == "mission" else ""
	if pre != "":
		GameSession.game = game
		Cutscene3D.carried_game = game
		StoryScene.queued = pre
		StoryScene.then_battle = s
		tree.change_scene_to_file("res://scenes/story_scene.tscn")
		return true
	BattleStage.pending_game = game
	BattleStage.pending_setup = s
	tree.change_scene_to_file("res://scenes/battle.tscn")
	return true
