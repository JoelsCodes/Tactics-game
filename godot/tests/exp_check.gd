extends Node
## Headless checks for character XP and levelling: godot --headless --path godot res://tests/exp_check.tscn

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
	SaveSystem.dir = "user://test_saves_exp"
	curve()
	add_exp()
	scaling()
	unit_data()
	pool_and_rule()
	real_battle()
	persistence()
	await ui()
	print("exp checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func board() -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(12)
	row.fill("g0")
	for y in 12:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func make(cls, name: String, speed := 6) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.speed = speed
	var s := WeaponStyle.new()
	s.geometry = TacticalMath.Geometry.ROOK
	s.reach = 2
	s.stance = WeaponStyle.Stance.IMPACT  # reach 1 with a cross burst
	u.loadout = EquipmentLoadout.make(WeaponItem.new(), s)
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


func curve() -> void:
	eq([ExperienceCurve.to_next(1), ExperienceCurve.to_next(2), ExperienceCurve.to_next(10)], [100, 110, 190], "100 to leave level 1, +10 each level")
	eq([ExperienceCurve.to_next(50), ExperienceCurve.to_next(98)], [590, 1070], "later levels")
	eq(ExperienceCurve.to_next(99), 0, "nothing past level 99")
	eq([ExperienceCurve.to_next(0), ExperienceCurve.to_next(500)], [100, 0], "levels are clamped to 1-99")
	eq([ExperienceCurve.total_to_reach(1), ExperienceCurve.total_to_reach(2), ExperienceCurve.total_to_reach(3)], [0, 100, 210], "cumulative")
	eq(ExperienceCurve.total_to_reach(99), 57330, "level 99 takes 57,330 XP in all")
	var sum := 0
	for l in range(1, 99):
		sum += ExperienceCurve.to_next(l)
	eq(sum, 57330, "the cumulative formula matches the sum")
	eq(ExperienceCurve.at_total(0), Vector2i(1, 0), "total 0")
	eq(ExperienceCurve.at_total(99), Vector2i(1, 99), "just below level 2")
	eq(ExperienceCurve.at_total(100), Vector2i(2, 0), "exactly level 2")
	eq(ExperienceCurve.at_total(250), Vector2i(3, 40), "250 = level 3 + 40")
	eq(ExperienceCurve.at_total(999999), Vector2i(99, 0), "capped")


func add_exp() -> void:
	var s := CharacterStats.new()
	eq([s.level, s.exp, s.total_exp, s.exp_to_next_level], [1, 0, 0, 100], "a new character")
	ok(s.add_exp(60).is_empty(), "60 XP: no level yet")
	eq([s.level, s.exp, s.total_exp], [1, 60, 60], "progress kept")
	var ups := s.add_exp(50)
	eq(ups.size(), 1, "110 total: one level")
	eq([s.level, s.exp], [2, 10], "excess XP rolls over")
	eq([ups[0].from_level, ups[0].to_level], [1, 2], "the level-up record")
	eq(s.exp_to_next_level, 110, "level 2 needs 110")
	ups = s.add_exp(400)  # 10 + 400 = 410: level 2 (110) -> 3 (120) -> 4 (130) -> 5 needs 140: 410-110-120-130 = 50
	eq(ups.size(), 3, "several levels at once")
	eq([s.level, s.exp], [5, 50], "levels 3, 4 and 5")
	eq(ups.map(func(u): return u.to_level), [3, 4, 5], "one record per level")
	eq(s.total_exp, 510, "lifetime XP")
	eq(s.add_exp(-30).size(), 0, "negative XP is ignored")
	eq(s.total_exp, 510, "...and not counted")
	# the cap
	var c := CharacterStats.new()
	c.add_exp(ExperienceCurve.total_to_reach(99) + 5000)
	eq([c.level, c.exp, c.exp_to_next_level], [99, 0, 0], "level 99: no leftover, nothing to earn")
	eq(c.total_exp, 57330 + 5000, "the cap still counts lifetime XP")
	eq(c.add_exp(100).size(), 0, "no level-ups at 99")
	eq(c.exp, 0, "no XP stored at the cap")
	# level set by hand is clamped; exp does not invent levels
	c.level = 120
	eq(c.level, 99, "level clamped to 99")
	c.level = 0
	eq(c.level, 1, "level clamped to 1")
	# exactly at the threshold
	var e := CharacterStats.new()
	eq(e.add_exp(100).size(), 1, "exactly 100 levels up")
	eq([e.level, e.exp], [2, 0], "with nothing left over")


func scaling() -> void:
	var s := CharacterStats.new()  # base HP 60, will 6, magic 5
	var ups := s.add_exp(100)
	eq([ups[0].hp_before, ups[0].hp_after], [61, 62], "level 1 -> 2: 60 x 1.02 = 61.2, x 1.04 = 62.4")
	s = CharacterStats.new()
	s.add_exp(ExperienceCurve.total_to_reach(50))
	eq(s.level, 50, "to level 50")
	eq(s.max_hp(), 120, "HP doubles by level 50 (x 2.0)")
	eq(s.max_sp(), 19, "SP: (5 + 3 + 1.25) x 2.0 = 18.5 rounds to 19")
	s.add_exp(ExperienceCurve.total_to_reach(99) - ExperienceCurve.total_to_reach(50))
	eq(s.level, 99, "to level 99")
	eq(s.max_hp(), 179, "60 x 2.98")
	eq(s.max_sp(), 28, "9.25 x 2.98 = 27.6")
	# the pools never leave the limits
	var big := CharacterStats.new()
	big.base_max_hp = 100
	big.will = 30
	big.magic = 30
	big.add_exp(ExperienceCurve.total_to_reach(99))
	eq([big.max_hp(), big.max_sp()], [298, 30], "the best character: 100 x 2.98 HP, SP capped at 30")
	var geared := EquipmentLoadout.new()
	var relic2 := RelicItem.new()
	relic2.passives = [StatModifier.make(StatModifier.Stat.MAX_HP, 50)]
	geared.relic_slot_1 = relic2
	eq(big.max_hp(geared), 300, "equipment cannot push HP past 300")
	# every level up never lowers a pool
	var t := CharacterStats.new()
	var prev_hp := t.max_hp()
	var prev_sp := t.max_sp()
	var rising := true
	for l in 98:
		var up := t.add_exp(t.exp_to_next_level)
		rising = rising and up.size() == 1 and up[0].hp_after >= prev_hp and up[0].sp_after >= prev_sp and up[0].hp_before == prev_hp
		prev_hp = up[0].hp_after
		prev_sp = up[0].sp_after
	ok(rising, "HP and SP never fall across 98 level-ups")
	eq(t.level, 99, "98 level-ups")
	# equipment counts in the record
	var w := CharacterStats.new()
	var l := EquipmentLoadout.new()
	var relic := RelicItem.new()
	relic.passives = [StatModifier.make(StatModifier.Stat.MAX_HP, 10)]
	l.relic_slot_1 = relic
	var up2 := w.add_exp(100, l)[0]
	eq([up2.hp_before, up2.hp_after], [71, 72], "the record includes equipment")
	ok(up2.describe().begins_with("Lv 1 → 2"), "describe")


func unit_data() -> void:
	var u := make(KingData, "King") as KingData
	eq([u.level, u.exp, u.exp_to_next_level, u.total_exp], [1, 0, 100, 0], "UnitData reads level and XP from its stats")
	u.add_exp(130)
	eq([u.level, u.exp, u.exp_to_next_level, u.total_exp], [2, 30, 110, 130], "UnitData.add_exp")
	var bare := VesselData.new()
	eq([bare.level, bare.exp, bare.exp_to_next_level], [1, 0, 0], "a unit without stats")
	eq(bare.add_exp(50).size(), 0, "no stats: nothing happens")


## A summary with player units that did or did not take turns, and enemies.
func manual_summary(pool: int, outcome: BattleController.Outcome, turns: Array) -> Array:
	var s := BattleSummary.new()
	s.outcome = outcome
	s.exp_pool = pool
	var units: Array[BattleUnit] = []
	var datas: Array = [make(KingData, "King"), make(CoCaptainData, "Cap"), make(VesselData, "Wisp"), make(EnemyData, "Foe")]
	for i in datas.size():
		var bu := BattleUnit.new(datas[i], 1 if i == 3 else 0)
		units.append(bu)
		s.line(bu).turns = turns[i]
	return [s, units]


func pool_and_rule() -> void:
	# 3 take part (King, Co-Captain, Vessel), the enemy does not: 100 / 3 = 33 each, the remainder is dropped
	var a := manual_summary(100, BattleController.Outcome.WON, [3, 1, 2, 5])
	var s: BattleSummary = a[0]
	ExperienceSystem.distribute(s)
	eq(s.participants.size(), 3, "three participants")
	ok(not s.participants.has(a[1][3]), "enemies never take part")
	eq(s.exp_each, 33, "100 / 3 = 33")
	for i in 3:
		eq(a[1][i].data.exp, 33, "unit %d got its share" % i)
		eq(s.line(a[1][i]).exp_gained, 33, "recorded")
	eq(a[1][3].data.exp, 0, "the enemy gets nothing")
	ExperienceSystem.distribute(s)
	eq(a[1][0].data.exp, 33, "distributing twice does nothing")
	# a unit that never started a turn is not used
	a = manual_summary(90, BattleController.Outcome.WON, [2, 0, 1, 1])
	s = a[0]
	ExperienceSystem.distribute(s)
	eq([s.participants.size(), s.exp_each], [2, 45], "the idle Co-Captain is excluded: 90 / 2")
	eq(a[1][1].data.exp, 0, "idle unit: no XP")
	# a vessel counts like anyone else
	ok(s.participants.has(a[1][2]), "vessels share the XP")
	# only a victory pays
	for outcome in [BattleController.Outcome.LOST, BattleController.Outcome.ONGOING]:
		a = manual_summary(100, outcome, [1, 1, 1, 1])
		ExperienceSystem.distribute(a[0])
		eq([a[0].exp_each, a[1][0].data.exp, a[1][0].data.total_exp], [0, 0, 0], "no XP unless won (%d)" % outcome)
	# an empty pool, nobody took part
	a = manual_summary(0, BattleController.Outcome.WON, [1, 1, 1, 1])
	ExperienceSystem.distribute(a[0])
	eq(a[0].exp_each, 0, "empty pool")
	a = manual_summary(100, BattleController.Outcome.WON, [0, 0, 0, 3])
	ExperienceSystem.distribute(a[0])
	eq([a[0].participants.size(), a[0].exp_each], [0, 0], "nobody took part")
	eq(ExperienceSystem.share(7, 2), 3, "integer share")
	eq(ExperienceSystem.share(5, 0), 0, "no participants")
	# a big share levels several times and the summary says so
	a = manual_summary(1000, BattleController.Outcome.WON, [1, 0, 0, 0])
	ExperienceSystem.distribute(a[0])
	var king: BattleUnit = a[1][0]
	eq([king.data.level, king.data.exp], [8, 90], "1000 XP: levels cost 100+110+...+160 = 910, 90 left")
	var l: BattleSummary.UnitLine = a[0].line(king)
	eq([l.level_before, l.level_after, l.level_ups.size()], [1, 8, 7], "level-ups recorded")
	ok(a[0].describe(king).contains("+1000 XP") and a[0].describe(king).contains("Lv 1 → 8"), "describe: %s" % a[0].describe(king))


func play(b: BattleController, who: BattleUnit) -> void:
	while b.current != who:
		if b.current != null:
			b.end_turn()
		b.next_turn()


func real_battle() -> void:
	var b := BattleController.new()
	add_child(b)
	b.setup(board())
	var kd := make(KingData, "King", 10) as KingData
	var cd := make(CoCaptainData, "Cap", 1) as CoCaptainData  # too slow to ever get a turn
	var vd := make(VesselData, "Wisp", 30) as VesselData
	vd.fade_turns = 5
	var king := b.deployment.deploy_king(kd, Vector2i(5, 5))
	var cap := b.deployment.deploy_co_captain(cd, Vector2i(2, 2))
	b.deployment.place_relic(RelicItem.new(), Vector2i(6, 6))
	var foes: Array[BattleUnit] = []
	var rewards := [40, 30, 50]
	for i in 3:
		var e := make(EnemyData, "Foe %d" % i, 1) as EnemyData
		e.exp_reward = rewards[i]
		var bu := b.add_enemy(e, [Vector2i(5, 4), Vector2i(4, 4), Vector2i(6, 4)][i])
		bu.hp = 1
		foes.append(bu)
	b.start()
	b.next_turn()
	ok(b.summon_vessel(king, vd, Vector2i(6, 6)) != null, "King summons a vessel")
	b.end_turn()  # waits
	var wisp := b.deployment.unit_of(vd)
	play(b, wisp)  # the vessel takes a turn
	b.end_turn()
	play(b, king)
	var r := b.perform(king, BattleAction.attack(), Vector2i(5, 4))
	eq(r.hits.size(), 3, "the burst hits all three foes")
	eq(b.outcome, BattleController.Outcome.WON, "won")
	# no XP mid-combat: the pool fills, the units gain nothing yet
	eq(b.summary.exp_pool, 120, "pool: 40 + 30 + 50")
	eq(b.summary.enemies_defeated, 3, "three defeated")
	eq([kd.exp, kd.total_exp, vd.exp, cd.exp], [0, 0, 0, 0], "nobody has XP before the battle ends")
	var s := b.finish(PartyRoster.new())
	eq(s.participants.size(), 2, "King and vessel took turns; the Co-Captain did not")
	ok(s.participants.has(king) and s.participants.has(wisp) and not s.participants.has(cap), "who took part")
	eq(s.exp_each, 60, "120 / 2")
	eq([kd.exp, kd.total_exp, vd.exp, vd.total_exp], [60, 60, 60, 60], "King and vessel each got 60")
	eq([cd.exp, cd.total_exp], [0, 0], "the idle Co-Captain got none")
	# a second battle for the King: 60 + 60 = 120 -> level 2
	kd.add_exp(40)
	eq([kd.level, kd.exp], [2, 0], "100 reached: level 2")
	b.queue_free()


func persistence() -> void:
	var g := SaveGame.new_game()
	var king := g.roster.king
	king.stats.level = 1
	king.stats.exp = 0
	king.stats.total_exp = 0
	king.add_exp(250)
	var vessel := g.roster.vessels()[1]
	vessel.add_exp(30)
	var text := JSON.stringify(SaveCodec.encode(g), "", true)
	var back := SaveCodec.decode(JSON.parse_string(text))
	ok(back.ok and back.warnings.is_empty(), "decodes cleanly")
	var bk := back.game.roster.king
	eq([bk.level, bk.exp, bk.total_exp, bk.exp_to_next_level], [3, 40, 250, 120], "level, XP and lifetime XP survive")
	eq([back.game.roster.vessels()[1].level, back.game.roster.vessels()[1].exp], [1, 30], "vessel XP survives")
	eq(JSON.stringify(SaveCodec.encode(back.game), "", true), text, "round trip is identical")
	# saved XP is kept consistent with the level
	var data := SaveCodec.encode(g)
	data.king.stats.exp = 99999
	eq(SaveCodec.decode(data).game.roster.king.exp, 119, "XP is clamped below the next level's cost")
	data.king.stats.level = 99
	data.king.stats.exp = 50
	eq(SaveCodec.decode(data).game.roster.king.exp, 0, "no XP at level 99")
	data.king.stats.total_exp = -5
	eq(SaveCodec.decode(data).game.roster.king.total_exp, 0, "lifetime XP never negative")
	# a version 1 save (no XP fields, level 0 allowed) loads and is upgraded
	var old := SaveCodec.encode(g)
	old["version"] = 1
	for u in [old.king] + old.king.vessels + old.co_captains:
		u.stats.erase("exp")
		u.stats.erase("total_exp")
	old.king.stats.level = 0
	var up := SaveCodec.decode(old)
	ok(up.ok, "a version 1 save still loads: %s" % up.error)
	eq([up.game.roster.king.level, up.game.roster.king.exp, up.game.roster.king.total_exp], [1, 0, 0], "level 0 becomes 1; XP starts at 0")
	eq(up.game.roster.co_captains[0].level, g.roster.co_captains[0].level, "other levels unchanged")
	eq(SaveCodec.decode({"version": 3}).error.contains("newer version"), true, "a newer version is refused")
	# the full battle path: XP is awarded in finish_battle and autosaved
	for f in DirAccess.get_files_at("user://test_saves_exp") if DirAccess.dir_exists_absolute("user://test_saves_exp") else PackedStringArray():
		DirAccess.remove_absolute("user://test_saves_exp/" + f)
	var game := SaveGame.new_game()
	var kd := game.roster.king
	var b := BattleController.new()
	add_child(b)
	b.setup(board())
	var kb := b.deployment.deploy_king(kd, Vector2i(5, 5))
	var e := make(EnemyData, "Foe", 1) as EnemyData
	e.exp_reward = 150
	var fb := b.add_enemy(e, Vector2i(5, 4))
	fb.hp = 1
	b.start()
	b.next_turn()
	b.perform(kb, BattleAction.attack(), Vector2i(5, 4))
	var sum := CampaignFlow.finish_battle(game, b, &"first")
	eq(sum.exp_each, 150, "a sole participant takes the whole pool")
	eq([kd.level, kd.exp, kd.total_exp], [10, 150, 150], "level 10 needs 190: 150 XP is kept toward level 11")
	var loaded := SaveSystem.load_slot(SaveSystem.AUTOSAVE)
	ok(loaded.ok, "autosaved")
	eq([loaded.game.roster.king.level, loaded.game.roster.king.exp, loaded.game.roster.king.total_exp], [kd.level, kd.exp, kd.total_exp], "the autosave holds the new level and XP")
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
	b.queue_free()


func ui() -> void:
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	var texts := []
	for n in b.find_children("*", "Label", true, false):
		texts.append(n.text)
	ok(texts.any(func(t): return t.contains("Aldric  ·  King  ·  Lv 10") and t.contains("XP 0 / 190")), "commander row shows level and XP")
	ok(texts.any(func(t): return t.contains("Ashen Squire  ·  Vessel\nLv 1  ·  XP 0 / 100")), "vessel row shows level and XP")
	b.queue_free()
