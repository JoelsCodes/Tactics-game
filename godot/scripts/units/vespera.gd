class_name Vespera
extends RefCounted
## Chapter seven, "The City of Silent Bells": five plain defeat-all-enemies battles in Vespera (samples/vespera_1..5.json, tools/make_late_maps.py) with the story in
## VesperaStory, and Seraphine, the Last Bell Keeper, who joins as an ordinary vessel at the end (`recruit`). Malrec is an independent villain, not tied to the King's
## story. Enemy skills are rank D and C; the summon stones carry rank C commonly.
##   1 The Streets Without Sound   wandering spirits, hollow lanterns, possessed ceremonial armor, a gravebound sentinel
##   2 The Forgotten Cemetery      gravebound knights, gargoyles, mourners, a cemetery guardian
##   3 The Catacombs Below         crystal-infused undead, spectral guardians, resonance constructs, a catacomb sentinel
##   4 The Choir of the Lost       captured spectral warriors, resonance constructs, crystal guardians, choir sentinels
##   5 The Last Toll               Malrec and his bell constructs, crystal spirits and bell sentinels

const MAPS := ["", "res://samples/vespera_1.json", "res://samples/vespera_2.json", "res://samples/vespera_3.json", "res://samples/vespera_4.json", "res://samples/vespera_5.json"]
const NAMES := ["", "The Streets Without Sound", "The Forgotten Cemetery", "The Catacombs Below", "The Choir of the Lost", "The Last Toll"]
const ENEMY_LEVEL := [0, 18, 19, 19, 20, 21]
const STONE_B_CHANCE := 0.15  ## rank B stones begin here (chapter seven)
const STONE_C_CHANCE := 0.40
const STONE_D_CHANCE := 0.30
const C := 2
const TUNE := {1: {"hp": 0.5, "atk": -4, "mag": -3}, 2: {"hp": 0.5, "atk": -4, "mag": -3}, 3: {"hp": 0.5, "atk": -4, "mag": -3}, 4: {"hp": 0.5, "atk": -4, "mag": -3}, 5: {"hp": 0.42, "atk": -5, "mag": -4}}

const KINDS := {
	"wander": {"name": "Wandering Spirit", "hp": 44, "atk": 6, "def": 5, "mag": 13, "res": 9, "spd": 7, "will": 12, "move": 5, "jump": 3, "exp": 80, "role": "caster", "rank_cap": C,
		"skills": ["Void Pun", "Lullaby", "Soul Rend"]},
	"lantern": {"name": "Hollow Lantern", "hp": 52, "atk": 5, "def": 6, "mag": 12, "res": 10, "spd": 5, "will": 12, "move": 4, "jump": 2, "exp": 85, "role": "support", "rank_cap": C,
		"skills": ["Blinding Flash", "Dim Light", "Mass Blind"]},
	"ceremonial": {"name": "Possessed Ceremonial Armor", "hp": 78, "atk": 15, "def": 13, "mag": 0, "res": 6, "spd": 3, "will": 8, "move": 3, "jump": 2, "exp": 100, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Stunning Blow", "Crippling Blow"]},
	"gsentinel": {"name": "Gravebound Sentinel", "hp": 150, "atk": 16, "def": 14, "mag": 0, "res": 8, "spd": 3, "will": 10, "move": 3, "jump": 2, "exp": 240, "role": "guardian", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Crippling Blow", "Shoulder Barge"]},
	"gknight": {"name": "Gravebound Knight", "hp": 82, "atk": 16, "def": 12, "mag": 0, "res": 6, "spd": 5, "will": 9, "move": 4, "jump": 2, "exp": 115, "role": "brute", "rank_cap": C,
		"skills": ["Rallying Blow", "Stunning Blow", "Crippling Blow"]},
	"gargoyle": {"name": "Stone Gargoyle", "hp": 70, "atk": 15, "def": 12, "mag": 0, "res": 5, "spd": 8, "will": 8, "move": 6, "jump": 5, "exp": 110, "role": "skirmisher", "rank_cap": C,
		"skills": ["Hooked Haul", "Rending Cut", "Reckless Charge"]},
	"mourner": {"name": "Spectral Mourner", "hp": 46, "atk": 5, "def": 5, "mag": 14, "res": 10, "spd": 6, "will": 14, "move": 4, "jump": 2, "exp": 90, "role": "support", "rank_cap": C,
		"skills": ["Lullaby", "Soothing Mist", "Hex of Waning"]},
	"cguard": {"name": "Cemetery Guardian", "hp": 160, "atk": 17, "def": 14, "mag": 0, "res": 8, "spd": 3, "will": 10, "move": 3, "jump": 2, "exp": 250, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Crippling Blow", "Stunning Blow", "Shoulder Barge"]},
	"cundead": {"name": "Crystal-Infused Undead", "hp": 76, "atk": 15, "def": 11, "mag": 0, "res": 6, "spd": 4, "will": 8, "move": 4, "jump": 2, "exp": 105, "role": "brute", "rank_cap": C,
		"skills": ["Rending Cut", "Crippling Blow", "Stunning Blow"]},
	"sguard": {"name": "Spectral Guardian", "hp": 64, "atk": 13, "def": 8, "mag": 8, "res": 9, "spd": 6, "will": 10, "move": 4, "jump": 3, "exp": 100, "role": "", "rank_cap": C,
		"skills": ["Void Lance", "Rallying Blow", "Drain Spirit"]},
	# a new enemy type (owner's sheet, Nov 2026): a skull-faced spider of the catacombs
	"skullspider": {"name": "Skull Spider", "hp": 60, "atk": 14, "def": 7, "mag": 8, "res": 8, "spd": 7, "will": 10, "move": 4, "jump": 4, "exp": 105, "role": "skirmisher", "rank_cap": C,
		"skills": ["Slow Venom", "Hooked Haul", "Umbra Bite"]},
	"rconstruct": {"name": "Resonance Construct", "hp": 80, "atk": 14, "def": 13, "mag": 6, "res": 8, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 105, "role": "guardian", "rank_cap": C,
		"skills": ["Shoulder Barge", "Ether Drain", "Crippling Blow"]},
	"catsentinel": {"name": "Catacomb Sentinel", "hp": 165, "atk": 17, "def": 15, "mag": 0, "res": 9, "spd": 3, "will": 10, "move": 3, "jump": 2, "exp": 260, "role": "guardian", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Stunning Blow", "Crippling Blow", "Gravity Well"]},
	"captured": {"name": "Captured Spectral Warrior", "hp": 68, "atk": 15, "def": 9, "mag": 0, "res": 6, "spd": 6, "will": 8, "move": 4, "jump": 3, "exp": 105, "role": "", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Crippling Blow"]},
	"crystalguard": {"name": "Crystal Guardian", "hp": 120, "atk": 15, "def": 14, "mag": 4, "res": 9, "spd": 3, "will": 9, "move": 3, "jump": 2, "exp": 160, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Cleaver of Ruin", "Bulwark"]},
	"choirsentinel": {"name": "Choir Sentinel", "hp": 92, "atk": 14, "def": 10, "mag": 10, "res": 11, "spd": 5, "will": 12, "move": 4, "jump": 2, "exp": 150, "role": "support", "rank_cap": C,
		"skills": ["Battle Hymn", "Soul Rend", "Lullaby", "Stunning Blow"]},
	# the choirmaster: spirit magic, area attacks, and equipment that lifts the creatures near him
	"malrec": {"name": "Malrec", "hp": 210, "atk": 8, "def": 9, "mag": 17, "res": 13, "spd": 6, "will": 18, "move": 4, "jump": 3, "exp": 520, "role": "support", "rank_cap": C,
		"skills": ["Soul Rend", "Black Hole Pinch", "Drain Spirit", "Battle Hymn", "Hex of Waning", "Void Lance"]},
	"bellconstruct": {"name": "Bell Construct", "hp": 90, "atk": 15, "def": 14, "mag": 6, "res": 9, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 120, "role": "guardian", "rank_cap": C,
		"skills": ["Shoulder Barge", "Stunning Blow", "Ether Drain"]},
	"crystalspirit": {"name": "Crystal-Infused Spirit", "hp": 58, "atk": 6, "def": 6, "mag": 15, "res": 11, "spd": 6, "will": 13, "move": 4, "jump": 3, "exp": 110, "role": "caster", "rank_cap": C,
		"skills": ["Void Lance", "Soul Rend", "Lullaby"]},
	"bellsentinel": {"name": "Bell Sentinel", "hp": 110, "atk": 16, "def": 13, "mag": 0, "res": 8, "spd": 4, "will": 10, "move": 4, "jump": 2, "exp": 150, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Crippling Blow", "Rallying Blow"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("vespera_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


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
	s.opening_line = VesperaStory.opening(n)
	return s


## Seraphine, the Last Bell Keeper: a support vessel (a hymn that lifts the company, a lullaby that dulls the foe). A normal vessel in every rule: she needs Alaric's
## energy and range, has a Fade Clock like the others, and no independent existence.
static func seraphine() -> VesselData:
	return Crucible._vessel("Seraphine", &"seraphine", {"hp": 54, "atk": 3, "def": 4, "mag": 14, "res": 11, "spd": 6, "will": 15, "move": 4, "jump": 2}, "Bell-Keeper's Staff",
		[["Resonant Handbell", "Battle Hymn"], ["Chime Pendant", "Lullaby"]])


## She joins for good (the existing vessel roster: no new interface). Safe to call twice.
static func recruit(g: SaveGame) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	if not owned.any(func(o): return o.display_name == "Seraphine"):
		owned.append(Crucible.join_at_level(seraphine(), g))
	return g
