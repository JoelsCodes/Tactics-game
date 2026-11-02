class_name SampleParty
extends RefCounted
## A small party for trying the menus before there is a save system: the King (Alaric), two Co-Captains (Sorceress and Vesper) and vessels
## (Bram and Lyra, the story's two, and placeholders) carrying relics with skills from different proficiencies. Placeholder names and numbers.
## Lyra is a vessel, not a Co-Captain.


static func make() -> PartyRoster:
	var p := PartyRoster.new()
	p.king = _human(KingData.new(), "Alaric", {&"physical": "A", &"tactical": "B", &"elemental": "D", &"void": "F"}) as KingData
	p.co_captains.append(_human(CoCaptainData.new(), "Sorceress", {&"healing": "S", &"status": "B", &"physical": "D"}) as CoCaptainData)
	p.co_captains.append(_human(CoCaptainData.new(), "Vesper", {&"physical": "B", &"elemental": "A", &"tactical": "C"}) as CoCaptainData)
	p.king.vessel_roster.append(_vessel("Ashen Squire", [
		_relic("Cracked Banner", _skill("Rally Cry", Proficiency.Category.TACTICAL, 4, 0)),
		_relic("Rusted Pike", _skill("Lunge", Proficiency.Category.PHYSICAL, 3, 8)),
	], 2))
	p.king.vessel_roster.append(_vessel("Hollow Choir", [
		_relic("Ember Censer", _skill("Cinder Hymn", Proficiency.Category.ELEMENTAL, 6, 9)),
		_relic("Wax Seal", _skill("Silence", Proficiency.Category.STATUS, 5, 0)),
	], 0))
	p.king.vessel_roster.append(_vessel("Lantern Wraith", [
		_relic("Grave Lantern", _skill("Mend Light", Proficiency.Category.HEALING, 5, 7)),
		_relic("Void Shard", _skill("Unmake", Proficiency.Category.VOID, 8, 12)),
	], 5))
	# placeholder vessels for the owner's newer sheets (names to come)
	for spec in [["Shade", Proficiency.Category.VOID, Proficiency.Category.STATUS], ["Lancer", Proficiency.Category.PHYSICAL, Proficiency.Category.TACTICAL],
			["Blade", Proficiency.Category.PHYSICAL, Proficiency.Category.ELEMENTAL]]:
		p.king.vessel_roster.append(_vessel(spec[0], [
			_relic("%s Relic I" % spec[0], _skill("%s Strike" % spec[0], spec[1], 4, 7)),
			_relic("%s Relic II" % spec[0], _skill("%s Art" % spec[0], spec[2], 5, 6)),
		], 0))
	p.king.vessel_roster.append(bram())
	p.king.vessel_roster.append(lyra())
	var thimble := _relic("Iron Thimble", _skill("Guard", Proficiency.Category.TACTICAL, 3, 0))
	thimble.passives = [StatModifier.make(StatModifier.Stat.DEFENSE, 2)]
	thimble.drawbacks = [StatModifier.make(StatModifier.Stat.MOVE, -1)]
	var tallow := _relic("Tallow Candle", _skill("Gutter", Proficiency.Category.STATUS, 4, 0))
	tallow.sp_drain_per_turn = 1
	p.relic_inventory.append_array([thimble, tallow])
	return p


## `ranks`: proficiency id -> rank letter; the rest stay C.
static func _human(u: UnitData, name: String, ranks: Dictionary) -> UnitData:
	u.display_name = name
	u.id = StringName(name.to_lower())
	u.stats = CharacterStats.new()
	u.stats.display_name = name
	u.stats.level = 10
	for c in Proficiency.all():
		u.stats.set_rank(c, TacticalMath.rank_from_letter(ranks.get(Proficiency.id(c), "C")))
	var w := WeaponItem.new()
	w.display_name = "Longsword"
	u.loadout = EquipmentLoadout.make(w, WeaponStyle.new())
	u.skill_tree = SkillTree.new()
	return u


## Bram: the scarred frontline sentinel, a shattered shield in hand. Physical and tactical.
static func bram() -> VesselData:
	var v := _vessel("Bram", [
		_relic("Shattered Shield", _skill("Shield Bash", Proficiency.Category.PHYSICAL, 3, 8)),
		_relic("Iron Oath", _skill("Hold the Line", Proficiency.Category.TACTICAL, 4, 0)),
	], 0)
	v.stats.display_name = "Bram"
	v.stats.base_max_hp = 80
	v.stats.defense = 9
	v.stats.attack = 8
	v.stats.speed = 4
	v.fade_turns = 6
	return v


## Lyra: the spellweaver with floating tactical tomes. Elemental and tactical. A vessel.
static func lyra() -> VesselData:
	var v := _vessel("Lyra", [
		_relic("Floating Tome", _skill("Arc Bolt", Proficiency.Category.ELEMENTAL, 4, 9)),
		_relic("Tactician's Page", _skill("Read the Field", Proficiency.Category.TACTICAL, 3, 0)),
	], 0)
	v.stats.display_name = "Lyra"
	v.stats.base_max_hp = 45
	v.stats.magic = 10
	v.stats.speed = 7
	v.fade_turns = 6
	return v


static func _vessel(name: String, relics: Array, severs: int) -> VesselData:
	var v := VesselData.new()
	v.display_name = name
	v.id = StringName(name.to_lower().replace(" ", "_"))
	v.stats = CharacterStats.new()
	v.sever_count = severs
	v.tether_count = severs + 3
	var w := WeaponItem.new()
	w.display_name = "Spectral Edge"
	v.loadout = EquipmentLoadout.make(w, WeaponStyle.new())
	v.loadout.relic_slot_1 = relics[0]
	if relics.size() > 1:
		v.loadout.relic_slot_2 = relics[1]
	return v


static func _relic(name: String, skill: SkillData) -> RelicItem:
	var r := RelicItem.new()
	r.display_name = name
	r.skill = skill
	return r


static func _skill(name: String, cat: Proficiency.Category, sp: int, power: int) -> SkillData:
	var s := SkillData.new()
	s.id = StringName(name.to_lower().replace(" ", "_"))
	s.display_name = name
	s.category = cat
	s.sp_cost = sp
	s.base_power = power
	return s
