class_name Ashes
extends RefCounted
## Chapter ten, "Ashes of a Lie": five plain defeat-all-enemies battles on the Falcon Guard trail (samples/ashes_1..5.json, tools/make_ashes_maps.py), the story in AshesStory.
## Enemy skills are rank D and C (the Last Sentinel alone is a boss kind and may use higher ranks); rank C stones are common. Nobody joins; Aldren is a story companion only.
##   1 The Broken Road          deserters, armored scavengers and starved wolves: opportunists, NOT Reave's people
##   2 The Memorial Approach    rusted constructs, stone-armored beasts, animated weapons and a memorial guardian
##   3 The Forgotten Sentinels  ancient armored sentinels, enchanted statues, spectral training constructs and a large memorial guardian
##   4 The Stolen Dead          Falcon Guard vessels: swordsmen, archers, shield soldiers and an officer. They act with discipline and mind of their own; nothing says who summoned them
##   5 The Last Sentinel        the memorial's guardian (a boss construct, not an evil spirit), royal constructs, armored guardians and arcane sentinels
## The vessels of Battle 4 are NOT shown to be controlled, and nothing here says whether they were at the village or who summoned them.

const MAPS := ["", "res://samples/ashes_1.json", "res://samples/ashes_2.json", "res://samples/ashes_3.json", "res://samples/ashes_4.json", "res://samples/ashes_5.json"]
const NAMES := ["", "The Broken Road", "The Memorial Approach", "The Forgotten Sentinels", "The Stolen Dead", "The Last Sentinel"]
const ENEMY_LEVEL := [0, 33, 34, 35, 36, 38]
const STONE_S_CHANCE := 0.04  ## rank S, a rare variety, begins here (chapter ten)
const STONE_A_CHANCE := 0.14
const STONE_B_CHANCE := 0.26
const STONE_C_CHANCE := 0.26
const STONE_D_CHANCE := 0.15
const C := 2
const TUNE := {1: {"hp": 0.5, "atk": -6, "mag": -4}, 2: {"hp": 0.5, "atk": -6, "mag": -4}, 3: {"hp": 0.5, "atk": -6, "mag": -4}, 4: {"hp": 0.5, "atk": -6, "mag": -4}, 5: {"hp": 0.5, "atk": -6, "mag": -4}}

const KINDS := {
	# --- 1 The Broken Road
	"dsword": {"name": "Deserter Swordsman", "hp": 112, "atk": 23, "def": 14, "mag": 0, "res": 8, "spd": 7, "will": 10, "move": 4, "jump": 3, "exp": 210, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Crippling Blow", "Reckless Charge"]},
	"dxbow": {"name": "Deserter Crossbowman", "hp": 78, "atk": 24, "def": 9, "mag": 0, "res": 8, "spd": 8, "will": 10, "move": 4, "jump": 3, "exp": 200, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Rending Cut", "Crippling Blow"]},
	"dscav": {"name": "Armored Scavenger", "hp": 134, "atk": 22, "def": 18, "mag": 0, "res": 9, "spd": 4, "will": 10, "move": 3, "jump": 2, "exp": 215, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow", "Fortify"]},
	"wolf": {"name": "Starved Wolf", "hp": 92, "atk": 24, "def": 9, "mag": 0, "res": 6, "spd": 11, "will": 7, "move": 6, "jump": 3, "exp": 190, "role": "skirmisher", "rank_cap": C,
		"skills": ["Rending Cut", "Reckless Charge", "Hamstring Cut"]},
	"dcap": {"name": "Deserter Captain", "hp": 250, "atk": 25, "def": 18, "mag": 5, "res": 12, "spd": 6, "will": 17, "move": 4, "jump": 3, "exp": 560, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Rallying Blow", "Battle Hymn", "Stunning Blow", "Crippling Blow", "Fortify"]},
	# --- 2 The Memorial Approach
	"rustc": {"name": "Rusted Military Construct", "hp": 142, "atk": 23, "def": 17, "mag": 0, "res": 8, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 215, "role": "brute", "rank_cap": C,
		"skills": ["Shoulder Barge", "Cleaver of Ruin", "Crippling Blow"]},
	"sbeast": {"name": "Stone-Armored Beast", "hp": 136, "atk": 25, "def": 19, "mag": 0, "res": 8, "spd": 6, "will": 8, "move": 4, "jump": 2, "exp": 225, "role": "brute", "rank_cap": C,
		"skills": ["Reckless Charge", "Shoulder Barge", "Rending Cut", "Stunning Blow"]},
	"aweapon": {"name": "Animated Weapon", "hp": 84, "atk": 24, "def": 10, "mag": 0, "res": 8, "spd": 10, "will": 7, "move": 5, "jump": 4, "exp": 200, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Rending Cut"]},
	"mguard": {"name": "Memorial Guardian", "hp": 300, "atk": 26, "def": 21, "mag": 0, "res": 11, "spd": 3, "will": 12, "move": 3, "jump": 2, "exp": 560, "role": "guardian", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow", "Bulwark"]},
	# --- 3 The Forgotten Sentinels
	"asent": {"name": "Ancient Armored Sentinel", "hp": 150, "atk": 24, "def": 20, "mag": 0, "res": 10, "spd": 3, "will": 9, "move": 3, "jump": 1, "exp": 230, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Bulwark"]},
	"rstat": {"name": "Enchanted Royal Statue", "hp": 154, "atk": 24, "def": 19, "mag": 8, "res": 14, "spd": 3, "will": 9, "move": 3, "jump": 1, "exp": 235, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Thunderclap"]},
	"tcons": {"name": "Spectral Training Construct", "hp": 110, "atk": 23, "def": 14, "mag": 0, "res": 10, "spd": 7, "will": 9, "move": 4, "jump": 3, "exp": 215, "role": "", "rank_cap": C,
		"skills": ["Twin Strike", "Stunning Blow", "Crippling Blow", "Rallying Blow"]},
	# --- 4 The Stolen Dead: Falcon Guard vessels, disciplined soldiers of a regiment that died generations ago
	"fsword": {"name": "Falcon Guard Swordsman", "hp": 126, "atk": 26, "def": 15, "mag": 0, "res": 10, "spd": 8, "will": 14, "move": 5, "jump": 3, "exp": 250, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Crippling Blow"]},
	"farcher": {"name": "Falcon Guard Archer", "hp": 88, "atk": 26, "def": 10, "mag": 0, "res": 10, "spd": 9, "will": 14, "move": 4, "jump": 3, "exp": 240, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Hooked Haul", "Crippling Blow", "Rending Cut"]},
	"fshield": {"name": "Falcon Guard Shield Soldier", "hp": 148, "atk": 22, "def": 21, "mag": 0, "res": 11, "spd": 4, "will": 14, "move": 3, "jump": 2, "exp": 255, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Bulwark"]},
	"fofficer": {"name": "Falcon Guard Officer", "hp": 270, "atk": 27, "def": 19, "mag": 6, "res": 13, "spd": 6, "will": 20, "move": 4, "jump": 3, "exp": 640, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Stunning Blow", "Fortify", "Crippling Blow"]},
	# --- 5 The Last Sentinel: an ancient security mechanism answering a perceived threat. Heavy melee, defence and magical energy; not a spirit, not evil.
	"lsent": {"name": "The Last Sentinel", "hp": 600, "atk": 29, "def": 24, "mag": 14, "res": 16, "spd": 3, "will": 20, "move": 3, "jump": 2, "exp": 1400, "role": "guardian", "boss": true,
		"skills": ["Hammer Slam", "Cleaver of Ruin", "Shoulder Barge", "Bulwark", "Fortify", "Thunderclap"]},
	"rconst": {"name": "Ancient Royal Construct", "hp": 158, "atk": 25, "def": 20, "mag": 0, "res": 10, "spd": 3, "will": 9, "move": 3, "jump": 1, "exp": 250, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow"]},
	"eguard": {"name": "Enchanted Armored Guardian", "hp": 140, "atk": 25, "def": 21, "mag": 6, "res": 13, "spd": 5, "will": 10, "move": 4, "jump": 2, "exp": 250, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Fortify", "Bulwark"]},
	"arcsent": {"name": "Arcane Memorial Sentinel", "hp": 92, "atk": 6, "def": 11, "mag": 24, "res": 19, "spd": 6, "will": 15, "move": 4, "jump": 3, "exp": 260, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Glacier Spike", "Thunderclap", "Fortify"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("ashes_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


static func setup(n: int, _rng: RandomNumberGenerator = null) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([SummonStone.make(null, STONE_D_CHANCE, STONE_C_CHANCE, STONE_B_CHANCE, STONE_A_CHANCE, STONE_S_CHANCE), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
	s.objective = "Defeat all enemies"
	s.max_summons = 6
	s.opening_line = AshesStory.opening(n)
	return s
