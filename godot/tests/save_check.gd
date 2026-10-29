extends Node
## Headless checks for saving, loading, roster management and the barracks screens:
## godot --headless --path godot res://tests/save_check.tscn

const DIR := "user://test_saves_check"

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = DIR
	_clean()
	round_trip()
	robustness()
	files()
	roster_rules()
	campaign()
	await ui()
	_clean()
	print("save checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + f)


## A party with something in every field the save has to keep.
func rich_game() -> SaveGame:
	var g := SaveGame.new_game()
	var r := g.roster
	var king := r.king
	king.stats.level = 17
	king.stats.attack = 9
	king.stats.proficiency_efficiency = 1.25
	king.stats.set_rank(Proficiency.Category.VOID, TacticalMath.Rank.S)
	king.stats.set_rank(Proficiency.Category.HEALING, TacticalMath.Rank.F)
	king.loadout.main_weapon.smith_level = 42
	king.loadout.weapon_style.geometry = TacticalMath.Geometry.KNIGHT
	king.loadout.weapon_style.stance = WeaponStyle.Stance.AXE
	king.loadout.weapon_style.reach = 3
	king.loadout.relic_slot_1 = r.relic_inventory[0]
	r.relic_inventory.remove_at(0)
	var vessels := r.vessels()
	vessels[1].loadout.temp_relic = vessels[2].loadout.relic_slot_1  # a tethered relic is saved too
	vessels[2].tether_count = 9
	vessels[2].sever_count = 4
	# a learned skill (level 1+, from use) and a study in progress
	var hymn: SkillData = vessels[1].loadout.relic_slot_1.skill
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	king.skill_tree.start_study(hymn, vessels[1].display_name)
	for i in 60:
		king.skill_tree.use_skill(hymn, king.stats, 1, null, rng)
	var lunge: SkillData = vessels[0].loadout.relic_slot_2.skill
	lunge.rank = SkillData.Rank.A  # a physical skill's rank survives a save
	king.skill_tree.start_study(lunge, vessels[0].display_name)
	king.skill_tree.use_skill(lunge, king.stats, 3, null, rng)
	r.co_captains[0].signature_skills.append(king.skill_tree.masteries[0].skill)
	r.active_co_captain = r.co_captains[1]
	g.campaign.battles_fought = 7
	g.campaign.battles_won = 5
	g.campaign.battles_lost = 1
	g.campaign.vessels_tethered = 12
	g.campaign.vessels_severed = 6
	g.campaign.relics_secured = 3
	g.campaign.relics_lost = 4
	g.campaign.skills_learned = 2
	g.campaign.missions_completed = [&"briar_ford", &"quarry"]
	return g


func as_json(g: SaveGame) -> String:
	return JSON.stringify(SaveCodec.encode(g), "", true)


func round_trip() -> void:
	var g := rich_game()
	var text := as_json(g)
	var parsed = JSON.parse_string(text)
	ok(parsed is Dictionary, "encodes to valid JSON")
	var res := SaveCodec.decode(parsed)
	ok(res.ok and res.warnings.is_empty(), "decodes without warnings: %s %s" % [res.error, res.warnings])
	var back := res.game
	eq(as_json(back), text, "encode -> decode -> encode gives identical data")
	var king := back.roster.king
	var old := g.roster.king
	# stats, level, ranks
	eq([king.display_name, king.stats.level, king.stats.attack], ["Aldric", 17, 9], "King's name, level, attack")
	ok(is_equal_approx(king.stats.proficiency_efficiency, 1.25), "efficiency")
	eq(king.stats.rank_of(Proficiency.Category.VOID), TacticalMath.Rank.S, "Void rank S")
	eq(king.stats.rank_of(Proficiency.Category.HEALING), TacticalMath.Rank.F, "Healing rank F")
	eq(king.stats.rank_of(Proficiency.Category.PHYSICAL), old.stats.rank_of(Proficiency.Category.PHYSICAL), "Physical rank")
	eq(king.stats.max_hp(king.loadout), old.stats.max_hp(old.loadout), "derived HP")
	# the five slots
	eq(king.loadout.main_weapon.smith_level, 42, "Main Weapon smithing level")
	eq(king.loadout.main_weapon.display_name, "Longsword", "Main Weapon name")
	eq([king.loadout.weapon_style.geometry, king.loadout.weapon_style.stance, king.loadout.weapon_style.reach], [TacticalMath.Geometry.KNIGHT, WeaponStyle.Stance.AXE, 3], "Weapon Style")
	eq(king.loadout.relic_slot_1.display_name, "Iron Thimble", "Relic Slot 1")
	eq(king.loadout.relic_slot_1.passives[0].describe(), "Defense +2", "relic passive")
	eq(king.loadout.relic_slot_1.drawbacks[0].describe(), "Move -1", "relic trade-off")
	ok(king.loadout.relic_slot_2 == null, "Relic Slot 2 empty")
	var vs := back.roster.vessels()
	eq(vs.size(), 8, "eight vessels")
	eq(vs[0].loadout.relic_slot_1.display_name, "Cracked Banner", "vessel Relic Slot 1")
	eq(vs[0].loadout.relic_slot_2.display_name, "Rusted Pike", "vessel Relic Slot 2")
	eq(vs[1].loadout.temp_relic.display_name, "Grave Lantern", "Temp-Relic saved")
	ok(vs[1].loadout.temp_relic == vs[2].loadout.relic_slot_1, "a relic shared by two slots stays one object")
	# lifetime stats
	eq([vs[2].tether_count, vs[2].sever_count], [9, 4], "vessel tether_count and sever_count")
	eq([vs[0].tether_count, vs[0].sever_count, vs[0].fade_turns], [5, 2, 5], "other vessel stats")
	# skills
	var tree := king.skill_tree
	eq(tree.masteries.size(), 2, "two skills in the tree")
	var hymn := tree.masteries[0].skill
	eq(hymn.display_name, "Cinder Hymn", "skill name")
	eq(tree.masteries.filter(func(m): return m.skill.display_name == "Lunge")[0].skill.rank, SkillData.Rank.A, "a physical skill's rank survives a save")
	eq(hymn.category, Proficiency.Category.ELEMENTAL, "skill proficiency")
	eq(tree.masteries[0].level, old.skill_tree.masteries[0].level, "skill level")
	ok(tree.is_learned(hymn) and tree.skill_level(hymn) >= 2, "learned and levelled by use (level %d)" % tree.skill_level(hymn))
	eq(tree.masteries[0].progress, old.skill_tree.masteries[0].progress, "level progress")
	eq(tree.masteries[0].mentor_name, "Hollow Choir", "mentor name")
	ok(tree.active_study() == tree.masteries[1] and tree.active_study().skill.display_name == "Lunge", "active study kept")
	ok(tree.can_use(tree.active_study().skill), "the study is still usable")
	eq(tree.active_study().progress, old.skill_tree.active_study().progress, "study progress")
	ok(hymn == vs[1].loadout.relic_slot_1.skill, "one skill object shared by the tree and the relic")
	ok(back.roster.co_captains[0].signature_skills[0] == hymn, "signature skill shared too")
	# roster extras
	eq(back.roster.relic_inventory.map(func(x): return x.display_name), ["Tallow Candle"], "relic inventory")
	eq(back.roster.relic_inventory[0].sp_drain_per_turn, 1, "relic SP drain")
	ok(back.roster.active_co_captain == back.roster.co_captains[1], "active Co-Captain kept (by identity)")
	eq(back.roster.deployed_co_captain().display_name, "Vesper", "and it is the one deployed")
	eq(back.roster.co_captains[0].display_name, "Mira", "Co-Captain")
	eq(back.roster.co_captains[0].stats.rank_of(Proficiency.Category.HEALING), TacticalMath.Rank.S, "Co-Captain rank")
	# campaign
	var c := back.campaign
	eq([c.battles_fought, c.battles_won, c.battles_lost], [7, 5, 1], "battle counts")
	eq([c.vessels_tethered, c.vessels_severed, c.relics_secured, c.relics_lost, c.skills_learned], [12, 6, 3, 4, 2], "campaign counters")
	eq(c.missions_completed, [&"briar_ford", &"quarry"] as Array[StringName], "missions")
	ok(back.roster.audit().is_empty(), "the loaded roster is consistent")


func robustness() -> void:
	var good := SaveCodec.encode(rich_game())
	eq(SaveCodec.decode({}).error, "not a save file (no version)", "empty data")
	ok(SaveCodec.decode({"version": 99}).error.contains("newer version"), "a newer save is refused")
	var no_king := good.duplicate(true)
	no_king.erase("king")
	eq(SaveCodec.decode(no_king).error, "the save has no King", "no King")
	# damaged or hand-edited values never crash; they are clamped or defaulted
	var bad := good.duplicate(true)
	bad.king.stats.level = 500
	bad.king.stats.move = -4
	bad.king.stats.proficiency_efficiency = 9.0
	bad.king.stats.ranks.physical = "Z"
	bad.king.stats.attack = "lots"
	bad.king.loadout.main_weapon.smith_level = 1000
	bad.king.loadout.weapon_style.geometry = "TELEPORT"
	bad.king.vessels[0].tether_count = -5
	bad.king.vessels[0].fade_turns = 0
	var hymn_key: String = bad.king.skill_tree.masteries[0].skill
	bad.skills[hymn_key].sp_cost = 9000
	bad.skills[hymn_key].category = 7
	bad.campaign.battles_won = -3
	bad.king.skill_tree.masteries[0].level = 250
	var res := SaveCodec.decode(bad)
	ok(res.ok, "damaged values still load")
	var k := res.game.roster.king
	eq(k.stats.level, 99, "level clamped to 99")
	eq(k.stats.move, 1, "move clamped up")
	ok(is_equal_approx(k.stats.proficiency_efficiency, 1.5), "efficiency clamped")
	eq(k.stats.rank_of(Proficiency.Category.PHYSICAL), TacticalMath.Rank.C, "unknown rank becomes C")
	eq(k.stats.attack, 6, "a wrong type falls back to the default")
	eq(k.loadout.main_weapon.smith_level, 99, "smithing clamped")
	eq(k.loadout.weapon_style.geometry, TacticalMath.Geometry.ROOK, "unknown geometry becomes Rook")
	eq(k.vessel_roster[0].tether_count, 0, "negative count clamped to 0")
	eq(k.vessel_roster[0].fade_turns, 1, "fade turns clamped")
	eq(k.skill_tree.masteries[0].skill.sp_cost, 30, "SP cost clamped")
	eq(k.skill_tree.masteries[0].skill.category, Proficiency.Category.PHYSICAL, "bad category becomes Physical")
	eq(k.skill_tree.masteries[0].level, 99, "skill level clamped")
	eq(res.game.campaign.battles_won, 0, "campaign counter clamped")
	# wrong shapes
	var shapes := good.duplicate(true)
	shapes.king.stats = "oops"
	shapes.king.loadout = [1, 2]
	shapes.co_captains = {"a": 1}
	shapes.relics = "no"
	shapes.king.skill_tree = 5
	var r2 := SaveCodec.decode(shapes)
	ok(r2.ok and r2.game.roster.king.stats == null and r2.game.roster.king.loadout == null, "wrong shapes become empty, no crash")
	# dangling references and a relic in two places are reported
	var dup := good.duplicate(true)
	dup.king.loadout.relic_slot_2 = dup.relic_inventory[0]
	dup.king.loadout.relic_slot_1 = "r999"
	dup.active_co_captain = 77
	var r3 := SaveCodec.decode(dup)
	ok(r3.ok and r3.warnings.size() >= 3, "problems are reported as warnings: %s" % [r3.warnings])
	ok(r3.warnings.any(func(w): return w.contains("is in the inventory and on Aldric")), "relic in two places")
	ok(r3.warnings.any(func(w): return w.contains("pointed at nothing")), "dangling relic reference")
	ok(r3.warnings.any(func(w): return w.contains("active Co-Captain entry")), "bad active Co-Captain index")
	var old_save := SaveCodec.encode(rich_game())
	old_save.erase("active_co_captain")
	old_save["active_vessels"] = [0, 1]  # the old squad is ignored
	var r4 := SaveCodec.decode(old_save)
	ok(r4.ok and r4.warnings.is_empty() and r4.game.roster.active_co_captain == null, "saves without a chosen Co-Captain still load")
	eq(r4.game.roster.deployed_co_captain().display_name, "Mira", "...and use the first")


func files() -> void:
	var g := rich_game()
	ok(not SaveSystem.exists("slot1"), "no save yet")
	eq(SaveSystem.load_slot("slot1").error, "no save in slot 'slot1'", "nothing to load")
	eq(SaveSystem.save_slot("slot1", g, 1000), OK, "save")
	ok(SaveSystem.exists("slot1"), "slot file exists")
	var r := SaveSystem.load_slot("slot1")
	ok(r.ok and not r.from_backup and r.game.saved_at == 1000, "load: %s" % r.error)
	eq(as_json(r.game).replace("1000", "X"), as_json(g).replace("1000", "X"), "file round trip")
	ok(not FileAccess.file_exists(SaveSystem.path("slot1") + ".bak"), "first save has no backup")
	g.roster.king.stats.level = 30
	eq(SaveSystem.save_slot("slot1", g, 2000), OK, "save again")
	ok(FileAccess.file_exists(SaveSystem.path("slot1") + ".bak"), "previous save kept as .bak")
	ok(not FileAccess.file_exists(SaveSystem.path("slot1") + ".tmp"), "no temporary file left")
	eq(SaveSystem.load_slot("slot1").game.roster.king.stats.level, 30, "newest save loads")
	# a damaged file falls back to the backup
	var f := FileAccess.open(SaveSystem.path("slot1"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	r = SaveSystem.load_slot("slot1")
	ok(r.ok and r.from_backup and r.game.roster.king.stats.level == 17, "damaged save: the backup loads")
	f = FileAccess.open(SaveSystem.path("slot1") + ".bak", FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	r = SaveSystem.load_slot("slot1")
	ok(not r.ok and r.error.contains("damaged"), "both damaged: a clear error")
	# slots
	for bad_name in ["", "../evil", "A B", "a/b", "x".repeat(40), "Slot1"]:
		eq(SaveSystem.save_slot(bad_name, g), ERR_INVALID_PARAMETER, "slot name '%s' refused" % bad_name)
	ok(not SaveSystem.load_slot("../x").ok, "bad slot on load")
	SaveSystem.save_slot("slot2", rich_game(), 3000)
	SaveSystem.save_slot("autosave", rich_game(), 2500)
	eq(SaveSystem.slots().map(func(s): return s.slot), ["slot2", "autosave"], "damaged slot skipped, newest first")
	eq(SaveSystem.newest_slot(), "slot2", "newest slot")
	eq(SaveSystem.slots()[0].king, "Aldric", "slot info")
	SaveSystem.delete_slot("slot2")
	SaveSystem.delete_slot("autosave")
	SaveSystem.delete_slot("slot1")
	ok(SaveSystem.slots().is_empty() and SaveSystem.newest_slot() == "", "deleted")


func roster_rules() -> void:
	var g := SaveGame.new_game()
	var r := g.roster
	var king := r.king
	var vessel := r.vessels()[0]
	var thimble := r.relic_inventory[0]
	var tallow := r.relic_inventory[1]
	eq(vessel.loadout.relic_slot_2.display_name, "Rusted Pike", "starts with the Pike")
	var pike := vessel.loadout.relic_slot_2
	# equip a spare relic: the replaced one goes back to the inventory
	eq(RosterManager.equip_relic(r, vessel, EquipmentLoadout.Slot.RELIC_SLOT_2, thimble), "", "equip")
	ok(vessel.loadout.relic_slot_2 == thimble and not r.relic_inventory.has(thimble) and r.relic_inventory.has(pike), "swap: Thimble in, Pike back in the inventory")
	eq(RosterManager.holder_of(r, thimble), vessel, "holder")
	ok(RosterManager.holder_of(r, tallow) == null, "a spare relic has no holder")
	ok(r.audit().is_empty(), "still consistent")
	# the same relic cannot go in both slots of one unit, nor be equipped when not spare
	eq(RosterManager.equip_relic(r, vessel, EquipmentLoadout.Slot.RELIC_SLOT_1, thimble), "that relic is not in the inventory", "not spare")
	r.relic_inventory.append(thimble)  # (corrupt on purpose: spare AND equipped)
	eq(RosterManager.equip_relic(r, vessel, EquipmentLoadout.Slot.RELIC_SLOT_1, thimble), "that relic is already in the other relic slot", "same unit, two slots")
	ok(not r.audit().is_empty(), "audit catches a relic in two places")
	r.relic_inventory.erase(thimble)
	# empty a slot
	eq(RosterManager.equip_relic(r, vessel, EquipmentLoadout.Slot.RELIC_SLOT_2, null), "", "unequip")
	ok(vessel.loadout.relic_slot_2 == null and r.relic_inventory.has(thimble), "unequipped relic is spare again")
	eq(RosterManager.equip_relic(r, king, EquipmentLoadout.Slot.RELIC_SLOT_1, tallow), "", "the King can carry relics")
	# fixed slots
	ok(RosterManager.equip_relic(r, king, EquipmentLoadout.Slot.MAIN_WEAPON, null).contains("bound"), "main weapon fixed")
	ok(RosterManager.equip_relic(r, king, EquipmentLoadout.Slot.WEAPON_STYLE, null).contains("no other weapon styles"), "no style swapping yet")
	ok(RosterManager.equip_relic(r, vessel, EquipmentLoadout.Slot.TEMP_RELIC, thimble).contains("only by tethering"), "Temp-Relic is battle only")
	eq(RosterManager.equip_relic(r, EnemyData.new(), EquipmentLoadout.Slot.RELIC_SLOT_1, null), "that unit is not in the party", "not a party unit")
	# the Co-Captain who goes on missions
	eq(r.co_captains.size(), 2, "two Co-Captains")
	eq(r.deployed_co_captain(), r.co_captains[0], "the first goes until another is chosen")
	eq(RosterManager.set_active_co_captain(r, r.co_captains[1]), "", "choose the second")
	eq(r.deployed_co_captain().display_name, "Vesper", "Vesper goes")
	eq(RosterManager.set_active_co_captain(r, CoCaptainData.new()), "that Co-Captain is not in the party", "a stranger cannot be chosen")
	eq(RosterManager.set_active_co_captain(r, null), "that Co-Captain is not in the party", "nor nobody")
	eq(r.deployed_co_captain().display_name, "Vesper", "unchanged by a refused choice")
	ok(r.audit().is_empty(), "consistent")
	r.active_co_captain = CoCaptainData.new()
	ok(not r.audit().is_empty() and r.deployed_co_captain() == r.co_captains[0], "a stale choice is reported and falls back to the first")
	r.active_co_captain = null
	# the leaders on the map: the King always, and the chosen Co-Captain
	var board := TacticalGrid.from_rows([" ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0"])), " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0"])), " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0"]))])
	var dm := DeploymentManager.new()
	add_child(dm)
	dm.setup(board)
	RosterManager.set_active_co_captain(r, r.co_captains[1])
	var leaders := CampaignFlow.deploy_leaders(g, dm, Vector2i(0, 0), Vector2i(1, 0))
	ok(leaders[0] != null and leaders[0].data == r.king, "the King is deployed")
	ok(leaders[1] != null and leaders[1].data == r.co_captains[1], "with the chosen Co-Captain")
	eq(dm.field_units().size(), 2, "one Co-Captain only")
	# any vessel the King owns can be summoned: nothing is picked beforehand
	dm.place_relic(RelicItem.new(), Vector2i(1, 1))
	CampaignFlow.prepare_deployment(g, dm, 4)
	eq(dm.summon_limit, 4, "the map's limit")
	for v in r.vessels():
		eq(dm.summon_error(v, Vector2i(1, 1)), "", "%s can be summoned" % v.display_name)
	eq(dm.summon_error(VesselData.new(), Vector2i(1, 1)), "not one of the King's vessels", "a vessel the King does not own cannot")
	var solo := SaveGame.new_game()
	solo.roster.co_captains.clear()
	var dm2 := DeploymentManager.new()
	add_child(dm2)
	dm2.setup(TacticalGrid.from_rows(["g0 g0 g0 g0"]))
	var alone := CampaignFlow.deploy_leaders(solo, dm2, Vector2i(0, 0), Vector2i(1, 0))
	ok(alone[0] != null and alone[1] == null, "no Co-Captain in the party: the King goes alone")


func campaign() -> void:
	var g := SaveGame.new_game()
	var s := BattleSummary.new()
	var v: VesselData = g.roster.vessels()[0]
	var bu := BattleUnit.new(v)
	s.line(bu).tethers = 2
	s.line(bu).severs = 1
	s.relics_secured = [RelicItem.new()] as Array[RelicItem]
	s.relics_lost = [RelicItem.new(), RelicItem.new()] as Array[RelicItem]
	s.skills_learned = [SkillData.new()] as Array[SkillData]
	s.outcome = BattleController.Outcome.WON
	CampaignFlow.record_battle(g, s, &"briar_ford")
	var c := g.campaign
	eq([c.battles_fought, c.battles_won, c.battles_lost], [1, 1, 0], "a win")
	eq([c.vessels_tethered, c.vessels_severed, c.relics_secured, c.relics_lost, c.skills_learned], [2, 1, 1, 2, 1], "totals from the summary")
	ok(c.is_completed(&"briar_ford"), "mission completed by a win")
	CampaignFlow.record_battle(g, s, &"briar_ford")
	eq(c.missions_completed, [&"briar_ford"] as Array[StringName], "no duplicate mission")
	s.outcome = BattleController.Outcome.LOST
	CampaignFlow.record_battle(g, s, &"quarry")
	eq([c.battles_won, c.battles_lost], [2, 1], "a loss")
	ok(not c.is_completed(&"quarry"), "a loss completes nothing")
	s.outcome = BattleController.Outcome.ONGOING
	CampaignFlow.record_battle(g, s)
	eq(c.battles_fought, 4, "ending early still counts as fought")
	eq([c.battles_won, c.battles_lost], [2, 1], "...but is neither a win nor a loss")

	# a real battle through finish_battle: relics home, stats updated, autosaved
	var game := SaveGame.new_game()
	var king := game.roster.king
	var grid := TacticalGrid.from_rows([" ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0"])), " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0"])), " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0"]))])
	var b := BattleController.new()
	add_child(b)
	b.setup(grid)
	CampaignFlow.prepare_deployment(game, b.deployment)
	b.deployment.rng.seed = 4
	var kb := b.deployment.deploy_king(king, Vector2i(0, 1))
	var foe_data := EnemyData.new()
	foe_data.stats = CharacterStats.new()
	foe_data.stats.base_max_hp = 25
	foe_data.stats.speed = 1
	foe_data.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	var foe := b.add_enemy(foe_data, Vector2i(2, 1))
	foe.hp = 1
	var relic := RelicItem.new()
	relic.display_name = "Field relic"
	b.deployment.place_relic(relic, Vector2i(1, 0))
	b.start()
	b.next_turn()
	var vd := game.roster.vessels()[0]
	ok(b.summon_vessel(kb, vd, Vector2i(1, 0)) != null, "summon any vessel the King owns")
	eq(vd.tether_count, 6, "tether_count 5 -> 6 on the roster's vessel")
	b.move(kb, Vector2i(1, 1))
	ok(b.perform(kb, BattleAction.attack(), Vector2i(2, 1)).ok, "King strikes")
	eq(b.outcome, BattleController.Outcome.WON, "won")
	var sum := CampaignFlow.finish_battle(game, b, &"first")
	eq([game.campaign.battles_won, game.campaign.vessels_tethered], [1, 1], "campaign updated")
	ok(game.campaign.is_completed(&"first"), "mission recorded")
	ok(SaveSystem.exists(SaveSystem.AUTOSAVE), "autosaved")
	var loaded := SaveSystem.load_slot(SaveSystem.AUTOSAVE)
	ok(loaded.ok and loaded.game.campaign.battles_won == 1, "the autosave loads")
	eq(loaded.game.roster.vessels()[0].tether_count, 6, "the autosave holds the new tether_count")
	eq(loaded.game.roster.relic_inventory.size(), game.roster.relic_inventory.size(), "the autosave holds the relic inventory")
	ok(loaded.game.roster.vessels()[0].loadout.temp_relic == null, "Temp-Relic empty after the battle")
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
	b.queue_free()
	dm_cleanup()


func dm_cleanup() -> void:
	pass


func ui() -> void:
	_clean()
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	ok(b.game != null and b.roster == b.game.roster, "barracks starts a new game when there is no save")
	eq(b.captain_buttons.size(), 2, "a Send on missions button per Co-Captain")
	eq(b.vessel_loadout_buttons.size(), 8, "a Loadout button per vessel")
	eq(b.human_loadout_buttons.size(), 3, "a Loadout button per human")
	eq(b.mentor_buttons.size(), 3, "a Mentorship button per human")
	ok(b.vessel_loadout_buttons.size() == 8 and b.find_children("*", "Button", true, false).all(func(x): return not x.text in ["Active", "Benched"]), "no squad buttons: vessels are not picked beforehand")
	ok(b.captain_buttons[0].disabled and b.captain_buttons[0].text == "On missions", "the first Co-Captain goes by default")
	ok(not b.captain_buttons[1].disabled and b.captain_buttons[1].text == "Send on missions", "the second can be chosen")
	b.captain_buttons[1].pressed.emit()
	await get_tree().process_frame
	eq(b.roster.deployed_co_captain().display_name, "Vesper", "pressing the button chooses Vesper")
	ok(b.captain_buttons[1].disabled and not b.captain_buttons[0].disabled, "the buttons follow the choice")
	var texts := []
	for n in b.find_children("*", "Label", true, false):
		texts.append(n.text)
	ok(texts.any(func(t): return t.contains("Goes on every mission")), "the King is fixed")
	ok(texts.any(func(t): return t.contains("8 OWNED") and t.contains("UP TO 6 A BATTLE")), "vessels: all owned, summon up to six a battle")
	await get_tree().process_frame

	# loadout menu: swap in a spare relic
	var vessel := b.roster.vessels()[0]
	var pike := vessel.loadout.relic_slot_2
	var spare := b.roster.relic_inventory[0]
	b.vessel_loadout_buttons[0].pressed.emit()
	var lm := b.loadout_menu
	ok(lm.visible and not b.main.visible and lm.unit == vessel, "loadout menu opens for the vessel")
	eq(lm.slot_list.item_count, 5, "five slots listed")
	eq(lm.slot_list.get_item_text(0), "Main Weapon:  Spectral Edge  (Raw 8)", "slot 1 is the Main Weapon")
	eq(lm.slot_list.get_item_text(4).begins_with("Temp-Relic"), true, "slot 5 is the Temp-Relic")
	for fixed in [0, 1, 4]:
		lm.slot_list.select(fixed)
		lm.slot_list.item_selected.emit(fixed)
		ok(lm.apply_button.disabled and lm.choice_list.item_count == 0, "slot %d cannot be changed here" % (fixed + 1))
	lm.slot_list.select(3)
	lm.slot_list.item_selected.emit(3)
	eq(lm.choice_list.item_count, 4, "the equipped relic, Empty and the two spare relics")
	eq(lm.choice_list.get_selected_items(), PackedInt32Array([0]), "the equipped relic is the default choice")
	ok(lm.apply_button.disabled and lm.apply_button.text == "Already equipped", "so there is nothing to apply")
	lm.choice_list.select(2)
	lm.choice_list.item_selected.emit(2)
	ok(not lm.apply_button.disabled, "apply enabled")
	lm.apply_button.pressed.emit()
	ok(vessel.loadout.relic_slot_2 == spare and b.roster.relic_inventory.has(pike) and not b.roster.relic_inventory.has(spare), "equipped; the old relic is spare")
	ok(lm.slot_list.get_item_text(3).contains(spare.display_name), "menu refreshed")
	lm.back_button.pressed.emit()
	await get_tree().process_frame
	ok(not lm.visible and b.main.visible, "back to the barracks")

	# save and load from the barracks
	b.roster.king.stats.level = 41
	b.save_button.pressed.emit()
	ok(SaveSystem.exists("slot1") and b.status.text.begins_with("Saved"), "Save button writes slot1")
	b.roster.king.stats.level = 5
	var old_roster := b.roster
	b.load_button.pressed.emit()
	await get_tree().process_frame
	ok(b.roster != old_roster and b.roster.king.stats.level == 41, "Load button restores the saved game")
	ok(b.roster.vessels()[0].loadout.relic_slot_2.display_name == spare.display_name, "loaded the new loadout")
	ok(b.status.text.begins_with("Loaded"), "status says so: %s" % b.status.text)
	b.queue_free()
	await get_tree().process_frame

	# a new barracks continues from the newest save
	var b2: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	add_child(b2)
	await get_tree().process_frame
	eq(b2.roster.king.stats.level, 41, "continues from the newest save")
	b2.queue_free()
