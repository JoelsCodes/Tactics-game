class_name Falcon
extends RefCounted
## Chapter eleven, "The Dead King's Army": five plain defeat-all-enemies battles against the Falcon Guard (samples/falcon_1..5.json, tools/make_falcon_maps.py), the story in FalconStory.
## Enemy skills are rank D and C (Commander Vaelor alone is a boss kind and may use higher ranks); rank C stones are common. Nobody joins.
##   1 The Ashes Return        Falcon Guard swordsmen, archers, shield soldiers and an elite officer, drawn up in the lane at Greyhaven
##   2 The Broken Farmlands    Falcon Guard spearmen and archers, armored field constructs, wild creatures and an elite captain
##   3 The Last Falcon         Commander Vaelor (an elite miniboss who lifts those near him) with honor guards, archers and shield soldiers
##   4 The Army Without Graves heavy infantry, cavalry, battle mages, archers and a standard bearer
##   5 The Dead King's Army    Vaelor again, with improved abilities, heavy infantry, archers, cavalry, a battle mage and honor guards
## Vaelor is not killed in either battle: like the King he yields at YIELD_PERCENT of his HP (BattleSetup.flee, flee_style "yield"): his materialized form fades and the story scene
## carries on. The Falcon Guard are free-willed vessels, never mindless: they speak, refuse and answer for what they did. Nothing here says who summoned them.
## Art: there is no Falcon Guard sheet; royal stand-ins are used (UnitLook) and the Falcon Guard get a faint pale-blue spectral tint (UnitLook.FALCON_TINT) so they never read as the living soldiers of chapter eight.

const MAPS := ["", "res://samples/falcon_1.json", "res://samples/falcon_2.json", "res://samples/falcon_3.json", "res://samples/falcon_4.json", "res://samples/falcon_5.json"]
const NAMES := ["", "The Ashes Return", "The Broken Farmlands", "The Last Falcon", "The Army Without Graves", "The Dead King's Army"]
const ENEMY_LEVEL := [0, 39, 40, 41, 42, 44]
const STONE_S_CHANCE := 0.06  ## from chapter eleven every rank E to S is in rotation
const STONE_A_CHANCE := 0.16
const STONE_B_CHANCE := 0.24
const STONE_C_CHANCE := 0.22
const STONE_D_CHANCE := 0.16
const C := 2
const YIELD_PERCENT := 25
const TUNE := {1: {"hp": 0.5, "atk": -7, "mag": -5}, 2: {"hp": 0.5, "atk": -7, "mag": -5}, 3: {"hp": 0.5, "atk": -7, "mag": -5}, 4: {"hp": 0.5, "atk": -7, "mag": -5}, 5: {"hp": 0.5, "atk": -7, "mag": -5}}

const KINDS := {
	"fsword": {"name": "Falcon Guard Swordsman", "hp": 134, "atk": 28, "def": 16, "mag": 0, "res": 11, "spd": 8, "will": 14, "move": 5, "jump": 3, "exp": 280, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Feinting Lunge", "Crippling Blow"]},
	"fspear": {"name": "Falcon Guard Spearman", "hp": 130, "atk": 28, "def": 16, "mag": 0, "res": 11, "spd": 7, "will": 14, "move": 4, "jump": 3, "exp": 280, "role": "brute", "rank_cap": C,
		"skills": ["Hooked Haul", "Cleaver of Ruin", "Pin Down", "Stunning Blow"]},
	"farcher": {"name": "Falcon Guard Archer", "hp": 92, "atk": 28, "def": 11, "mag": 0, "res": 11, "spd": 9, "will": 14, "move": 4, "jump": 3, "exp": 270, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Hooked Haul", "Crippling Blow", "Rending Cut"]},
	"fshield": {"name": "Falcon Guard Shield Soldier", "hp": 156, "atk": 24, "def": 22, "mag": 0, "res": 12, "spd": 4, "will": 14, "move": 3, "jump": 2, "exp": 285, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Fortify", "Bulwark"]},
	"fheavy": {"name": "Falcon Guard Heavy Infantry", "hp": 176, "atk": 29, "def": 23, "mag": 0, "res": 11, "spd": 3, "will": 14, "move": 3, "jump": 1, "exp": 310, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow", "Bulwark"]},
	"fcav": {"name": "Falcon Guard Cavalry", "hp": 150, "atk": 29, "def": 17, "mag": 0, "res": 11, "spd": 10, "will": 14, "move": 6, "jump": 3, "exp": 310, "role": "skirmisher", "rank_cap": C,
		"skills": ["Reckless Charge", "Twin Strike", "Cartwheel Slash", "Crippling Blow"]},
	"fmage": {"name": "Falcon Guard Battle Mage", "hp": 96, "atk": 6, "def": 11, "mag": 26, "res": 20, "spd": 6, "will": 19, "move": 4, "jump": 2, "exp": 300, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Thunderclap", "Glacier Spike", "Soothing Mist"]},
	"fhonor": {"name": "Falcon Guard Honor Guard", "hp": 164, "atk": 29, "def": 21, "mag": 0, "res": 12, "spd": 6, "will": 16, "move": 4, "jump": 2, "exp": 320, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Rallying Blow", "Stunning Blow", "Bulwark", "Crippling Blow"]},
	"fstd": {"name": "Falcon Guard Standard Bearer", "hp": 184, "atk": 24, "def": 19, "mag": 8, "res": 15, "spd": 5, "will": 20, "move": 4, "jump": 2, "exp": 540, "role": "support", "rank_cap": C,
		"skills": ["Battle Hymn", "Rallying Blow", "Fortify", "Bulwark", "Rally Cry"]},
	"fofficer": {"name": "Falcon Guard Officer", "hp": 270, "atk": 27, "def": 19, "mag": 6, "res": 13, "spd": 6, "will": 20, "move": 4, "jump": 3, "exp": 640, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Stunning Blow", "Fortify", "Crippling Blow"]},
	"fcapt": {"name": "Falcon Guard Captain", "hp": 290, "atk": 29, "def": 20, "mag": 6, "res": 14, "spd": 6, "will": 20, "move": 4, "jump": 3, "exp": 700, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Twin Strike", "Fortify", "Crippling Blow"]},
	# the farmlands' other dangers: constructs left in the fields and creatures disturbed by the fighting (they serve nobody)
	"fcons": {"name": "Armored Field Construct", "hp": 170, "atk": 27, "def": 21, "mag": 0, "res": 9, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 270, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Crippling Blow"]},
	"tboar": {"name": "Territorial Boar", "hp": 150, "atk": 29, "def": 15, "mag": 0, "res": 7, "spd": 7, "will": 7, "move": 5, "jump": 2, "exp": 250, "role": "brute", "rank_cap": C,
		"skills": ["Reckless Charge", "Shoulder Barge", "Rending Cut"]},
	# a new enemy type (owner's sheet, Nov 2026): a prismatic mantis of the wilds
	"prismmantis": {"name": "Prism Mantis", "hp": 96, "atk": 27, "def": 10, "mag": 4, "res": 9, "spd": 12, "will": 8, "move": 5, "jump": 4, "exp": 240, "role": "skirmisher", "rank_cap": C,
		"skills": ["Rending Cut", "Cutting Wind", "Rift Slash"]},
	"twolf": {"name": "Disturbed Wolf", "hp": 104, "atk": 28, "def": 11, "mag": 0, "res": 7, "spd": 11, "will": 7, "move": 6, "jump": 3, "exp": 240, "role": "skirmisher", "rank_cap": C,
		"skills": ["Rending Cut", "Reckless Charge", "Hamstring Cut"]},
	# Commander Vaelor, the Last Falcon: proud, disciplined, loyal to the royal bloodline; he lifts the soldiers near him. Battle 3 uses "vaelor"; Battle 5 "vaelor2" is stronger and
	# knows the techniques of a field commander (Phalanx, Whirlwind). Neither is the villain of the whole piece and neither is a mindless puppet.
	"vaelor": {"name": "Commander Vaelor", "hp": 380, "atk": 31, "def": 22, "mag": 8, "res": 15, "spd": 7, "will": 22, "move": 4, "jump": 3, "exp": 1300, "role": "support", "boss": true,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Bulwark", "Fortify", "Cartwheel Slash", "Stunning Blow"]},
	"vaelor2": {"name": "Commander Vaelor", "hp": 520, "atk": 34, "def": 24, "mag": 10, "res": 17, "spd": 8, "will": 24, "move": 4, "jump": 3, "exp": 1800, "role": "support", "boss": true,
		"skills": ["Whirlwind", "Phalanx", "Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Bulwark", "Executioner's Cut", "Fortify"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("falcon_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


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
	if n == 3 or n == 5:  # Vaelor yields (his form fades), he is never destroyed: he returns in Battle 5 and survives it
		s.objective = "Defeat all enemies, including Vaelor"
		s.flee = {"Commander Vaelor": YIELD_PERCENT}
		s.flee_style = "yield"
		s.flee_line = FalconStory.vaelor_fades(n)
	s.max_summons = 6
	s.opening_line = FalconStory.opening(n)
	return s
