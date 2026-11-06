class_name Finale
extends RefCounted
## Chapter nine, "The Last King": five plain defeat-all-enemies battles in the palace (samples/palace_1..5.json, tools/make_palace_maps.py), the story in FinaleStory.
## Enemy skills are rank D and C (the King alone is a boss kind and may use higher ranks); rank C summon stones are common. Nobody joins, the King included.
##   1 The Royal Hall         palace infantry, halberdiers, spellcasters, archers and a hall officer
##   2 The King's Shield      shield knights, palace guards, battle mages, halberdiers and the Shield's commander (Captain Aldren stands aside and does not fight)
##   3 The Hall of Ancestors  animated statues, ancestral armor, arcane sentinels and one great guardian construct: ward-bound constructs, NOT enslaved souls
##   4 The Crown's Last Stand champions, spellcasters, swordsmen, honor guards and the Crown's Guard commander (the hardest battle before the boss)
##   5 The Last King          the King (a powerful melee fighter who leads his honor guards), two honor guards and a guardian construct. The King is incapacitated, never killed:
##                            he yields at YIELD_PERCENT of his HP (BattleSetup.flee, flee_style "yield": he kneels and speaks, no smoke) and at SECOND_PHASE_PERCENT his
##                            resolve hardens (ScenarioRules event: a ward and haste for a few turns). No demonic power, no soul magic.
## Art: there is no sprite of the King of his own yet; the Lancer sheet stands in for him (UnitLook.ENEMY_CHARACTERS) and must be replaced.

const MAPS := ["", "res://samples/palace_1.json", "res://samples/palace_2.json", "res://samples/palace_3.json", "res://samples/palace_4.json", "res://samples/palace_5.json"]
const NAMES := ["", "The Royal Hall", "The King's Shield", "The Hall of Ancestors", "The Crown's Last Stand", "The Last King"]
const ENEMY_LEVEL := [0, 27, 28, 29, 30, 32]
const STONE_C_CHANCE := 0.5
const STONE_D_CHANCE := 0.3
const C := 2
const YIELD_PERCENT := 22
const SECOND_PHASE_PERCENT := 55
const TUNE := {1: {"hp": 0.5, "atk": -6, "mag": -4}, 2: {"hp": 0.5, "atk": -6, "mag": -4}, 3: {"hp": 0.5, "atk": -6, "mag": -4}, 4: {"hp": 0.5, "atk": -6, "mag": -4}, 5: {"hp": 0.5, "atk": -6, "mag": -4}}

const KINDS := {
	# --- 1 The Royal Hall
	"hinf": {"name": "Elite Palace Infantry", "hp": 108, "atk": 20, "def": 15, "mag": 0, "res": 8, "spd": 5, "will": 10, "move": 4, "jump": 2, "exp": 190, "role": "", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Rallying Blow", "Crippling Blow"]},
	"hhalb": {"name": "Palace Hall Halberdier", "hp": 120, "atk": 21, "def": 16, "mag": 0, "res": 8, "spd": 4, "will": 10, "move": 3, "jump": 2, "exp": 195, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Shoulder Barge", "Hooked Haul"]},
	"hspell": {"name": "Hall Spellcaster", "hp": 76, "atk": 6, "def": 9, "mag": 21, "res": 16, "spd": 6, "will": 17, "move": 4, "jump": 2, "exp": 200, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Thunderclap", "Soothing Mist", "Fortify"]},
	"harcher": {"name": "Veteran Hall Archer", "hp": 74, "atk": 22, "def": 8, "mag": 0, "res": 8, "spd": 9, "will": 11, "move": 4, "jump": 3, "exp": 180, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Hooked Haul", "Crippling Blow", "Rending Cut"]},
	"hofficer": {"name": "Royal Hall Officer", "hp": 190, "atk": 21, "def": 15, "mag": 5, "res": 11, "spd": 6, "will": 15, "move": 4, "jump": 3, "exp": 330, "role": "support", "rank_cap": C,
		"skills": ["Rallying Blow", "Battle Hymn", "Fortify", "Stunning Blow", "Cartwheel Slash"]},
	# --- 2 The King's Shield: defensive formations and support
	"sknight": {"name": "Royal Shield Knight", "hp": 132, "atk": 18, "def": 19, "mag": 0, "res": 9, "spd": 3, "will": 11, "move": 3, "jump": 1, "exp": 200, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Bulwark"]},
	"sguard": {"name": "Elite Palace Guard", "hp": 112, "atk": 21, "def": 16, "mag": 0, "res": 9, "spd": 5, "will": 11, "move": 4, "jump": 2, "exp": 200, "role": "", "rank_cap": C,
		"skills": ["Stunning Blow", "Rallying Blow", "Crippling Blow", "Shield Prod"]},
	"smage": {"name": "Royal Battle Mage", "hp": 74, "atk": 6, "def": 9, "mag": 20, "res": 16, "spd": 6, "will": 17, "move": 4, "jump": 2, "exp": 200, "role": "support", "rank_cap": C,
		"skills": ["Glacier Spike", "Chain Spark", "Soothing Mist", "Battle Hymn", "Fortify"]},
	"shalb": {"name": "Veteran Halberdier", "hp": 124, "atk": 22, "def": 16, "mag": 0, "res": 8, "spd": 4, "will": 11, "move": 3, "jump": 2, "exp": 205, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Hooked Haul", "Stunning Blow", "Shoulder Barge"]},
	"scmd": {"name": "Commander of the King's Shield", "hp": 240, "atk": 22, "def": 18, "mag": 5, "res": 12, "spd": 5, "will": 18, "move": 4, "jump": 2, "exp": 520, "role": "guardian", "rank_cap": C,
		"skills": ["Bulwark", "Battle Hymn", "Rallying Blow", "Shoulder Barge", "Stunning Blow", "Fortify"]},
	# --- 3 The Hall of Ancestors: ward-bound constructs (not souls)
	"statue": {"name": "Animated Royal Statue", "hp": 140, "atk": 20, "def": 18, "mag": 0, "res": 9, "spd": 2, "will": 8, "move": 3, "jump": 1, "exp": 190, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow"]},
	"ancarmor": {"name": "Enchanted Ancestral Armor", "hp": 108, "atk": 21, "def": 15, "mag": 6, "res": 12, "spd": 5, "will": 10, "move": 4, "jump": 2, "exp": 190, "role": "", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Crippling Blow", "Fortify"]},
	"sentinel": {"name": "Arcane Palace Sentinel", "hp": 82, "atk": 6, "def": 10, "mag": 21, "res": 17, "spd": 6, "will": 14, "move": 4, "jump": 3, "exp": 210, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Glacier Spike", "Thunderclap", "Fortify"]},
	"gconstruct": {"name": "Great Royal Guardian", "hp": 300, "atk": 24, "def": 20, "mag": 0, "res": 10, "spd": 3, "will": 12, "move": 3, "jump": 2, "exp": 520, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow", "Bulwark"]},
	# --- 4 The Crown's Last Stand
	"champion": {"name": "Royal Champion Knight", "hp": 150, "atk": 24, "def": 18, "mag": 0, "res": 10, "spd": 6, "will": 13, "move": 4, "jump": 3, "exp": 260, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Twin Strike", "Rallying Blow", "Crippling Blow", "Reckless Charge"]},
	"cspell": {"name": "Elite Palace Spellcaster", "hp": 84, "atk": 6, "def": 10, "mag": 23, "res": 18, "spd": 7, "will": 18, "move": 4, "jump": 2, "exp": 250, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Thunderclap", "Glacier Spike", "Soothing Mist"]},
	"cswords": {"name": "Veteran Royal Swordsman", "hp": 106, "atk": 24, "def": 12, "mag": 0, "res": 9, "spd": 9, "will": 12, "move": 5, "jump": 3, "exp": 230, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Crippling Blow"]},
	"honor": {"name": "Royal Honor Guard", "hp": 126, "atk": 23, "def": 17, "mag": 0, "res": 10, "spd": 5, "will": 14, "move": 4, "jump": 2, "exp": 240, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Rallying Blow", "Stunning Blow", "Bulwark"]},
	"ccmd": {"name": "Commander of the Crown's Guard", "hp": 280, "atk": 25, "def": 19, "mag": 6, "res": 13, "spd": 6, "will": 19, "move": 4, "jump": 3, "exp": 600, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Stunning Blow", "Fortify", "Crippling Blow"]},
	# --- 5 The Last King: a legendary warrior grown tired. Heavy sword, sweeping strikes, a counter-minded guard and leadership that lifts his honor guards. No soul magic, nothing demonic.
	"king": {"name": "The Last King", "hp": 560, "atk": 28, "def": 20, "mag": 8, "res": 14, "spd": 6, "will": 20, "move": 4, "jump": 3, "exp": 1200, "role": "support", "boss": true,
		"skills": ["Executioner's Cut", "Whirlwind", "Last Stand", "Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Bulwark", "Fortify"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("palace_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


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
	if n == 5:  # the King is beaten, never killed: he yields, kneeling, at YIELD_PERCENT; the battle is won when he and his guards are down
		s.objective = "Defeat the King and all remaining enemies"
		s.flee = {KINDS.king.name: YIELD_PERCENT}
		s.flee_style = "yield"
		s.flee_line = FinaleStory.king_yield()
		s.rules = {"event": {"unit": KINDS.king.name, "below": SECOND_PHASE_PERCENT, "fx": "none", "status": {"ward": 3, "haste": 3},
			"banner": "The King sets his feet. His resolve hardens.", "line": FinaleStory.king_resolve()}}
	s.max_summons = 6
	s.opening_line = FinaleStory.opening(n)
	return s
