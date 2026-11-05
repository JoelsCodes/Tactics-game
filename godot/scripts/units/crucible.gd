class_name Crucible
extends RefCounted
## Chapter three, "The Crucible and the Crown": the three Crucible battles (samples/crucible_1..3.json, made by tools/make_crucible_maps.py): big maps
## (16 deep, 32 to 40 wide: the battle camera scrolls) on a new tileset (marble, snow, sand, isle stone, lava). Their scenes are in CrucibleStory.
##   1 The Phalanx         a roofless arena; royal infantry in waves from the east arches
##   2 The Pincer          a snowfield pass; battle-mages in towers on both flanks, infantry in the middle
##   3 The Breaking Point  a terrace split by lava rifts; Vesper on a dais, who flees at 40% HP
## Enemies keep to rank E and D skills ("occasional rank D", the owner's wish); the summon stones carry rank E physical skills and now and then a rank D one.
## Chapter three's party: Alaric, Bram, Merc and Lyra; in the scene before map 3 Lyra becomes a Co-Captain (the owner's Co-Captain system: she can be
## deployed as the Co-Captain or summoned as a vessel, not both) and two vessels join: Gideon (the Iron Wall, drawn with the Ashen Squire's armoured
## sheet) and Kaelen (the Stormweaver, the Hollow Choir's mage sheet): the owner allowed any unused vessels in their places.

const MAPS := ["", "res://samples/crucible_1.json", "res://samples/crucible_2.json", "res://samples/crucible_3.json"]
const NAMES := ["", "The Phalanx", "The Pincer", "The Breaking Point"]
const BASTION := "res://samples/crucible_bastion.json"  ## the war room (scene stage)
const ENEMY_LEVEL := [0, 6, 7, 8]
const FLEE_PERCENT := 40
const STONE_D_CHANCE := 0.3  ## the share of summon stones that carry a rank D skill

const KINDS := {
	"phalanx": {"name": "Royal Phalanx", "hp": 52, "atk": 8, "def": 10, "mag": 0, "res": 5, "spd": 3, "will": 6, "move": 3, "jump": 1, "exp": 55, "role": "guardian",
		"skills": ["Shield Prod", "Hamstring Cut", "Shoulder Barge"]},
	"legionary": {"name": "Royal Legionnaire", "hp": 38, "atk": 8, "def": 6, "mag": 0, "res": 3, "spd": 5, "will": 8, "move": 4, "jump": 2, "exp": 45, "role": "",
		"skills": ["Quick Jab", "Crescent Strike", "Twin Strike"]},
	"executioner": {"name": "Royal Executioner", "hp": 66, "atk": 11, "def": 8, "mag": 0, "res": 3, "spd": 2, "will": 8, "move": 3, "jump": 1, "exp": 80, "role": "brute",
		"skills": ["Crescent Strike", "Grip Loosen", "Stunning Blow"]},
	"runemage": {"name": "Rune Mage", "hp": 28, "atk": 3, "def": 3, "mag": 12, "res": 8, "spd": 6, "will": 16, "move": 4, "jump": 2, "exp": 60, "role": "caster",
		"skills": ["Ember Flick", "Static Snap", "Chain Spark", "Frost Lance"]},
	"hexer": {"name": "Rune Hexer", "hp": 30, "atk": 3, "def": 4, "mag": 10, "res": 9, "spd": 5, "will": 18, "move": 4, "jump": 2, "exp": 60, "role": "support",
		"skills": ["Hush", "Bandage Hat", "Lullaby", "Slow Spell"]},
	"wyvern": {"name": "Arena Wyvern", "hp": 44, "atk": 9, "def": 4, "mag": 0, "res": 3, "spd": 8, "will": 6, "move": 6, "jump": 5, "exp": 65, "role": "skirmisher",
		"skills": ["Hamstring Cut", "Step-Aside Strike", "Rending Cut"]},
	"vesper": {"name": "Vesper", "hp": 105, "atk": 12, "def": 9, "mag": 6, "res": 6, "spd": 7, "will": 12, "move": 5, "jump": 3, "exp": 220, "role": "",
		"skills": ["Feinting Lunge", "Hamstring Cut", "Step-Aside Strike", "Twin Strike", "Pin Down"]},
}


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
	for w in sp.get("waves", []):
		var wave := {"round": int(w["round"]), "enemies": [], "line": w.get("line", []), "banner": String(w.get("banner", ""))}
		for e in w["enemies"]:
			i += 1
			wave.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
		s.waves.append(wave)
	s.objective = ["", "Survive the phalanx and break its ranks", "Break the pincer: the mages and the infantry", "Break Vesper's army (Vesper flees when wounded)"][n]
	if n == 3:
		s.flee = {"Vesper": FLEE_PERCENT}
		s.flee_line = CrucibleStory.flee_line()
	s.opening_line = CrucibleStory.opening(n)
	s.max_summons = 6
	return s


## An enemy of `kind` for map `n`: its own stats and its own skills, rank E and D only.
static func enemy(kind: String, n: int, i: int) -> EnemyData:
	var k: Dictionary = KINDS[kind]
	var e := EnemyData.new()
	e.id = StringName("crucible_%d_%s_%d" % [n, kind, i])
	e.display_name = k.name
	e.stats = CharacterStats.new()
	e.stats.display_name = k.name
	e.stats.level = ENEMY_LEVEL[n]
	e.stats.base_max_hp = int(k.hp)
	e.stats.attack = int(k.atk)
	e.stats.defense = int(k.def)
	e.stats.magic = int(k.mag)
	e.stats.resistance = int(k.res)
	e.stats.speed = int(k.spd)
	e.stats.will = int(k.will)
	e.stats.move = int(k.move)
	e.stats.jump = int(k.jump)
	e.skills_only = true
	for sk in k.skills:
		var s := SkillLibrary.find(sk)
		assert(s != null and s.rank <= SkillData.Rank.D, "rank E or D skill " + sk)
		e.skills.append(s)
	e.exp_reward = int(k.exp)
	e.ai_role = String(k.role)
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.ROOK
	e.loadout = EquipmentLoadout.make(WeaponItem.new(), style)
	return e


## Gideon, the Iron Wall: a towering knight of an older age with a two-handed hammer.
static func gideon() -> VesselData:
	return _vessel("Gideon", &"gideon", {"hp": 95, "atk": 11, "def": 10, "mag": 2, "res": 5, "spd": 3, "will": 6, "move": 3, "jump": 1}, "Colossal Hammer",
		[["Hammerhead", "Stunning Blow"], ["Earthshaker", "Shoulder Barge"]])


## Kaelen, the Stormweaver: a battle-mage whose hands crackle with tempest.
static func kaelen() -> VesselData:
	return _vessel("Kaelen", &"kaelen", {"hp": 52, "atk": 3, "def": 4, "mag": 13, "res": 9, "spd": 6, "will": 14, "move": 4, "jump": 2}, "Tempest Staff",
		[["Storm Sigil", "Chain Spark"], ["Static Charm", "Static Snap"]])


static func _vessel(name: String, id: StringName, n: Dictionary, weapon: String, relics: Array) -> VesselData:
	var v := VesselData.new()
	v.display_name = name
	v.id = id
	v.stats = CharacterStats.new()
	v.stats.display_name = name
	v.stats.base_max_hp = int(n.hp)
	v.stats.attack = int(n.atk)
	v.stats.defense = int(n.def)
	v.stats.magic = int(n.mag)
	v.stats.resistance = int(n.res)
	v.stats.speed = int(n.spd)
	v.stats.will = int(n.will)
	v.stats.move = int(n.move)
	v.stats.jump = int(n.jump)
	var w := WeaponItem.new()
	w.display_name = weapon
	v.loadout = EquipmentLoadout.make(w, WeaponStyle.new())
	var slots: Array[RelicItem] = []
	for r in relics:
		var relic := RelicItem.new()
		relic.display_name = r[0]
		relic.skill = SkillLibrary.find(r[1])
		slots.append(relic)
	v.loadout.relic_slot_1 = slots[0]
	v.loadout.relic_slot_2 = slots[1]
	v.fade_turns = 6
	v.tether_count = 1
	return v


## Lyra as a Co-Captain: flesh and blood, with the signature skills of an officer (a hymn, a healing circle and a sanctuary: her auras).
static func lyra_captain() -> CoCaptainData:
	var c := CoCaptainData.new()
	c.display_name = "Lyra"
	c.id = &"lyra"
	c.stats = CharacterStats.new()
	c.stats.display_name = "Lyra"
	c.stats.level = 8
	c.stats.base_max_hp = 70
	c.stats.attack = 6
	c.stats.defense = 6
	c.stats.magic = 13
	c.stats.resistance = 9
	c.stats.speed = 7
	c.stats.will = 15
	c.stats.move = 4
	c.stats.jump = 2
	c.stats.set_rank(Proficiency.Category.HEALING, TacticalMath.Rank.S)
	c.stats.set_rank(Proficiency.Category.TACTICAL, TacticalMath.Rank.A)
	c.stats.set_rank(Proficiency.Category.ELEMENTAL, TacticalMath.Rank.B)
	var w := WeaponItem.new()
	w.display_name = "Living Tome"
	c.loadout = EquipmentLoadout.make(w, WeaponStyle.new())
	c.skill_tree = SkillTree.new()
	for sk in ["Battle Hymn", "Healing Circle", "Sanctuary"]:
		c.signature_skills.append(SkillLibrary.find(sk))
	return c


## The scene before map 3 (RiverfordStory step "give_ch3"): Lyra becomes Alaric's Co-Captain (and stays on the vessel list: she is deployed as one or the
## other, never both: CampaignFlow.prepare_deployment), and Gideon and Kaelen join as vessels. Calling it again changes nothing. Returns `g`.
static func unlock_party(g: SaveGame) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	for v in [gideon(), kaelen()]:
		if not owned.any(func(o): return o.display_name == v.display_name):
			owned.append(v)
	if not g.roster.co_captains.any(func(c): return c.display_name == "Lyra"):
		var lyra := lyra_captain()
		var vessel_lyra: VesselData = owned.filter(func(o): return o.display_name == "Lyra").front() if owned.any(func(o): return o.display_name == "Lyra") else null
		if vessel_lyra != null:  # she keeps what she has learned
			lyra.stats.level = maxi(lyra.stats.level, vessel_lyra.stats.level)
		g.roster.co_captains.append(lyra)
		g.roster.active_co_captain = lyra
	return g
