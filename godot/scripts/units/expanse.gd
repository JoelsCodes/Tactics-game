class_name Expanse
extends RefCounted
## Chapter six, "The General Who Would Not Kneel": five plain defeat-all-enemies battles in the Ashen Expanse (samples/expanse_1..5.json, tools/make_late_maps.py) with
## the story in ExpanseStory. Enemy skills are rank D and C; the summon stones carry rank C commonly (owner). Cassian Vale is the fifth battle's boss and does NOT become a
## vessel: he refuses and stays a recurring character (no recruit function exists on purpose).
##   1 The Ashen Expanse     living armor, animated blades, a rust construct, an armored sentinel
##   2 The Academy Gates     cadets, training constructs, phantom archers, an academy instructor
##   3 The General's Lesson  a coordinated formation: shield line, archers, elite swordsmen, a tactical instructor
##   4 The Price of Victory  the academy's chambers failing: corrupted soldiers and guardians (the trapped cadet is told in the scenes, not played as an objective)
##   5 The Unbowed General   Cassian and his honor guard

const MAPS := ["", "res://samples/expanse_1.json", "res://samples/expanse_2.json", "res://samples/expanse_3.json", "res://samples/expanse_4.json", "res://samples/expanse_5.json"]
const NAMES := ["", "The Ashen Expanse", "The Academy Gates", "The General's Lesson", "The Price of Victory", "The Unbowed General"]
const ENEMY_LEVEL := [0, 15, 16, 16, 17, 18]
const STONE_C_CHANCE := 0.45
const STONE_D_CHANCE := 0.35
const C := 2
const TUNE := {1: {"hp": 0.5, "atk": -4, "mag": -2}, 2: {"hp": 0.5, "atk": -4, "mag": -2}, 3: {"hp": 0.5, "atk": -4, "mag": -2}, 4: {"hp": 0.5, "atk": -4, "mag": -2}, 5: {"hp": 0.42, "atk": -5, "mag": -3}}

const KINDS := {
	"armor": {"name": "Living Armor", "hp": 64, "atk": 13, "def": 12, "mag": 0, "res": 5, "spd": 3, "will": 8, "move": 3, "jump": 2, "exp": 85, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Crippling Blow"]},
	"blade": {"name": "Animated Blade", "hp": 38, "atk": 14, "def": 5, "mag": 0, "res": 4, "spd": 9, "will": 6, "move": 6, "jump": 4, "exp": 70, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Rending Cut"]},
	"construct": {"name": "Rust Construct", "hp": 90, "atk": 15, "def": 12, "mag": 0, "res": 4, "spd": 2, "will": 6, "move": 3, "jump": 1, "exp": 110, "role": "brute", "rank_cap": C,
		"skills": ["Shoulder Barge", "Cleaver of Ruin", "Crippling Blow"]},
	"sentinel": {"name": "Armored Sentinel", "hp": 170, "atk": 16, "def": 15, "mag": 0, "res": 8, "spd": 2, "will": 10, "move": 3, "jump": 2, "exp": 260, "role": "guardian", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Crippling Blow", "Shoulder Barge"]},
	"cadet": {"name": "Spectral Cadet", "hp": 40, "atk": 12, "def": 6, "mag": 0, "res": 4, "spd": 6, "will": 7, "move": 4, "jump": 3, "exp": 70, "role": "", "rank_cap": C,
		"skills": ["Quick Jab", "Rending Cut", "Twin Strike"]},
	"trainer": {"name": "Armored Training Construct", "hp": 78, "atk": 13, "def": 13, "mag": 0, "res": 5, "spd": 3, "will": 7, "move": 3, "jump": 1, "exp": 95, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Fortify"]},
	"parcher": {"name": "Phantom Archer", "hp": 36, "atk": 13, "def": 4, "mag": 0, "res": 4, "spd": 7, "will": 7, "move": 4, "jump": 3, "exp": 80, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Rending Cut", "Crippling Blow"]},
	"instructor": {"name": "Academy Instructor", "hp": 110, "atk": 15, "def": 10, "mag": 0, "res": 6, "spd": 5, "will": 12, "move": 4, "jump": 2, "exp": 200, "role": "brute", "rank_cap": C,
		"skills": ["Rallying Blow", "Cartwheel Slash", "Stunning Blow", "Disrupt Formation"]},
	"shieldwall": {"name": "Spectral Shield Infantry", "hp": 72, "atk": 12, "def": 14, "mag": 0, "res": 6, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 95, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Bulwark"]},
	"swordsman": {"name": "Elite Spectral Swordsman", "hp": 64, "atk": 15, "def": 7, "mag": 0, "res": 5, "spd": 7, "will": 9, "move": 5, "jump": 3, "exp": 110, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Crippling Blow"]},
	"tactician": {"name": "Tactical Instructor", "hp": 100, "atk": 12, "def": 9, "mag": 6, "res": 9, "spd": 5, "will": 14, "move": 4, "jump": 2, "exp": 220, "role": "support", "rank_cap": C,
		"skills": ["Rallying Blow", "Battle Hymn", "Rending Cut", "Stunning Blow"]},
	"corrupt": {"name": "Corrupted Soldier", "hp": 58, "atk": 15, "def": 8, "mag": 0, "res": 4, "spd": 6, "will": 6, "move": 4, "jump": 2, "exp": 85, "role": "", "rank_cap": C,
		"skills": ["Reckless Charge", "Rending Cut", "Crippling Blow"]},
	"cguardian": {"name": "Corrupted Guardian", "hp": 120, "atk": 16, "def": 13, "mag": 0, "res": 6, "spd": 3, "will": 8, "move": 3, "jump": 2, "exp": 170, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Shoulder Barge"]},
	# the general: a swordsman and tactician. He does not rely on one blow; he arranges the fight.
	"cassian": {"name": "Cassian Vale", "hp": 230, "atk": 16, "def": 11, "mag": 6, "res": 9, "spd": 7, "will": 16, "move": 5, "jump": 3, "exp": 500, "role": "support", "rank_cap": C,
		"skills": ["Cartwheel Slash", "Feinting Lunge", "Twin Strike", "Rallying Blow", "Battle Hymn", "Fortify", "Crippling Blow"]},
	"eliteswords": {"name": "Elite Honor Swordsman", "hp": 70, "atk": 15, "def": 8, "mag": 0, "res": 5, "spd": 7, "will": 9, "move": 5, "jump": 3, "exp": 120, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Crippling Blow"]},
	"academyguard": {"name": "Royal Academy Guardian", "hp": 90, "atk": 14, "def": 14, "mag": 0, "res": 7, "spd": 3, "will": 9, "move": 3, "jump": 1, "exp": 130, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Bulwark", "Shoulder Barge"]},
	"vparcher": {"name": "Veteran Phantom Archer", "hp": 48, "atk": 15, "def": 5, "mag": 0, "res": 5, "spd": 8, "will": 8, "move": 4, "jump": 3, "exp": 105, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Cleaver of Ruin", "Rending Cut", "Hooked Haul"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("expanse_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


static func setup(n: int, _rng: RandomNumberGenerator = null) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([SummonStone.make(null, STONE_D_CHANCE, STONE_C_CHANCE), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
	s.objective = "Defeat all enemies"
	s.max_summons = 6
	s.opening_line = ExpanseStory.opening(n)
	return s
