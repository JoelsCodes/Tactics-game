class_name Crown
extends RefCounted
## Chapter eight, "The Road to the Crown": five plain defeat-all-enemies battles on the way to the throne room (samples/crown_1..5.json, tools/make_crown_maps.py), the story
## in CrownStory. The royal soldiers are honorable defenders following the King's order to take Alaric ALIVE: the scenes show them disarmed, hurt or retreating, never
## slaughtered. Enemy skills are rank D and C; rank C stones are common. Nothing here recruits anyone, and the chapter stops at the throne room's doors (chapter nine,
## "The Last King", is not built).
##   1 The King's Highway    royal patrol: infantry, archers, mounted guards, an elite patrol commander
##   2 The Outer Defenses    a moat and a curtain wall: shield infantry, crossbowmen, halberdiers, a defensive mage, a gate officer
##   3 The Captain's Oath    Captain Aldren (leadership: he lifts nearby allies) and his veterans
##   4 The City of Crowns    elite infantry, battle mages, heavy guards, veteran crossbowmen, a royal knight
##   5 The Palace Gates      the palace guard: elite knights, halberdiers, spellcasters, archers and their veteran commander

const MAPS := ["", "res://samples/crown_1.json", "res://samples/crown_2.json", "res://samples/crown_3.json", "res://samples/crown_4.json", "res://samples/crown_5.json"]
const NAMES := ["", "The King's Highway", "The Outer Defenses", "The Captain's Oath", "The City of Crowns", "The Palace Gates"]
const ENEMY_LEVEL := [0, 22, 23, 24, 25, 26]
const STONE_B_CHANCE := 0.20
const STONE_C_CHANCE := 0.40
const STONE_D_CHANCE := 0.25
const C := 2
const TUNE := {1: {"hp": 0.5, "atk": -5, "mag": -3}, 2: {"hp": 0.5, "atk": -5, "mag": -3}, 3: {"hp": 0.45, "atk": -5, "mag": -4}, 4: {"hp": 0.5, "atk": -5, "mag": -3}, 5: {"hp": 0.5, "atk": -5, "mag": -3}}

const KINDS := {
	"infantry": {"name": "Royal Infantry", "hp": 80, "atk": 17, "def": 12, "mag": 0, "res": 6, "spd": 5, "will": 9, "move": 4, "jump": 2, "exp": 130, "role": "", "rank_cap": C,
		"skills": ["Shield Prod", "Rallying Blow", "Crippling Blow"]},
	"rarcher": {"name": "Royal Archer", "hp": 58, "atk": 17, "def": 6, "mag": 0, "res": 6, "spd": 8, "will": 9, "move": 4, "jump": 3, "exp": 125, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Rending Cut", "Hooked Haul"]},
	"mounted": {"name": "Mounted Royal Guard", "hp": 92, "atk": 18, "def": 11, "mag": 0, "res": 6, "spd": 9, "will": 9, "move": 6, "jump": 3, "exp": 150, "role": "skirmisher", "rank_cap": C,
		"skills": ["Reckless Charge", "Twin Strike", "Cartwheel Slash"]},
	"patrolcmd": {"name": "Elite Patrol Commander", "hp": 150, "atk": 18, "def": 13, "mag": 4, "res": 9, "spd": 6, "will": 14, "move": 4, "jump": 2, "exp": 280, "role": "support", "rank_cap": C,
		"skills": ["Rallying Blow", "Battle Hymn", "Stunning Blow", "Crippling Blow"]},
	"shield": {"name": "Royal Shield Infantry", "hp": 96, "atk": 15, "def": 16, "mag": 0, "res": 7, "spd": 4, "will": 9, "move": 3, "jump": 1, "exp": 140, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Bulwark"]},
	"crossbow": {"name": "Royal Crossbowman", "hp": 60, "atk": 18, "def": 7, "mag": 0, "res": 6, "spd": 7, "will": 9, "move": 4, "jump": 3, "exp": 130, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Crippling Blow", "Rending Cut"]},
	"halberd": {"name": "Armored Halberdier", "hp": 104, "atk": 19, "def": 14, "mag": 0, "res": 6, "spd": 4, "will": 9, "move": 3, "jump": 2, "exp": 150, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Hooked Haul"]},
	"bmage": {"name": "Defensive Battle Mage", "hp": 62, "atk": 6, "def": 7, "mag": 17, "res": 13, "spd": 6, "will": 15, "move": 4, "jump": 2, "exp": 150, "role": "caster", "rank_cap": C,
		"skills": ["Fireball", "Chain Spark", "Glacier Spike", "Fortify"]},
	"gateofficer": {"name": "Elite Gate Officer", "hp": 170, "atk": 19, "def": 14, "mag": 5, "res": 10, "spd": 6, "will": 14, "move": 4, "jump": 2, "exp": 300, "role": "support", "rank_cap": C,
		"skills": ["Rallying Blow", "Battle Hymn", "Cartwheel Slash", "Crippling Blow", "Fortify"]},
	# the captain who serves the King and the city: his presence strengthens the line
	"aldren": {"name": "Captain Aldren", "hp": 210, "atk": 19, "def": 14, "mag": 6, "res": 11, "spd": 6, "will": 17, "move": 4, "jump": 3, "exp": 450, "role": "support", "rank_cap": C,
		"skills": ["Battle Hymn", "Rallying Blow", "Fortify", "Cartwheel Slash", "Stunning Blow", "Bulwark"]},
	"swords": {"name": "Veteran Royal Swordsman", "hp": 90, "atk": 19, "def": 10, "mag": 0, "res": 7, "spd": 8, "will": 10, "move": 5, "jump": 3, "exp": 150, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Crippling Blow"]},
	"support": {"name": "Royal Support Mage", "hp": 64, "atk": 5, "def": 7, "mag": 16, "res": 14, "spd": 6, "will": 16, "move": 4, "jump": 2, "exp": 150, "role": "support", "rank_cap": C,
		"skills": ["Soothing Mist", "Battle Hymn", "Lullaby", "Purify"]},
	"eliteinf": {"name": "Elite Royal Infantry", "hp": 104, "atk": 19, "def": 14, "mag": 0, "res": 8, "spd": 5, "will": 10, "move": 4, "jump": 2, "exp": 170, "role": "", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Rallying Blow", "Crippling Blow"]},
	"cmage": {"name": "Royal Battle Mage", "hp": 70, "atk": 6, "def": 8, "mag": 19, "res": 14, "spd": 6, "will": 16, "move": 4, "jump": 2, "exp": 180, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Glacier Spike", "Thunderclap", "Fortify"]},
	"heavy": {"name": "Heavy Armored Guard", "hp": 130, "atk": 18, "def": 18, "mag": 0, "res": 8, "spd": 3, "will": 10, "move": 3, "jump": 1, "exp": 190, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Cleaver of Ruin", "Shoulder Barge", "Bulwark"]},
	"vcross": {"name": "Veteran Crossbowman", "hp": 68, "atk": 20, "def": 8, "mag": 0, "res": 7, "spd": 8, "will": 10, "move": 4, "jump": 3, "exp": 160, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Crippling Blow", "Cleaver of Ruin"]},
	"rknight": {"name": "Royal Knight", "hp": 200, "atk": 21, "def": 16, "mag": 4, "res": 11, "spd": 6, "will": 14, "move": 4, "jump": 3, "exp": 380, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Rallying Blow", "Crippling Blow", "Reckless Charge"]},
	"pknight": {"name": "Elite Royal Knight", "hp": 128, "atk": 21, "def": 15, "mag": 0, "res": 9, "spd": 7, "will": 12, "move": 4, "jump": 3, "exp": 210, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Twin Strike", "Rallying Blow", "Crippling Blow"]},
	"phalberd": {"name": "Palace Halberdier", "hp": 116, "atk": 20, "def": 16, "mag": 0, "res": 8, "spd": 4, "will": 10, "move": 3, "jump": 2, "exp": 180, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Shoulder Barge", "Hooked Haul"]},
	"spell": {"name": "Royal Spellcaster", "hp": 74, "atk": 6, "def": 9, "mag": 20, "res": 15, "spd": 6, "will": 17, "move": 4, "jump": 2, "exp": 190, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Thunderclap", "Soothing Mist", "Fortify"]},
	"parcher": {"name": "Veteran Royal Archer", "hp": 72, "atk": 21, "def": 8, "mag": 0, "res": 8, "spd": 9, "will": 11, "move": 4, "jump": 3, "exp": 170, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Hooked Haul", "Crippling Blow", "Rending Cut"]},
	# the commander who has served the royal family for decades: his stand is a personal one, not an order to kill
	"pcmd": {"name": "Palace Guard Commander", "hp": 240, "atk": 22, "def": 17, "mag": 6, "res": 12, "spd": 6, "will": 18, "move": 4, "jump": 3, "exp": 520, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Stunning Blow", "Rallying Blow", "Fortify", "Crippling Blow"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("crown_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


static func setup(n: int, _rng: RandomNumberGenerator = null) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([SummonStone.make(null, STONE_D_CHANCE, STONE_C_CHANCE, STONE_B_CHANCE), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
	s.objective = "Defeat all enemies"
	s.max_summons = 6
	s.opening_line = CrownStory.opening(n)
	return s
