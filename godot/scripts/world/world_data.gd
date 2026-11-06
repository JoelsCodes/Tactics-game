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
const UNLOCKED_BY_CLEARING := {"hallway": [&"keep"], "chamber": [&"base"], "wrath": [&"irongate"], "judgment": [&"mountain"], "mheart": [&"bellwether"], "bwstay": [&"ashen"], "exgeneral": [&"vespera"], "vstoll": [&"capital"]}

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
	{"id": &"mountain", "name": "The Forgotten Mountain", "pos": Vector2(0.90, 0.50), "kind": "keep", "links": [&"irongate", &"bellwether"],
		"blurb": "Chapter four, The Mountain That Remembers: a fortress where hundreds of soldiers still fight a siege that ended centuries ago.",
		"maps": [
			{"id": "mpass", "name": "1: The Forgotten Pass", "story": true, "mission": true, "after": "", "blurb": "A narrow road between cliffs, held by soldiers who never stopped guarding it.", "levels": ["The battle"]},
			{"id": "mscout", "name": "2: The Scout Who Never Returned", "story": true, "mission": true, "after": "mpass", "blurb": "Forest ruins, and a scout who knows he is dead.", "levels": ["The battle"]},
			{"id": "msiege", "name": "3: The Endless Siege", "story": true, "mission": true, "after": "mscout", "blurb": "The fortress courtyard, whole again for one more night, and three war standards to break.", "levels": ["The battle"]},
			{"id": "mlast", "name": "4: The Last Commander", "story": true, "mission": true, "after": "msiege", "blurb": "Gideon and his honor guard around the memorial of the fallen.", "levels": ["The battle"]},
			{"id": "mheart", "name": "5: The Mountain's Heart", "story": true, "mission": true, "after": "mlast", "blurb": "The chamber under the fortress, and the thing that feeds on the garrison's grief.", "levels": ["The battle"]},
		]},
	{"id": &"bellwether", "name": "Bellwether", "pos": Vector2(0.92, 0.72), "kind": "river", "links": [&"mountain", &"ashen"],
		"blurb": "Chapter five, The Man Behind the Summoner: a harvest town waiting for its bridge, and an old quarry with something moving under it.",
		"maps": [
			{"id": "bwroad", "name": "1: The Roadside Ambush", "story": true, "mission": true, "after": "", "blurb": "A caravan on the road to town, and creatures and raiders closing on it.", "levels": ["The battle"]},
			{"id": "bwquarry", "name": "2: The Missing Children", "story": true, "mission": true, "after": "bwroad", "blurb": "The quarry's outer ledges, and children who did not come home.", "levels": ["The battle"]},
			{"id": "bwmine", "name": "3: The Old Mine", "story": true, "mission": true, "after": "bwquarry", "blurb": "Tunnels cut in the rock, a trapped miner, and something very large below.", "levels": ["The battle"]},
			{"id": "bwhollow", "name": "4: The Empty Battlefield", "story": true, "mission": true, "after": "bwmine", "blurb": "A collapsed gallery. Only Alaric and Lyra, and no one else can answer.", "levels": ["The battle"]},
			{"id": "bwstay", "name": "5: The Choice to Stay", "story": true, "mission": true, "after": "bwhollow", "blurb": "The road is open, and the town is in danger.", "levels": ["The battle"]},
		]},
	{"id": &"ashen", "name": "The Ashen Expanse", "pos": Vector2(0.66, 0.90), "kind": "keep", "links": [&"bellwether", &"vespera"],
		"blurb": "Chapter six, The General Who Would Not Kneel: a plain of old wars, and at its centre the academy of Cassian Vale.",
		"maps": [
			{"id": "exash", "name": "1: The Ashen Expanse", "story": true, "mission": true, "after": "", "blurb": "Swords in the ash, and armor that remembers how to fight.", "levels": ["The battle"]},
			{"id": "exgate", "name": "2: The Academy Gates", "story": true, "mission": true, "after": "exash", "blurb": "A general's test at the academy's gate.", "levels": ["The battle"]},
			{"id": "exlesson", "name": "3: The General's Lesson", "story": true, "mission": true, "after": "exgate", "blurb": "A disciplined formation on the drill field.", "levels": ["The battle"]},
			{"id": "exprice", "name": "4: The Price of Victory", "story": true, "mission": true, "after": "exlesson", "blurb": "The academy's chambers failing, and a cadet trapped inside.", "levels": ["The battle"]},
			{"id": "exgeneral", "name": "5: The Unbowed General", "story": true, "mission": true, "after": "exprice", "blurb": "Cassian Vale, and his honor guard.", "levels": ["The battle"]},
		]},
	{"id": &"vespera", "name": "Vespera", "pos": Vector2(0.40, 0.88), "kind": "river", "links": [&"ashen", &"capital"],
		"blurb": "Chapter seven, The City of Silent Bells: a city built round its dead, whose bells have stopped ringing.",
		"maps": [
			{"id": "vsstreets", "name": "1: The Streets Without Sound", "story": true, "mission": true, "after": "", "blurb": "Spirits wander the fogbound streets and the towers stand silent.", "levels": ["The battle"]},
			{"id": "vscemetery", "name": "2: The Forgotten Cemetery", "story": true, "mission": true, "after": "vsstreets", "blurb": "Where the bell keepers disappeared.", "levels": ["The battle"]},
			{"id": "vscatacombs", "name": "3: The Catacombs Below", "story": true, "mission": true, "after": "vscemetery", "blurb": "Burial galleries and the crystals that hold the dead.", "levels": ["The battle"]},
			{"id": "vschoir", "name": "4: The Choir of the Lost", "story": true, "mission": true, "after": "vscatacombs", "blurb": "A chamber of captured spirits, and the man who keeps them.", "levels": ["The battle"]},
			{"id": "vstoll", "name": "5: The Last Toll", "story": true, "mission": true, "after": "vschoir", "blurb": "The top of the great bell tower.", "levels": ["The battle"]},
		]},
	{"id": &"capital", "name": "The Royal Capital", "pos": Vector2(0.16, 0.84), "kind": "keep", "links": [&"vespera"],
		"blurb": "Chapter eight, The Road to the Crown: the walls, the city and the palace at last.",
		"maps": [
			{"id": "cwhighway", "name": "1: The King's Highway", "story": true, "mission": true, "after": "", "blurb": "A royal patrol on the road, ordered to bring you in alive.", "levels": ["The battle"]},
			{"id": "cwouter", "name": "2: The Outer Defenses", "story": true, "mission": true, "after": "cwhighway", "blurb": "A moat, a curtain wall and the defenders behind them.", "levels": ["The battle"]},
			{"id": "cwoath", "name": "3: The Captain's Oath", "story": true, "mission": true, "after": "cwouter", "blurb": "Captain Aldren and the barbican.", "levels": ["The battle"]},
			{"id": "cwcity", "name": "4: The City of Crowns", "story": true, "mission": true, "after": "cwoath", "blurb": "The central avenue and the city's last organized defense.", "levels": ["The battle"]},
			{"id": "cwgates", "name": "5: The Palace Gates", "story": true, "mission": true, "after": "cwcity", "blurb": "The palace guard on the great steps. Beyond them, the throne room.", "levels": ["The battle"]},
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
		"exash":
			s = Expanse.setup(1)
		"exgate":
			s = Expanse.setup(2)
		"exlesson":
			s = Expanse.setup(3)
		"exprice":
			s = Expanse.setup(4)
		"exgeneral":
			s = Expanse.setup(5)
		"vsstreets":
			s = Vespera.setup(1)
		"vscemetery":
			s = Vespera.setup(2)
		"vscatacombs":
			s = Vespera.setup(3)
		"vschoir":
			s = Vespera.setup(4)
		"vstoll":
			s = Vespera.setup(5)
		"cwhighway":
			s = Crown.setup(1)
		"cwouter":
			s = Crown.setup(2)
		"cwoath":
			s = Crown.setup(3)
		"cwcity":
			s = Crown.setup(4)
		"cwgates":
			s = Crown.setup(5)
		"bwroad":
			s = Bellwether.setup(1)
		"bwquarry":
			s = Bellwether.setup(2)
		"bwmine":
			s = Bellwether.setup(3)
		"bwhollow":
			s = Bellwether.setup(4)
		"bwstay":
			s = Bellwether.setup(5)
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
	# chapter five (Bellwether): the first click on map 1 plays the festival and the toy and returns to the world map; the second plays the ambush
	"bwroad": {"pre": ["bw_arrival", "bw_road_pre"], "post": "bw_road_post"},
	"bwquarry": {"pre": "bw_kids_pre", "post": "bw_kids_post"},
	"bwmine": {"pre": "bw_mine_pre", "post": "bw_mine_post"},
	"bwhollow": {"pre": "bw_empty_pre", "post": "bw_empty_post"},
	"bwstay": {"pre": "bw_stay_pre", "post": "bw_stay_post"},
	# chapter six (the Ashen Expanse) and chapter seven (Vespera)
	"exash": {"pre": "ex_opening", "post": "ex_b1_post"},
	"exgate": {"pre": "ex_arrival", "post": "ex_b2_post"},
	"exlesson": {"pre": "ex_king_talk", "post": "ex_b3_post"},
	"exprice": {"pre": "ex_b4_pre", "post": "ex_b4_post"},
	"exgeneral": {"pre": "ex_b5_pre", "post": "ex_b5_post"},
	"vsstreets": {"pre": "vs_arrival", "post": "vs_b1_post"},
	"vscemetery": {"pre": "vs_seraphine", "post": "vs_b2_post"},
	"vscatacombs": {"pre": "vs_lyra", "post": "vs_b3_post"},
	"vschoir": {"pre": "vs_b4_pre", "post": "vs_b4_post"},
	"vstoll": {"pre": "vs_b5_pre", "post": "vs_b5_post"},
	# chapter eight (the capital): the road to the throne room; chapter nine begins at the doors
	"cwhighway": {"pre": "cw_hill", "post": "cw_b1_post"},
	"cwouter": {"pre": "cw_refugees", "post": "cw_b2_post"},
	"cwoath": {"pre": "cw_aldren", "post": "cw_b3_post"},
	"cwcity": {"pre": "cw_city", "post": "cw_b4_post"},
	"cwgates": {"pre": "cw_b5_pre", "post": "cw_b5_post"},
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
