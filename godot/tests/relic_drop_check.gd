extends Node
## Headless: every defeated enemy leaves the party a relic with a random skill (owner, Nov 2026). The relic goes into the inventory, is equipped at the base
## and its skill is usable in battle; defeating an enemy teaches nobody a skill; the skill's rank follows the chapter.
## godot --headless --path godot res://tests/relic_drop_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	DamageFormula.legacy_numbers()
	ranks()
	await in_battle()
	print("relic drop checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func ranks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for chapter in [1, 3, 6, 7, 9, 10, 15]:
		var top := Crucible.player_top_rank(chapter)
		var highest := 0
		var seen := {}
		for i in 600:
			var r := RelicDrop.make(chapter, rng)
			ok(r.skill != null and r.display_name == r.skill.display_name + RelicDrop.NAME_SUFFIX, "a relic carries a skill and is named after it")
			highest = maxi(highest, r.skill.rank)
			seen[r.skill.category] = true
		ok(highest <= top, "chapter %d: no skill above the chapter's top rank (%d <= %d)" % [chapter, highest, top])
		if chapter >= 7:
			ok(highest >= top - 1, "chapter %d: the higher ranks do appear (%d)" % [chapter, highest])
		ok(seen.size() >= 4, "chapter %d: several proficiencies (%d)" % [chapter, seen.size()])


func make(cls, name: String, speed := 6) -> UnitData:
	var d: UnitData = cls.new()
	d.display_name = name
	d.stats = CharacterStats.new()
	d.stats.speed = speed
	d.stats.base_max_hp = 50
	d.stats.attack = 30
	d.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	d.loadout.weapon_style.geometry = TacticalMath.Geometry.ROOK
	d.skill_tree = SkillTree.new() if d is KingData or d is CoCaptainData else null
	return d


func in_battle() -> void:
	var rows := []
	for y in 8:
		rows.append(" ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"])))
	var b := BattleController.new()
	add_child(b)
	b.setup(TacticalGrid.from_rows(rows))
	b.miss_chance = 0.0
	b.crit_scale = 0.0
	b.drop_rng.seed = 5
	var kd := make(KingData, "King", 10) as KingData
	var king := b.deployment.deploy_king(kd, Vector2i(2, 2))
	var foes: Array[BattleUnit] = []
	for i in 3:
		foes.append(b.add_enemy(make(EnemyData, "Foe %d" % i, 1) as EnemyData, Vector2i(2, 3 + i)))
	var dropped: Array = []
	b.relic_dropped.connect(func(r, from): dropped.append([r, from]))
	b.start()
	b.next_turn()
	var learned_before := kd.skill_tree.learned_skills().size()
	foes[0].hp = 1
	var res := b.perform(king, BattleAction.attack(), foes[0].cell)
	ok(res.ok and foes[0].is_down(), "the first foe is defeated")
	eq(dropped.size(), 1, "a relic dropped at once")
	ok(dropped[0][1] == foes[0] and dropped[0][0].skill != null, "it carries a skill")
	eq(b.summary.relics_secured.size(), 1, "and is in the summary")
	# a second knockout by a status (not a hit) drops one too, and nobody drops twice
	foes[1].hp = 0
	b.unit_knocked_out.emit(foes[1])
	b.unit_knocked_out.emit(foes[1])
	eq(dropped.size(), 2, "a knockout by any means drops one relic, once")
	b.unit_knocked_out.emit(king)
	eq(dropped.size(), 2, "the party's own units drop nothing")
	foes[2].hp = 0
	b.unit_knocked_out.emit(foes[2])
	eq(dropped.size(), 3, "three foes, three relics")
	eq(kd.skill_tree.learned_skills().size(), learned_before, "defeating enemies teaches nobody a skill")
	ok(kd.skill_tree.active_study() == null, "and starts no study")
	var roster := PartyRoster.new()
	roster.king = kd
	var s := b.finish(roster)
	eq(s.relics_secured.size(), 3, "the summary holds three relics")
	eq(roster.relic_inventory.size(), 3, "all three are in the inventory")
	# equipped at the base
	var relic: RelicItem = roster.relic_inventory[0]
	eq(RosterManager.equip_relic(roster, kd, EquipmentLoadout.Slot.RELIC_SLOT_1, relic), "", "the relic can be equipped")
	eq(roster.relic_inventory.size(), 2, "it leaves the inventory")
	# and its skill is usable in a battle
	var b2 := BattleController.new()
	add_child(b2)
	b2.setup(TacticalGrid.from_rows(rows))
	var king2 := b2.deployment.deploy_king(kd, Vector2i(2, 2))
	b2.add_enemy(make(EnemyData, "Far", 1) as EnemyData, Vector2i(7, 7))
	b2.start()
	b2.next_turn()
	ok(b2.skills_of(king2).has(relic.skill), "the equipped relic's skill is usable in battle")
	ok(b2.actions(king2).any(func(a): return a.skill == relic.skill), "and appears among the unit's actions")
