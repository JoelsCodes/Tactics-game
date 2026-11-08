class_name Bellwether
extends RefCounted
## Chapter five, "The Man Behind the Summoner": five battles around the harvest town of Bellwether (samples/bellwether_1..5.json, tools/make_bellwether_maps.py),
## all plain "defeat all enemies" (owner's brief), with the story carried by BellwetherStory. The enemies are creatures of the roadside and the old quarry, with
## rank D and C skills (chapter four's use D normally). Nothing here gives Alaric a new power, a title or another vessel.
##   1 The Roadside Ambush       a caravan road: wolves, bog slimes and opportunistic raiders
##   2 The Missing Children      the quarry's outer ledges: quarry beasts and a stronger pack leader
##   3 The Old Mine              tunnels: stone-fused miners, cave beasts and a stone guardian
##   4 The Empty Battlefield     a collapsed gallery: ONLY Alaric (weakened) and Lyra; no vessel can be summoned (BattleSetup.max_summons 0)
##   5 The Choice to Stay        the town's edge: the full party against the mine's titan and what follows it
## The Battle 4 restrictions belong to that battle's BattleSetup alone: nothing is written to the save, so they cannot outlive it.

const MAPS := ["", "res://samples/bellwether_1.json", "res://samples/bellwether_2.json", "res://samples/bellwether_3.json", "res://samples/bellwether_4.json", "res://samples/bellwether_5.json"]
const NAMES := ["", "The Roadside Ambush", "The Missing Children", "The Old Mine", "The Empty Battlefield", "The Choice to Stay"]
const TOWN := "res://samples/bellwether_town.json"  ## the festival square (scene stage)
const ENEMY_LEVEL := [0, 11, 12, 13, 13, 15]
const STONE_C_CHANCE := 0.45  ## chapter five's summon stones: rank C skills are common (owner)
const STONE_D_CHANCE := 0.35
const WEAKENED_PERCENT := 55  ## Battle 4: Alaric starts with this percent of his HP
const C := 2  ## SkillData.Rank.C
const TUNE := {1: {"hp": 0.55, "atk": -3, "mag": -2}, 2: {"hp": 0.55, "atk": -3, "mag": -2}, 3: {"hp": 0.5, "atk": -3, "mag": -2}, 4: {"hp": 0.45, "atk": -4, "mag": -3}, 5: {"hp": 0.4, "atk": -4, "mag": -3}}

const KINDS := {
	"wolf": {"name": "Gravel Wolf", "hp": 46, "atk": 11, "def": 5, "mag": 0, "res": 3, "spd": 8, "will": 6, "move": 6, "jump": 3, "exp": 50, "role": "skirmisher", "rank_cap": C,
		"skills": ["Rending Cut", "Hamstring Cut", "Crippling Blow"]},
	"alpha": {"name": "Alpha Gravel Wolf", "hp": 110, "atk": 13, "def": 7, "mag": 0, "res": 4, "spd": 9, "will": 10, "move": 6, "jump": 3, "exp": 140, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Rending Cut", "Crippling Blow", "Shoulder Barge"]},
	"slime": {"name": "Bog Slime", "hp": 52, "atk": 6, "def": 4, "mag": 9, "res": 6, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 45, "role": "support", "rank_cap": C,
		"skills": ["Tar Trap", "Slow Venom", "Lethargy"]},
	"raider": {"name": "Road Raider", "hp": 40, "atk": 11, "def": 5, "mag": 0, "res": 3, "spd": 7, "will": 6, "move": 5, "jump": 3, "exp": 50, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Dirty Sand Kick", "Cartwheel Slash", "Reckless Charge"]},
	"raider_brute": {"name": "Raider Brute", "hp": 70, "atk": 13, "def": 8, "mag": 0, "res": 3, "spd": 4, "will": 8, "move": 4, "jump": 2, "exp": 70, "role": "brute", "rank_cap": C,
		"skills": ["Stunning Blow", "Tavern Brawl", "Shoulder Barge"]},
	"scavenger": {"name": "Quarry Scavenger", "hp": 34, "atk": 9, "def": 4, "mag": 0, "res": 3, "spd": 7, "will": 6, "move": 5, "jump": 3, "exp": 45, "role": "skirmisher", "rank_cap": C,
		"skills": ["Hooked Haul", "Weaken Armor", "Quick Jab"]},
	"crawler": {"name": "Quarry Crawler", "hp": 62, "atk": 12, "def": 11, "mag": 0, "res": 5, "spd": 4, "will": 6, "move": 4, "jump": 2, "exp": 65, "role": "", "rank_cap": C,
		"skills": ["Rending Cut", "Crippling Blow", "Hamstring Cut"]},
	"eater": {"name": "Cave Eater", "hp": 58, "atk": 8, "def": 5, "mag": 9, "res": 7, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 55, "role": "support", "rank_cap": C,
		"skills": ["Mudslide", "Slow Venom", "Lethargy"]},
	# a new enemy type (owner's sheet, Nov 2026): a toothed maw on legs that spits venom and spores
	"gorgemaw": {"name": "Gorge Maw", "hp": 70, "atk": 12, "def": 6, "mag": 9, "res": 6, "spd": 3, "will": 8, "move": 3, "jump": 1, "exp": 70, "role": "brute", "rank_cap": C,
		"skills": ["Rending Cut", "Slow Venom", "Choke Spores"]},
	"cave_boar": {"name": "Cave Boar", "hp": 66, "atk": 13, "def": 7, "mag": 0, "res": 3, "spd": 6, "will": 6, "move": 5, "jump": 2, "exp": 65, "role": "brute", "rank_cap": C,
		"skills": ["Reckless Charge", "Rending Cut", "Hamstring Cut"]},
	"fused": {"name": "Stone-Fused Miner", "hp": 78, "atk": 13, "def": 10, "mag": 0, "res": 5, "spd": 4, "will": 8, "move": 4, "jump": 2, "exp": 85, "role": "", "rank_cap": C,
		"skills": ["Stunning Blow", "Crippling Blow", "Rending Cut", "Shoulder Barge"]},
	"guardian": {"name": "Stone Guardian", "hp": 150, "atk": 14, "def": 14, "mag": 0, "res": 8, "spd": 2, "will": 10, "move": 3, "jump": 2, "exp": 200, "role": "guardian", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Crippling Blow", "Stunning Blow", "Shoulder Barge"]},
	# the thing that lives under the quarry: territorial, not evil. It grabs, drags and brings the ground down.
	"titan": {"name": "The Deepdweller", "hp": 320, "atk": 16, "def": 14, "mag": 8, "res": 10, "spd": 3, "will": 14, "move": 3, "jump": 2, "exp": 450, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Hooked Haul", "Mudslide", "Gravity Well", "Crippling Blow", "Disrupt Formation"]},
}


static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return Crucible.build(KINDS[kind], StringName("bellwether_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


static func setup(n: int, _rng: RandomNumberGenerator = null) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	if n != 4:  # the empty battlefield has no summon stones: nothing can be materialised there
		for c in sp["stones"]:
			s.relics.append([SummonStone.make(null, STONE_D_CHANCE, STONE_C_CHANCE), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
	s.objective = "Defeat all enemies"
	s.max_summons = 6
	if n == 4:
		# Alaric has no strength to spare: only he and Lyra fight, and no vessel can be summoned (a limit of this battle only)
		s.max_summons = 0
		s.force_co_captain = "Lyra"
		s.rules = {"king_hp_pct": WEAKENED_PERCENT}
	s.opening_line = BellwetherStory.opening(n)
	return s
