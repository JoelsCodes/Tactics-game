class_name Riverford
extends RefCounted
## Chapter two, "The Price of Embers": the five Riverford battles (samples/riverford_1..5.json, made by tools/make_riverford_maps.py). Each map
## file carries its own "spawns" (Alaric, the Co-Captain's place, the summon stones, the enemies, the waves). The story (the owner's text) and
## where each scene plays are in RiverfordStory; the world map lists the maps (WorldData).
##   1 The Back Alleys    16x22  a pack of Rot-Hounds ambushes the party at the crossing in the market quarter
##   2 The Tangled Paths  16x24  Town Watchmen close in from three sides across a canal district
##   3 The Interception   16x20  the squires have Merc cornered in a walled yard; the party arrives from the high street
##   4 The Final Stand    16x20  the squires' last stand in the courtyard's mouth, at dusk
##   5 Vesper's Wrath     16x24  Vesper calls royal guards and battle-mages from the drain; she flees when wounded (waves, `Vesper` retreats)
## Rules every map follows (the owner's): depth 16, up to 24 wide; everyone starts out of reach on turn one (tests/spacing_check.gd); the road
## to the foes is a detour. Only rank E skills are used here: every enemy has a short list of its own (skills_only) and the summon stones carry
## rank E physical skills. Stats are written per kind below (unique, and kept fair against a party of Alaric, Bram, Lyra and Merc by
## the balance simulator, godot/tools/balance/run.sh).

const MAPS := ["", "res://samples/riverford_1.json", "res://samples/riverford_2.json", "res://samples/riverford_3.json", "res://samples/riverford_4.json", "res://samples/riverford_5.json"]
const NAMES := ["", "The Back Alleys", "The Tangled Paths", "The Interception", "The Final Stand", "Vesper's Wrath"]
const MARKET := "res://samples/riverford_market.json"  ## the opening scene's stage
const ENEMY_LEVEL := [0, 2, 3, 4, 4, 6]
const FLEE_PERCENT := 40  ## Vesper leaves the fight at this share of her HP

## One entry per kind: display name (the sheet is found by name, UnitLook.ENEMY_CHARACTERS), base stats, and the rank E skills it uses.
## hp/atk/def/mag/res/spd/will/move/jump are the stats before the level's 2% a level on HP and SP.

## Difficulty tuning per map, found with the balance simulator (tests/balance_sim.tscn, tools/balance/run.sh): "hp" multiplies every enemy's base HP, "atk" and "mag" are
## added to its Attack and Magic, "drop" leaves that many enemies out of the map's first group (from the end of its list) and "wave_drop" the same from each wave.
## Change these (or KINDS) and run the simulator again; the aim is "fair" (60 to 90% for the AI party), the map by map ramp matters more than the number.
const TUNE := {1: {"hp": 0.55, "atk": -3, "drop": 1}, 2: {"hp": 0.55, "atk": -3, "drop": 1}, 3: {"hp": 0.55, "atk": -3, "drop": 1}, 4: {"hp": 0.5, "atk": -3, "drop": 1},
	5: {"hp": 0.5, "atk": -3, "mag": -2, "drop": 1, "wave_drop": 1}}
const KINDS := {
	"hound": {"name": "Rot-Hound", "hp": 25, "atk": 6, "def": 2, "mag": 0, "res": 2, "spd": 8, "will": 6, "move": 5, "jump": 3, "exp": 22,
		"skills": ["Hamstring Cut"]},
	"alpha": {"name": "Rot-Hound Alpha", "hp": 38, "atk": 7, "def": 4, "mag": 0, "res": 3, "spd": 7, "will": 8, "move": 5, "jump": 3, "exp": 40,
		"skills": ["Hamstring Cut", "Crescent Strike"]},
	"slime": {"name": "Sewer Slime", "hp": 40, "atk": 4, "def": 6, "mag": 2, "res": 1, "spd": 3, "will": 6, "move": 3, "jump": 1, "exp": 24,
		"skills": ["Grip Loosen"]},
	"watchman": {"name": "Town Watchman", "hp": 34, "atk": 6, "def": 6, "mag": 0, "res": 3, "spd": 4, "will": 6, "move": 4, "jump": 2, "exp": 30,
		"skills": ["Shield Prod", "Quick Jab"]},
	"scout": {"name": "Watch Scout", "hp": 25, "atk": 7, "def": 3, "mag": 0, "res": 3, "spd": 8, "will": 8, "move": 5, "jump": 3, "exp": 32,
		"skills": ["Feinting Lunge", "Dirty Sand Kick", "Step-Aside Strike"]},
	"brute": {"name": "Watch Sergeant", "hp": 48, "atk": 8, "def": 7, "mag": 0, "res": 3, "spd": 3, "will": 6, "move": 3, "jump": 1, "exp": 55,
		"skills": ["Shield Prod", "Grip Loosen"]},
	"squire": {"name": "Ashen Squire", "hp": 32, "atk": 6, "def": 5, "mag": 0, "res": 3, "spd": 5, "will": 6, "move": 4, "jump": 2, "exp": 30,
		"skills": ["Quick Jab", "Crescent Strike"]},
	"aide": {"name": "Captain's Aide", "hp": 42, "atk": 7, "def": 6, "mag": 0, "res": 4, "spd": 5, "will": 8, "move": 4, "jump": 2, "exp": 60,
		"skills": ["Feinting Lunge", "Shield Prod", "Bonk"]},
	"guard": {"name": "Royal Guard", "hp": 46, "atk": 8, "def": 9, "mag": 0, "res": 4, "spd": 3, "will": 6, "move": 3, "jump": 1, "exp": 50,
		"skills": ["Shield Prod", "Hamstring Cut"]},
	"mage": {"name": "Battle-Mage", "hp": 25, "atk": 3, "def": 3, "mag": 11, "res": 7, "spd": 6, "will": 14, "move": 4, "jump": 2, "exp": 45,
		"skills": ["Ember Flick", "Frost Prick", "Static Snap"]},
	"priest": {"name": "Battle-Mage", "hp": 28, "atk": 3, "def": 4, "mag": 10, "res": 8, "spd": 5, "will": 16, "move": 4, "jump": 2, "exp": 45,
		"skills": ["Bandage Hat", "Hum a Tune", "Soak"]},
	"vesper": {"name": "Vesper", "hp": 78, "atk": 10, "def": 8, "mag": 6, "res": 6, "spd": 7, "will": 10, "move": 5, "jump": 3, "exp": 140,
		"skills": ["Feinting Lunge", "Hamstring Cut", "Step-Aside Strike", "Dirty Sand Kick"]},
}


## The battle for map `n` (1-5) as a BattleSetup (no map id or flags: WorldData sets those).
static func setup(n: int, rng: RandomNumberGenerator = null) -> BattleSetup:
	var path: String = MAPS[n]
	var sp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["spawns"]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = cell(sp["king"])
	s.captain_cell = cell(sp["captain"])
	for c in sp["stones"]:
		s.relics.append([FirstBattle._stone(), cell(c)])
	var i := 0
	var tune: Dictionary = TUNE.get(n, {})
	var first: Array = sp["enemies"].duplicate()
	for k in int(tune.get("drop", 0)):  # leave out the last of the list that is not Vesper
		var at := first.size() - 1
		while at > 0 and first[at].kind == "vesper":
			at -= 1
		if first.size() > 2:
			first.remove_at(at)
	for e in first:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i, rng), cell(e["at"])])
	for w in sp.get("waves", []):
		var wave := {"round": int(w["round"]), "enemies": [], "line": w.get("line", []), "banner": String(w.get("banner", ""))}
		var members: Array = w["enemies"].duplicate()
		for k in int(tune.get("wave_drop", 0)):
			if members.size() > 1:
				members.pop_back()
		for e in members:
			i += 1
			wave.enemies.append([enemy(String(e["kind"]), n, i, rng), cell(e["at"])])
		s.waves.append(wave)
	s.objective = ["", "Defeat the Rot-Hounds", "Defeat the Town Watch", "Defeat the squires", "Cut down the squires", "Break Vesper's guard (Vesper flees when wounded)"][n]
	if n == 5:
		s.flee = {"Vesper": FLEE_PERCENT}
		s.flee_line = RiverfordStory.flee_line()
	s.opening_line = RiverfordStory.opening(n)
	s.max_summons = 6
	return s


static func cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


## An enemy of `kind` for map `n`: its own stats from KINDS, its level from the map, its rank E skills only.
static func enemy(kind: String, n: int, i: int, _rng: RandomNumberGenerator = null) -> EnemyData:
	var k: Dictionary = KINDS[kind]
	var e := EnemyData.new()
	e.id = StringName("riverford_%d_%s_%d" % [n, kind, i])
	e.display_name = k.name
	e.stats = stats(kind, ENEMY_LEVEL[n])
	var tune: Dictionary = TUNE.get(n, {})
	e.stats.base_max_hp = maxi(20, roundi(e.stats.base_max_hp * float(tune.get("hp", 1.0))))
	e.stats.attack = maxi(2, e.stats.attack + int(tune.get("atk", 0)))
	if e.stats.magic > 0:
		e.stats.magic = maxi(1, e.stats.magic + int(tune.get("mag", 0)))
	e.basic_attack_only = false
	e.skills_only = true
	for sk in k.skills:
		var s := SkillLibrary.find(sk)
		assert(s != null and s.rank == SkillData.Rank.E, "rank E skill " + sk)
		e.skills.append(s)
	e.exp_reward = int(k.exp)
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.ROOK
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
	return e


static func stats(kind: String, level: int) -> CharacterStats:
	var k: Dictionary = KINDS[kind]
	var c := CharacterStats.new()
	c.display_name = k.name
	c.level = level
	c.base_max_hp = int(k.hp)
	c.attack = int(k.atk)
	c.defense = int(k.def)
	c.magic = int(k.mag)
	c.resistance = int(k.res)
	c.speed = int(k.spd)
	c.will = int(k.will)
	c.move = int(k.move)
	c.jump = int(k.jump)
	return c


## Merc as a vessel, after the awakening (RiverfordStory): a trader's cunning: swaps places, feints, and the SP to keep at it.
static func merc() -> VesselData:
	var v := VesselData.new()
	v.display_name = "Merc"
	v.id = &"merc"
	v.stats = CharacterStats.new()
	v.stats.display_name = "Merc"
	v.stats.base_max_hp = 56
	v.stats.attack = 7
	v.stats.defense = 6
	v.stats.magic = 4
	v.stats.resistance = 5
	v.stats.speed = 7
	v.stats.will = 8
	v.stats.move = 5
	v.stats.jump = 3
	var w := WeaponItem.new()
	w.display_name = "Spectral Dagger"
	v.loadout = EquipmentLoadout.make(w, WeaponStyle.new())
	var ledger := RelicItem.new()
	ledger.display_name = "Ledger of Debts"
	ledger.skill = SkillLibrary.find("Swap Meet")
	var dagger := RelicItem.new()
	dagger.display_name = "Pocketed Dagger"
	dagger.skill = SkillLibrary.find("Feinting Lunge")
	v.loadout.relic_slot_1 = ledger
	v.loadout.relic_slot_2 = dagger
	v.fade_turns = 6
	v.tether_count = 1
	return v


## `g` with Merc among Alaric's vessels (once: calling it again changes nothing). Returns `g`.
static func add_merc(g: SaveGame) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	if not owned.any(func(v): return v.display_name == "Merc"):
		owned.append(merc())
	return g
