class_name SampleParty
extends RefCounted
## A small party for trying the menus before there is a save system: the King, one Co-Captain and
## three vessels carrying relics with skills from different proficiencies. Placeholder names and numbers.


static func make() -> PartyRoster:
	var p := PartyRoster.new()
	p.king = _human(KingData.new(), "Aldric", {&"physical": 6, &"tactical": 4, &"elemental": 1}) as KingData
	p.co_captains.append(_human(CoCaptainData.new(), "Mira", {&"healing": 7, &"status": 3, &"physical": 2}) as CoCaptainData)
	p.king.vessel_roster.append(_vessel("Ashen Squire", [
		_relic("Cracked Banner", _skill("Rally Cry", Proficiency.Category.TACTICAL, 4, 0, 3)),
		_relic("Rusted Pike", _skill("Lunge", Proficiency.Category.PHYSICAL, 3, 8, 4)),
	], 2))
	p.king.vessel_roster.append(_vessel("Hollow Choir", [
		_relic("Ember Censer", _skill("Cinder Hymn", Proficiency.Category.ELEMENTAL, 6, 9, 5)),
		_relic("Wax Seal", _skill("Silence", Proficiency.Category.STATUS, 5, 0, 3)),
	], 0))
	p.king.vessel_roster.append(_vessel("Lantern Wraith", [
		_relic("Grave Lantern", _skill("Mend Light", Proficiency.Category.HEALING, 5, 7, 4)),
		_relic("Void Shard", _skill("Unmake", Proficiency.Category.VOID, 8, 12, 8)),
	], 5))
	return p


static func _human(u: UnitData, name: String, levels: Dictionary) -> UnitData:
	u.display_name = name
	u.id = StringName(name.to_lower())
	u.stats = CharacterStats.new()
	u.stats.display_name = name
	u.stats.level = 10
	for c in Proficiency.all():
		var t := u.stats.ensure_proficiency(Proficiency.id(c))
		t.level = levels.get(Proficiency.id(c), 0)
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
	v.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	v.loadout.relic_slot_1 = relics[0]
	if relics.size() > 1:
		v.loadout.relic_slot_2 = relics[1]
	return v


static func _relic(name: String, skill: SkillData) -> RelicItem:
	var r := RelicItem.new()
	r.display_name = name
	r.skill = skill
	return r


static func _skill(name: String, cat: Proficiency.Category, sp: int, power: int, need: int) -> SkillData:
	var s := SkillData.new()
	s.id = StringName(name.to_lower().replace(" ", "_"))
	s.display_name = name
	s.category = cat
	s.sp_cost = sp
	s.base_power = power
	s.required_level = need
	return s
