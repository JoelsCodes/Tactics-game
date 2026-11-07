class_name FinalArc
extends RefCounted
## The final arc, chapters twelve to fifteen ("The Woman Who Returned", "A Kingdom Divided", "The Lovers' War", "Hollowmark"): twenty defeat-all-enemies battles
## (samples/arc12_1 .. arc15_5.json, tools/make_final_maps.py), the story in FinalStory. Enemy skill ranks follow the player's stones (Crucible._add_chapter_ranks;
## bosses one rank up). The Falcon Guard reuse chapter eleven's kinds (Falcon.KINDS) with new elite ones; the revolutionaries are a third faction with their own tint.
## Bosses never die: Vaelor yields (12-5) and withdraws for good (15-2); Reave and Elowen are fought together in 15-5 and both yield (incapacitated) for the ending.
## Elowen calls a few elite Falcon Guard vessels while she stands (ScenarioRules boss_summon, capped: her energy and range are limited like Alaric's).
## Cassian Vale joins as a vessel in chapter fourteen (FinalArc.recruit_cassian, story step give_cassian).
## Art: Reave, Elowen, Vaelor, Cassian and the revolutionaries have no sheets of their own; stand-ins are named in UnitLook and godot/HANDOFF.md.

const CH := {12: ["The Silvermere Road", "The Forgotten Gardens", "The Royal Training Grounds", "The Hidden Chambers", "The Princess's Guardian"],
	13: ["The Princess's Guard", "The Divided Streets", "The Revolutionary Vanguard", "The Burning Standard", "The First Uprising"],
	14: ["The Shattered Crossing", "The Chapel's Last Guard", "The General's Return", "The Fallen Banner", "The March to Hollowmark"],
	15: ["The Hollowmark Approach", "The Army of Yesterday", "The Revolutionary Heart", "The Princess's Last Army", "The Last Summoners"]}
const LEVEL := {12: 46, 13: 50, 14: 54, 15: 58}
const YIELD_PERCENT := 25
const C := 2
const B := 3
const TUNE := {"hp": 0.5, "atk": -8, "mag": -6}
## Stones: everything in rotation from chapter eleven on (owner), the same chances as chapter eleven.
const STONE := [0.16, 0.22, 0.24, 0.16, 0.06]  # D, C, B, A, S

const KINDS := {
	# --- the revolutionaries: living fighters of Reave's movement. Not every revolutionary is a villain: these are the armed ones threatening people.
	"rsword": {"name": "Revolutionary Swordsman", "hp": 150, "atk": 30, "def": 18, "mag": 0, "res": 12, "spd": 8, "will": 14, "move": 5, "jump": 3, "exp": 320, "role": "skirmisher", "rank_cap": C,
		"skills": ["Twin Strike", "Cartwheel Slash", "Crippling Blow"]},
	"rarcher": {"name": "Revolutionary Archer", "hp": 110, "atk": 30, "def": 12, "mag": 0, "res": 12, "spd": 9, "will": 14, "move": 4, "jump": 3, "exp": 310, "role": "skirmisher", "rank_cap": C,
		"skills": ["Pin Down", "Hooked Haul", "Rending Cut"]},
	"rduel": {"name": "Revolutionary Duelist", "hp": 130, "atk": 32, "def": 14, "mag": 0, "res": 12, "spd": 11, "will": 14, "move": 5, "jump": 4, "exp": 340, "role": "skirmisher", "rank_cap": C,
		"skills": ["Feinting Lunge", "Twin Strike", "Step-Aside Strike", "Crippling Blow"]},
	"rmage": {"name": "Revolutionary Battle Mage", "hp": 110, "atk": 6, "def": 12, "mag": 30, "res": 22, "spd": 7, "will": 20, "move": 4, "jump": 2, "exp": 340, "role": "caster", "rank_cap": C,
		"skills": ["Flame Wave", "Cutting Wind", "Scorch"]},
	"rspell": {"name": "Revolutionary Spellcaster", "hp": 112, "atk": 6, "def": 12, "mag": 31, "res": 23, "spd": 7, "will": 20, "move": 4, "jump": 2, "exp": 345, "role": "caster", "rank_cap": C,
		"skills": ["Thunderclap", "Glacier Spike", "Soothing Mist"]},
	"rheavy": {"name": "Revolutionary Heavy Infantry", "hp": 190, "atk": 31, "def": 24, "mag": 0, "res": 12, "spd": 4, "will": 14, "move": 3, "jump": 2, "exp": 350, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Bulwark"]},
	"rchamp": {"name": "Revolutionary Champion", "hp": 210, "atk": 34, "def": 22, "mag": 6, "res": 15, "spd": 7, "will": 18, "move": 4, "jump": 3, "exp": 420, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Reckless Charge", "Rallying Blow", "Stunning Blow"]},
	"rext": {"name": "Revolutionary Extremist", "hp": 130, "atk": 31, "def": 14, "mag": 0, "res": 10, "spd": 8, "will": 12, "move": 5, "jump": 3, "exp": 300, "role": "brute", "rank_cap": C,
		"skills": ["Reckless Charge", "Tavern Brawl", "Rending Cut"]},
	"rraid": {"name": "Revolutionary Armored Raider", "hp": 170, "atk": 31, "def": 21, "mag": 0, "res": 11, "spd": 6, "will": 12, "move": 4, "jump": 2, "exp": 320, "role": "brute", "rank_cap": C,
		"skills": ["Shoulder Barge", "Cleaver of Ruin", "Stunning Blow"]},
	"rcapt": {"name": "Revolutionary Captain", "hp": 300, "atk": 33, "def": 22, "mag": 8, "res": 16, "spd": 7, "will": 22, "move": 4, "jump": 3, "exp": 760, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Crippling Blow", "Fortify"]},
	"rvan": {"name": "Revolutionary Vanguard Commander", "hp": 320, "atk": 34, "def": 22, "mag": 8, "res": 16, "spd": 8, "will": 22, "move": 5, "jump": 3, "exp": 800, "role": "support", "rank_cap": C,
		"skills": ["Feinting Lunge", "Battle Hymn", "Cartwheel Slash", "Rallying Blow", "Fortify"]},
	"rsab": {"name": "Revolutionary Saboteur Commander", "hp": 290, "atk": 33, "def": 20, "mag": 10, "res": 16, "spd": 9, "will": 20, "move": 5, "jump": 4, "exp": 760, "role": "support", "rank_cap": C,
		"skills": ["Dirty Sand Kick", "Hooked Haul", "Battle Hymn", "Crippling Blow", "Fortify"]},
	"rcmd": {"name": "Revolutionary Commander", "hp": 340, "atk": 35, "def": 23, "mag": 10, "res": 17, "spd": 7, "will": 24, "move": 4, "jump": 3, "exp": 880, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Bulwark", "Stunning Blow", "Fortify"]},
	"rofficer": {"name": "Revolutionary Fortress Commander", "hp": 330, "atk": 34, "def": 23, "mag": 10, "res": 17, "spd": 7, "will": 24, "move": 4, "jump": 3, "exp": 860, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Fortify", "Bulwark", "Crippling Blow"]},
	# --- more Falcon Guard (the rest are Falcon.KINDS)
	"felite": {"name": "Falcon Guard Elite Honor Guard", "hp": 200, "atk": 33, "def": 24, "mag": 0, "res": 14, "spd": 6, "will": 18, "move": 4, "jump": 2, "exp": 380, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Rallying Blow", "Stunning Blow", "Bulwark", "Crippling Blow"]},
	"fcmd": {"name": "Falcon Guard Commander", "hp": 340, "atk": 34, "def": 24, "mag": 8, "res": 17, "spd": 7, "will": 24, "move": 4, "jump": 3, "exp": 880, "role": "support", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Bulwark", "Fortify", "Twin Strike"]},
	# --- Silvermere's own guardians: enchanted, ward-bound, not souls
	"gsent": {"name": "Enchanted Garden Sentinel", "hp": 170, "atk": 30, "def": 22, "mag": 10, "res": 16, "spd": 3, "will": 10, "move": 3, "jump": 1, "exp": 330, "role": "guardian", "rank_cap": C,
		"skills": ["Shield Prod", "Shoulder Barge", "Thunderclap"]},
	"gcons": {"name": "Elite Guardian Construct", "hp": 340, "atk": 33, "def": 25, "mag": 0, "res": 13, "spd": 3, "will": 12, "move": 3, "jump": 2, "exp": 760, "role": "brute", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Shoulder Barge", "Stunning Blow", "Bulwark"]},
	"gguard": {"name": "Ancient Royal Guardian", "hp": 330, "atk": 33, "def": 25, "mag": 8, "res": 15, "spd": 3, "will": 12, "move": 3, "jump": 2, "exp": 760, "role": "guardian", "rank_cap": C,
		"skills": ["Cleaver of Ruin", "Bulwark", "Fortify", "Shoulder Barge"]},
	# --- bosses. Vaelor keeps his name (and so his look) in every appearance.
	"vaelor": {"name": "Commander Vaelor", "hp": 600, "atk": 36, "def": 26, "mag": 10, "res": 18, "spd": 8, "will": 25, "move": 4, "jump": 3, "exp": 2000, "role": "support", "boss": true,
		"skills": ["Whirlwind", "Phalanx", "Cleaver of Ruin", "Battle Hymn", "Rallying Blow", "Bulwark", "Executioner's Cut", "Fortify"]},
	"vaelor3": {"name": "Commander Vaelor", "hp": 680, "atk": 39, "def": 28, "mag": 12, "res": 20, "spd": 9, "will": 27, "move": 4, "jump": 3, "exp": 2600, "role": "support", "boss": true,
		"skills": ["Whirlwind", "Phalanx", "Shatter Guard", "Last Stand", "Battle Hymn", "Rallying Blow", "Executioner's Cut", "Fortify"]},
	# Reave: a living human duelist with a rapier. Speed, precision, counters, positioning. He does not summon.
	"reave": {"name": "Reave", "hp": 640, "atk": 40, "def": 22, "mag": 8, "res": 18, "spd": 13, "will": 26, "move": 5, "jump": 4, "exp": 3000, "role": "skirmisher", "boss": true,
		"skills": ["Feinting Lunge", "Twin Strike", "Step-Aside Strike", "Thousand Cuts", "Blade Storm", "Flank Order", "Weak Point", "Cartwheel Slash"]},
	# Elowen: a living summoner. Spirit strikes, wards, a commanding presence; she calls elite Falcon Guard vessels (ScenarioRules boss_summon) within her limits.
	"elowen": {"name": "Elowen", "hp": 600, "atk": 10, "def": 18, "mag": 40, "res": 26, "spd": 9, "will": 30, "move": 4, "jump": 3, "exp": 3000, "role": "caster", "boss": true,
		"skills": ["Soul Rend", "Abyssal Maw", "Singularity", "Null Field", "Sanctuary", "Commander's Aura", "Event Horizon", "Battle Hymn"]},
}


static func kind(key: String) -> Dictionary:
	return KINDS[key] if KINDS.has(key) else Falcon.KINDS[key]


static func enemy(key: String, ch: int, n: int, i: int) -> EnemyData:
	return Crucible.build(kind(key), StringName("arc%d_%d_%s_%d" % [ch, n, key, i]), LEVEL[ch] + n - 1, TUNE)


static func map_path(ch: int, n: int) -> String:
	return "res://samples/arc%d_%d.json" % [ch, n]


static func setup(ch: int, n: int, _rng: RandomNumberGenerator = null) -> BattleSetup:
	var path := map_path(ch, n)
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Riverford.cell(sp["king"])
	s.captain_cell = Riverford.cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([SummonStone.make(null, STONE[0], STONE[1], STONE[2], STONE[3], STONE[4]), Riverford.cell(c)])
	var i := 0
	for e in sp["enemies"]:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), ch, n, i), Riverford.cell(e["at"])])
	s.objective = "Defeat all enemies"
	if (ch == 12 and n == 5) or (ch == 15 and n == 2):
		s.objective = "Defeat all enemies, including Vaelor"
		s.flee = {"Commander Vaelor": YIELD_PERCENT}
		s.flee_style = "yield"
		s.flee_line = FinalStory.vaelor_fades(ch)
	if ch == 15 and n == 5:  # the last summoners: both are beaten, neither dies; Elowen calls a few of her strongest vessels while she stands
		s.objective = "Defeat all enemies, including Reave and Elowen"
		s.flee = {"Reave": YIELD_PERCENT, "Elowen": YIELD_PERCENT}
		s.flee_style = "yield"
		s.flee_line = FinalStory.lovers_fall()
		s.rules = {"boss_summon": {"unit": "Elowen", "every": 3, "kind": "felite", "count": 1, "max": 3, "from": "final", "chapter": 15, "map": 5,
			"banner": "Elowen calls her strongest vessels!", "float": "Summoned!", "objective": "Defeat Reave and Elowen"}}
	s.max_summons = 6
	s.opening_line = FinalStory.opening(ch, n)
	return s


## Cassian Vale joins as a vessel in chapter fourteen (the existing vessel roster; no new interface). Safe to call twice.
static func cassian() -> VesselData:
	return Crucible._vessel("Cassian Vale", &"cassian", {"hp": 88, "atk": 13, "def": 9, "mag": 6, "res": 8, "spd": 7, "will": 14, "move": 4, "jump": 3}, "General's Saber",
		[["Command Baton", "Battle Hymn"], ["Academy Seal", "Flank Order"]])


static func recruit_cassian(g: SaveGame) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	if not owned.any(func(o): return o.display_name == "Cassian Vale"):
		owned.append(cassian())
	return g
