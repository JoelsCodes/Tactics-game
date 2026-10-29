class_name SampleParty
extends RefCounted
## A small party for trying the menus before there is a save system: the King, two Co-Captains (the
## first goes on missions until another is chosen) and three vessels carrying relics with skills from different proficiencies. Placeholder names and numbers.


static func make() -> PartyRoster:
	var p := PartyRoster.new()
	p.king = _human(KingData.new(), "Aldric", {&"physical": "A", &"tactical": "B", &"elemental": "D", &"void": "F"}) as KingData
	p.co_captains.append(_human(CoCaptainData.new(), "Lyra", {&"healing": "S", &"status": "B", &"physical": "D"}) as CoCaptainData)
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
	for spec in [["Sorceress", Proficiency.Category.ELEMENTAL, Proficiency.Category.HEALING], ["Warden", Proficiency.Category.TACTICAL, Proficiency.Category.PHYSICAL],
			["Shade", Proficiency.Category.VOID, Proficiency.Category.STATUS], ["Lancer", Proficiency.Category.PHYSICAL, Proficiency.Category.TACTICAL],
			["Blade", Proficiency.Category.PHYSICAL, Proficiency.Category.ELEMENTAL]]:
		p.king.vessel_roster.append(_vessel(spec[0], [
			_relic("%s Relic I" % spec[0], _skill("%s Strike" % spec[0], spec[1], 4, 7)),
			_relic("%s Relic II" % spec[0], _skill("%s Art" % spec[0], spec[2], 5, 6)),
		], 0))
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
