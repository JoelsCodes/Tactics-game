class_name Mountain
extends RefCounted
## Chapter four, "The Mountain That Remembers": five battles on samples/mountain_1..5.json (tools/make_mountain_maps.py), the foes, and the battle rules
## (ScenarioRules, set from here). Scenes are in MountainStory. Same build as Crucible (its `build` makes the EnemyData).
##   1 The Forgotten Pass          a mountain road with choke points; spectral infantry, archers and a veteran captain
##   2 The Scout Who Never Returned  forest ruins; Kaelen and his scouts (Kaelen withdraws when beaten: he joins later)
##   3 The Endless Siege           a fortress courtyard in sections; three war standards call reinforcements until they fall
##   4 The Last Commander          the command courtyard; Gideon and his honor guard around a memorial that must not fall
##   5 The Mountain's Heart        the chamber under the fortress; the Hollow Heart, its echoes, and Gideon and Kaelen as temporary allies
## Gideon and Kaelen join the party for good only after the final scene (`recruit`).

const MAPS := ["", "res://samples/mountain_1.json", "res://samples/mountain_2.json", "res://samples/mountain_3.json", "res://samples/mountain_4.json", "res://samples/mountain_5.json"]
const NAMES := ["", "The Forgotten Pass", "The Scout Who Never Returned", "The Endless Siege", "The Last Commander", "The Mountain's Heart"]
const ENEMY_LEVEL := [0, 8, 9, 10, 11, 12]
const FLEE_PERCENT := 25  ## Kaelen and Gideon yield at this percent of their HP: they are beaten, not killed (they join the party later)
const STANDARD_EVERY := 3  ## Battle 3: each war standard calls a soldier every 3 rounds
const ECHO_EVERY := 3  ## Battle 5: the Hollow Heart calls two echoes every 3 rounds
const STONE_D_CHANCE := 0.35
const TUNE := {1: {"hp": 0.5, "atk": -3}, 2: {"hp": 0.5, "atk": -3}, 3: {"hp": 0.5, "atk": -3}, 4: {"hp": 0.5, "atk": -3}, 5: {"hp": 0.45, "atk": -3, "mag": -2}}

const KINDS := {
	"infantry": {"name": "Spectral Infantry", "hp": 40, "atk": 9, "def": 8, "mag": 0, "res": 3, "spd": 4, "will": 6, "move": 4, "jump": 2, "exp": 45, "role": "",
		"skills": ["Quick Jab", "Twin Strike", "Rending Cut"]},
	"archer": {"name": "Spectral Archer", "hp": 30, "atk": 8, "def": 5, "mag": 0, "res": 3, "spd": 6, "will": 6, "move": 4, "jump": 3, "exp": 45, "role": "skirmisher",
		"skills": ["Pin Down", "Hamstring Cut", "Rending Cut"]},
	"captain": {"name": "Spectral Captain", "hp": 72, "atk": 10, "def": 10, "mag": 0, "res": 5, "spd": 5, "will": 10, "move": 4, "jump": 2, "exp": 110, "role": "",
		"skills": ["Rallying Blow", "Feinting Lunge", "Stunning Blow", "Twin Strike"]},
	"shield": {"name": "Spectral Shield Bearer", "hp": 56, "atk": 7, "def": 13, "mag": 0, "res": 5, "spd": 3, "will": 6, "move": 3, "jump": 1, "exp": 55, "role": "guardian",
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Hamstring Cut"]},
	"elite": {"name": "Spectral Elite Guard", "hp": 60, "atk": 11, "def": 10, "mag": 0, "res": 4, "spd": 5, "will": 8, "move": 4, "jump": 2, "exp": 70, "role": "",
		"skills": ["Cartwheel Slash", "Step-Aside Strike", "Stunning Blow", "Rending Cut"]},
	"knight": {"name": "Spectral Knight", "hp": 70, "atk": 12, "def": 12, "mag": 0, "res": 4, "spd": 4, "will": 8, "move": 4, "jump": 2, "exp": 80, "role": "brute",
		"skills": ["Stunning Blow", "Grip Loosen", "Shoulder Barge", "Rending Cut"]},
	"scout": {"name": "Spectral Scout", "hp": 30, "atk": 8, "def": 5, "mag": 0, "res": 3, "spd": 8, "will": 6, "move": 6, "jump": 4, "exp": 45, "role": "skirmisher",
		"skills": ["Step-Aside Strike", "Rending Cut", "Quick Jab", "Ankle Snare"]},
	"swordsman": {"name": "Swift Swordsman", "hp": 36, "atk": 10, "def": 6, "mag": 0, "res": 3, "spd": 8, "will": 6, "move": 5, "jump": 3, "exp": 55, "role": "skirmisher",
		"skills": ["Twin Strike", "Feinting Lunge", "Cartwheel Slash", "Step-Aside Strike"]},
	# the fortress's chief scout: dangerous but fair, and the tactician he will be as a vessel
	"kaelen": {"name": "Kaelen", "hp": 78, "atk": 11, "def": 5, "mag": 3, "res": 5, "spd": 9, "will": 12, "move": 6, "jump": 4, "exp": 160, "role": "skirmisher",
		"skills": ["Feinting Lunge", "Twin Strike", "Cartwheel Slash", "Pin Down", "Rending Cut"]},
	# the commander who would not let the siege end: durable, close-range, breaks formations
	"gideon": {"name": "Gideon", "hp": 190, "atk": 13, "def": 13, "mag": 2, "res": 8, "spd": 3, "will": 12, "move": 3, "jump": 2, "exp": 260, "role": "brute",
		"skills": ["Stunning Blow", "Shoulder Barge", "Rallying Blow", "Rending Cut", "Grip Loosen"]},
	"standard": {"name": "War Standard", "hp": 44, "atk": 1, "def": 6, "mag": 0, "res": 6, "spd": 1, "will": 4, "move": 0, "jump": 0, "exp": 70, "role": "", "behavior": "standard", "skills": []},
	"memorial": {"name": "The Memorial", "hp": 90, "atk": 1, "def": 6, "mag": 0, "res": 6, "spd": 1, "will": 4, "move": 0, "jump": 0, "exp": 0, "role": "", "behavior": "memorial", "skills": []},
	"echo": {"name": "Corrupted Echo", "hp": 34, "atk": 9, "def": 7, "mag": 0, "res": 3, "spd": 5, "will": 6, "move": 4, "jump": 2, "exp": 30, "role": "",
		"skills": ["Quick Jab", "Rending Cut", "Twin Strike"]},
	"grief": {"name": "Manifestation of Grief", "hp": 38, "atk": 3, "def": 6, "mag": 10, "res": 8, "spd": 5, "will": 14, "move": 4, "jump": 2, "exp": 60, "role": "caster",
		"skills": ["Hollow Touch", "Void Pun", "Lullaby", "Gravity Well"]},
	# the thing under the mountain: it controls ground and spirits more than it strikes
	"heart": {"name": "Hollow Heart", "hp": 210, "atk": 4, "def": 7, "mag": 13, "res": 12, "spd": 5, "will": 18, "move": 0, "jump": 0, "exp": 400, "role": "support", "boss": true,
		"skills": ["Griefbound", "Unbroken Oath", "Final Lament", "Hollow Touch", "Borrowed Hour"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("mountain_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


static func setup(n: int, _rng: RandomNumberGenerator = null) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([SummonStone.make(null, STONE_D_CHANCE), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
	s.objective = ["", "Defeat the spectral guardians", "Defeat Kaelen and his scouts", "Destroy the three war standards", "Defeat Gideon: do not let the memorial fall",
		"Defeat the Hollow Heart"][n]
	match n:
		2:
			s.flee = {"Kaelen": FLEE_PERCENT}
			s.flee_line = MountainStory.kaelen_yield()
		3:
			s.rules = {"standards": {"every": STANDARD_EVERY, "kind": "infantry", "map": 3}, "win_when_down": "standard"}
		4:
			s.flee = {"Gideon": FLEE_PERCENT}
			s.flee_line = MountainStory.gideon_yield()
			s.rules = {"protect": "The Memorial", "win_unless": ["The Memorial"]}
		5:
			s.rules = {"win_when_down": "Hollow Heart",
				"boss_summon": {"unit": "Hollow Heart", "every": ECHO_EVERY, "kind": "echo", "count": 2, "map": 5, "banner": "Echoes of War! Corrupted soldiers rise from the stone."}}
			s.temp_vessels = [Crucible.gideon(), Crucible.kaelen()]  # temporary allies: summonable here, never added to the roster
	s.opening_line = MountainStory.opening(n)
	s.max_summons = 6
	return s


## After the final scene Gideon and Kaelen join for good: two vessels added to the roster (the existing vessel system; no new interface).
static func recruit(g: SaveGame) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	for v in [Crucible.gideon(), Crucible.kaelen()]:
		if not owned.any(func(o): return o.display_name == v.display_name):
			owned.append(Crucible.join_at_level(v, g))
	return g
