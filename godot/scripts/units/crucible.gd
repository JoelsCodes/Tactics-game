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

const MAPS := ["", "res://samples/crucible_1.json", "res://samples/crucible_2.json", "res://samples/crucible_3.json", "res://samples/crucible_4.json", "res://samples/crucible_5.json"]
const NAMES := ["", "The Silent Village", "The Lantern Convoy", "The Severing", "The Price of a Soul", "The Warden's Judgment"]
const BASTION := "res://samples/crucible_bastion.json"  ## the war room (scene stage)
const ENEMY_LEVEL := [0, 6, 7, 8, 8, 9]
const FLEE_PERCENT := 40
const CLOCK := {"every": 3, "spirits": 4}  ## Battle 2: a spirit is consumed every 3 rounds while a soul-binder stands; 4 consumed loses
const KING_DRAIN_PCT := 6  ## Battle 4: Alaric loses this percent of his max HP every round until the apparatus gives way
const STONE_D_CHANCE := 0.3  ## the share of summon stones that carry a rank D skill


## Difficulty tuning per map, found with the balance simulator (tests/balance_sim.tscn, tools/balance/run.sh): "hp" multiplies every enemy's base HP, "atk" and "mag" are
## added to its Attack and Magic, "drop" leaves that many enemies out of the map's first group (from the end of its list) and "wave_drop" the same from each wave.
## Change these (or KINDS) and run the simulator again; the aim is "fair" (60 to 90% for the AI party), the map by map ramp matters more than the number.
const TUNE := {1: {"hp": 0.5, "atk": -3, "drop": 1, "wave_drop": 1}, 2: {"hp": 0.5, "atk": -3, "mag": -3, "drop": 1}, 3: {"hp": 0.4, "atk": -4, "mag": -2, "drop": 2, "wave_drop": 1},
	4: {"hp": 0.6, "atk": -3, "mag": -2}, 5: {"hp": 0.5, "atk": -3, "mag": -2}}
const KINDS := {
	"phalanx": {"name": "Royal Phalanx", "hp": 52, "atk": 8, "def": 10, "mag": 0, "res": 5, "spd": 3, "will": 6, "move": 3, "jump": 1, "exp": 55, "role": "guardian",
		"skills": ["Shield Prod", "Hamstring Cut", "Shoulder Barge"]},
	"legionary": {"name": "Royal Legionnaire", "hp": 38, "atk": 8, "def": 6, "mag": 0, "res": 3, "spd": 5, "will": 8, "move": 4, "jump": 2, "exp": 45, "role": "",
		"skills": ["Quick Jab", "Crescent Strike", "Twin Strike"]},
	"executioner": {"name": "Royal Executioner", "hp": 66, "atk": 11, "def": 8, "mag": 0, "res": 3, "spd": 2, "will": 8, "move": 3, "jump": 1, "exp": 80, "role": "brute",
		"skills": ["Crescent Strike", "Grip Loosen", "Stunning Blow"]},
	"runemage": {"name": "Rune Mage", "hp": 28, "atk": 3, "def": 3, "mag": 12, "res": 8, "spd": 6, "will": 10, "move": 4, "jump": 2, "exp": 60, "role": "caster",
		"skills": ["Ember Flick", "Static Snap", "Chain Spark", "Frost Lance"]},
	"hexer": {"name": "Rune Hexer", "hp": 30, "atk": 3, "def": 4, "mag": 10, "res": 9, "spd": 5, "will": 18, "move": 4, "jump": 2, "exp": 60, "role": "support",
		"skills": ["Hush", "Bandage Hat", "Lullaby", "Slow Spell"]},
	"wyvern": {"name": "Arena Wyvern", "hp": 44, "atk": 9, "def": 4, "mag": 0, "res": 3, "spd": 8, "will": 6, "move": 6, "jump": 5, "exp": 65, "role": "skirmisher",
		"skills": ["Hamstring Cut", "Step-Aside Strike", "Rending Cut"]},
	# the lantern-bearer: his Borrowed Hour shortens a vessel's Fade Clock by one tick (SkillFx "fade_drain")
	"soulwarden": {"name": "Soul Warden", "hp": 34, "atk": 3, "def": 4, "mag": 11, "res": 9, "spd": 5, "will": 14, "move": 4, "jump": 2, "exp": 65, "role": "caster",
		"skills": ["Borrowed Hour", "Hollow Touch", "Dim Light", "Null Pulse"]},
	# the new story's units (Nov 2026): lantern bearers walk off the map with a captive spirit, soul-binders and the ritual apparatus never act
	"bearer": {"name": "Lantern Bearer", "hp": 30, "atk": 2, "def": 3, "mag": 0, "res": 3, "spd": 4, "will": 4, "move": 3, "jump": 2, "exp": 40, "role": "", "behavior": "carrier", "skills": []},
	"binder": {"name": "Soul Binder", "hp": 40, "atk": 1, "def": 7, "mag": 0, "res": 7, "spd": 1, "will": 4, "move": 0, "jump": 0, "exp": 60, "role": "", "behavior": "device", "skills": []},
	"apparatus": {"name": "Ritual Apparatus", "hp": 100, "atk": 1, "def": 5, "mag": 0, "res": 5, "spd": 1, "will": 4, "move": 0, "jump": 0, "exp": 150, "role": "", "behavior": "device", "skills": []},
	# the Soul Warden in the fight of Battle 5: positioning, not blows (every skill is the owner's; Lyra is unbound by the soul arts)
	"wardenboss": {"name": "Soul Warden", "hp": 190, "atk": 4, "def": 6, "mag": 13, "res": 12, "spd": 6, "will": 18, "move": 4, "jump": 3, "exp": 300, "role": "support", "boss": true,
		"skills": ["Soul Lantern", "Judgment Chains", "Ether Drain", "Final Absolution", "Borrowed Hour", "Hollow Touch"]},
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
	var tune: Dictionary = TUNE.get(n, {})
	var first: Array = sp["enemies"].duplicate()
	for k in int(tune.get("drop", 0)):
		var at := first.size() - 1
		while at > 0 and first[at].kind in ["vesper", "soulwarden"]:
			at -= 1
		if first.size() > 2:
			first.remove_at(at)
	for e in first:
		i += 1
		s.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
	for w in sp.get("waves", []):
		var wave := {"round": int(w["round"]), "enemies": [], "line": w.get("line", []), "banner": String(w.get("banner", ""))}
		var members: Array = w["enemies"].duplicate()
		for k in int(tune.get("wave_drop", 0)):
			if members.size() > 1:
				members.pop_back()
		for e in members:
			i += 1
			wave.enemies.append([enemy(String(e["kind"]), n, i), Riverford.cell(e["at"])])
		s.waves.append(wave)
	s.objective = ["", "Free the captured spirits", "Destroy the soul-binders", "Break the Soul Warden's guard (he withdraws when wounded)",
		"Disable the ritual apparatus", "Defeat the Soul Warden"][n]
	match n:
		1:
			s.rules = {"carriers": {"exit": sp.get("exit", []), "allowed": 0}, "win_when_down": "carrier"}
		2:
			s.rules = {"clock": CLOCK, "win_when_down": "device"}
		4:
			s.rules = {"king_drain": {"pct": KING_DRAIN_PCT, "source": "Ritual Apparatus"}, "king_must_live": true, "captured": "Lyra", "win_when_down": "Ritual Apparatus",
				"event": {"unit": "Ritual Apparatus", "below": 50, "banner": "Lyra pushes against the bond! The drain on Alaric stops.", "line": ["mira", "Lyra", "Let go. I choose."]}}
	if n == 3:
		s.flee = {"Soul Warden": FLEE_PERCENT}
		s.flee_line = CrucibleStory.flee_line()
	s.opening_line = CrucibleStory.opening(n)
	s.max_summons = 6
	return s


## An enemy of `kind` for map `n`: its own stats and its own skills, rank E and D only.
static func enemy(kind: String, n: int, i: int) -> EnemyData:
	return build(KINDS[kind], StringName("crucible_%d_%s_%d" % [n, kind, i]), ENEMY_LEVEL[n], TUNE.get(n, {}))


## Builds an enemy from a kind's numbers (also chapter four's Mountain.KINDS): `tune` is the map's TUNE entry.
static func build(k: Dictionary, id: StringName, level: int, tune: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.display_name = k.name
	e.stats = CharacterStats.new()
	e.stats.display_name = k.name
	e.stats.level = level
	e.stats.base_max_hp = int(k.hp)
	e.stats.attack = int(k.atk)
	e.stats.defense = int(k.def)
	e.stats.magic = int(k.mag)
	e.stats.resistance = int(k.res)
	e.stats.speed = int(k.spd)
	e.stats.will = int(k.will)
	e.stats.move = int(k.move)
	e.stats.jump = int(k.jump)
	e.stats.base_max_hp = maxi(20, roundi(e.stats.base_max_hp * float(tune.get("hp", 1.0))))
	e.stats.attack = maxi(2, e.stats.attack + int(tune.get("atk", 0)))
	if e.stats.magic > 0:
		e.stats.magic = maxi(1, e.stats.magic + int(tune.get("mag", 0)))
	e.skills_only = true
	for sk in k.skills:
		var s := SkillLibrary.find(sk)
		assert(s != null and (s.rank <= int(k.get("rank_cap", SkillData.Rank.D)) or k.get("boss", false)), "skill within the kind's rank cap: " + sk)
		e.skills.append(s)
	_add_other_proficiencies(e, k)
	_add_chapter_ranks(e, k, chapter_of(String(id)))
	e.exp_reward = int(k.exp)
	e.ai_role = String(k.role)
	e.behavior = String(k.get("behavior", ""))
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


## The scene before map 3 (RiverfordStory step "give_ch3"): Lyra becomes Alaric's Co-Captain (her vessel is merged into her and deleted: merge_lyra), and Gideon and Kaelen join as vessels. Calling it again changes nothing. Returns `g`.
## A vessel joining the party starts one level below Alaric (owner, Nov 2026), grown there through the real experience curve (its stats rise as if it had
## levelled up). Returns the vessel.
static func join_at_level(v: VesselData, g: SaveGame) -> VesselData:
	var target := maxi(1, g.roster.king.stats.level - 1)
	if v.stats.level < target:
		v.stats.add_exp(maxi(0, ExperienceCurve.total_to_reach(target) - v.stats.total_exp), v.loadout)
	return v


static func unlock_party(g: SaveGame, with_vessels := true) -> SaveGame:
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	for v in ([gideon(), kaelen()] if with_vessels else []):
		if not owned.any(func(o): return o.display_name == v.display_name):
			owned.append(join_at_level(v, g))
	if not g.roster.co_captains.any(func(c): return c.display_name == "Lyra"):
		var lyra := lyra_captain()
		g.roster.co_captains.append(lyra)
		g.roster.active_co_captain = lyra
	merge_lyra(g)
	return g


## Lyra becomes human in the story (cr_price_post, "give_lyra"; owner, Nov 2026): her vessel is merged into the Co-Captain and deleted. The
## Co-Captain takes the vessel's level, experience and attributes (each attribute and proficiency rank the higher of the two) and every skill the
## vessel learned or was learning. Does nothing until the Co-Captain exists, so before that scene she stays a vessel.
static func merge_lyra(g: SaveGame) -> void:
	var caps := g.roster.co_captains.filter(func(c): return c.display_name == "Lyra")
	if caps.is_empty():
		return
	var cap: CoCaptainData = caps.front()
	var owned: Array[VesselData] = g.roster.king.vessel_roster
	for v in owned.duplicate():
		if v.display_name != "Lyra":
			continue
		var a: CharacterStats = cap.stats
		var b: CharacterStats = v.stats
		if b.total_exp > a.total_exp or b.level > a.level:
			a.level = b.level
			a.exp = b.exp
			a.total_exp = b.total_exp
		for f in ["base_max_hp", "attack", "defense", "magic", "resistance", "speed", "will", "move", "jump",
				"physical_rank", "elemental_rank", "healing_rank", "tactical_rank", "status_rank", "void_rank"]:
			a.set(f, maxi(int(a.get(f)), int(b.get(f))))
		a.proficiency_efficiency = maxf(a.proficiency_efficiency, b.proficiency_efficiency)
		if cap.skill_tree == null:
			cap.skill_tree = SkillTree.new()
		if v.skill_tree != null:
			for m in v.skill_tree.masteries:
				var mine: SkillMastery = cap.skill_tree.mastery_of(m.skill)
				if mine == null:
					cap.skill_tree.masteries.append(m.duplicate())
				elif m.level > mine.level or (m.level == mine.level and m.progress > mine.progress):
					cap.skill_tree.masteries[cap.skill_tree.masteries.find(mine)] = m.duplicate()
		owned.erase(v)
	g.roster.stand_down = false


## Enemies use every proficiency (owner, Nov 2026): on top of its own list, each kind gets one skill from each of up to two proficiencies it does not already use
## (physical, elemental, healing, tactical, status, void), within its rank cap (bosses up to rank A). The pick is fixed per kind name, so a kind always fights the same way.
static func _add_other_proficiencies(e: EnemyData, k: Dictionary) -> void:
	if String(k.get("behavior", "")) != "":  # devices, standards, memorials and carriers never fight
		return
	var cap := int(k.get("rank_cap", SkillData.Rank.D))
	if k.get("boss", false):
		cap = maxi(cap, SkillData.Rank.A)
	var have := {}
	for s in e.skills:
		have[s.category] = true
	var cats: Array = Proficiency.Category.values().filter(func(c): return not have.has(c))
	var h := absi(String(k.name).hash())
	var added := 0
	for i in cats.size():
		if added >= 2:
			break
		var cat = cats[(h + i) % cats.size()]
		var pool: Array = SkillLibrary.of(cat).filter(func(s): return s.rank <= cap and s.rank >= mini(cap, SkillData.Rank.D))
		if pool.is_empty():
			continue
		var pick: SkillData = pool[(h / 3 + i) % pool.size()]
		if not e.skills.has(pick):
			e.skills.append(pick)
			added += 1


## The chapter a built enemy belongs to, from its id's prefix (crucible_ is chapter three ... arc15_ is chapter fifteen); 0 when unknown.
const CHAPTER_OF := {"crucible": 3, "mountain": 4, "bellwether": 5, "expanse": 6, "vespera": 7, "crown": 8, "palace": 9, "ashes": 10, "falcon": 11, "arc12": 12, "arc13": 13, "arc14": 14, "arc15": 15}


static func chapter_of(id: String) -> int:
	return int(CHAPTER_OF.get(id.get_slice("_", 0), 0))


## The highest skill rank the player's summon stones reach in a chapter (owner, Nov 2026): C up to six, B from seven, A from nine, S (rare) from ten.
static func player_top_rank(chapter: int) -> int:
	if chapter >= 10:
		return SkillData.Rank.S
	if chapter >= 9:
		return SkillData.Rank.A
	if chapter >= 7:
		return SkillData.Rank.B
	return SkillData.Rank.C


## The highest rank an enemy of this kind may use in the chapter: the player's, and one rank up for a boss (owner, Nov 2026).
static func enemy_top_rank(chapter: int, boss: bool) -> int:
	return mini(SkillData.Rank.S, player_top_rank(chapter) + (1 if boss else 0))


## Enemies unlock the same ranks as the player (owner, Nov 2026): from chapter seven each fighting kind also carries one skill of the newer ranks, as the stones do
## (B from seven; A for some kinds from nine, more from ten; S rare from ten, a little more from eleven), from any proficiency; a boss carries one at one rank above the
## player's best. The picks are fixed per kind name.
static func _add_chapter_ranks(e: EnemyData, k: Dictionary, chapter: int) -> void:
	if chapter < 7 or String(k.get("behavior", "")) != "":
		return
	var h := absi(String(k.name).hash())
	var ranks: Array = [SkillData.Rank.B]
	if chapter >= 9 and h % 3 == 0 or chapter >= 10 and h % 2 == 0:
		ranks.append(SkillData.Rank.A)
	if chapter >= 10 and h % 8 == 1 or chapter >= 11 and h % 4 == 1:
		ranks.append(SkillData.Rank.S)
	if k.get("boss", false):
		ranks.append(enemy_top_rank(chapter, true))
	for i in ranks.size():
		var pool: Array = SkillLibrary.of_rank(ranks[i]).filter(func(sk): return not e.skills.has(sk))
		if not pool.is_empty():
			e.skills.append(pool[(h / 5 + i * 11) % pool.size()])
