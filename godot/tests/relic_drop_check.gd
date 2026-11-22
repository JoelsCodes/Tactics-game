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
	stacking()
	await learning()
	one_per_skill()
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


## The same move stacks in lists as x2, x3 (owner, Nov 2026).
func stacking() -> void:
	var jab := SkillLibrary.find("Quick Jab")
	var hop := SkillLibrary.find("Hop")
	var rs: Array[RelicItem] = []
	for sk in [jab, hop, jab, jab, hop]:
		var r := RelicItem.new()
		r.skill = sk
		r.display_name = sk.display_name + RelicDrop.NAME_SUFFIX
		rs.append(r)
	var stacks := RelicDrop.stacks(rs)
	eq(stacks.size(), 2, "five relics of two moves make two stacks")
	eq([stacks[0].count, stacks[1].count], [3, 2], "x3 and x2")
	eq(stacks[0].label, "Quick Jab Relic  x3", "the label shows the count")
	eq(stacks[1].label, "Hop Relic  x2", "and the second one")
	ok(stacks[0].relics.size() == 3 and stacks[0].relic == rs[0], "a stack keeps its relics, the first one leads")
	var single := RelicDrop.stacks([rs[0]])
	eq(single[0].label, "Quick Jab Relic", "a lone relic has no count")
	var roster := PartyRoster.new()
	roster.relic_inventory = rs
	eq(roster.relic_stacks().size(), 2, "the roster groups its inventory")


## An equipped relic trains its skill when used; at level 1 it is learned for good, the relic breaks and the skill stays without it (owner, Nov 2026).
func learning() -> void:
	var rows := []
	for y in 8:
		rows.append(" ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"])))
	var jab := SkillLibrary.find("Quick Jab")
	var kd := make(KingData, "King", 10) as KingData
	kd.stats.will = 20
	var carried := RelicItem.new()
	carried.skill = jab
	carried.display_name = "Quick Jab Relic"
	var spare := RelicItem.new()
	spare.skill = jab
	spare.display_name = "Quick Jab Relic"
	var roster := PartyRoster.new()
	roster.king = kd
	roster.relic_inventory = [carried, spare] as Array[RelicItem]
	eq(roster.relic_stacks()[0].label, "Quick Jab Relic  x2", "two of the same move: x2")
	eq(RosterManager.equip_relic(roster, kd, EquipmentLoadout.Slot.RELIC_SLOT_1, roster.relic_stacks()[0].relic), "", "one of the stack is equipped")
	eq(roster.relic_stacks()[0].label, "Quick Jab Relic", "the stack is down to one")
	var b := BattleController.new()
	add_child(b)
	b.setup(TacticalGrid.from_rows(rows))
	b.miss_chance = 0.0
	b.crit_scale = 0.0
	var king := b.deployment.deploy_king(kd, Vector2i(2, 2))
	var foe := b.add_enemy(make(EnemyData, "Dummy", 1) as EnemyData, Vector2i(2, 3))
	foe.data.stats.base_max_hp = 500
	foe.data.stats.defense = 0
	foe.hp = foe.max_hp()
	b.start()
	b.next_turn()
	ok(kd.skill_tree.mastery_of(jab) == null, "nothing is learned yet")
	var broken: Array = []
	b.relic_broken.connect(func(u, r): broken.append([u, r]))
	var uses := 0
	var learned_at := -1
	king.facing = Vector2i(0, 1)
	for i in 150:
		foe.hp = foe.max_hp()
		king.sp = king.max_sp()
		b.acted = false
		var res := b.perform(king, BattleAction.use(jab), foe.cell)
		if not res.ok:
			break
		uses += 1
		if res.skill_learned != null:
			learned_at = uses
			ok(res.relic_broken == carried, "the result names the relic that broke")
			break
	ok(learned_at > 2 and learned_at < 120, "using the equipped relic's skill trains it until it is learned (%d uses)" % learned_at)
	ok(kd.skill_tree.is_learned(jab), "it is learned for good")
	ok(kd.loadout.relic_slot_1 == null, "the relic that carried it broke: the slot is empty")
	eq(broken.size(), 1, "one relic broke")
	ok(b.summary.relics_broken.has(carried), "the summary lists it")
	ok(roster.relic_inventory.has(spare) and roster.relic_inventory.size() == 1, "the spare copy is untouched")
	ok(b.skills_of(king).has(jab), "the skill stays usable without the relic")
	ok(b.actions(king).any(func(a): return a.skill == jab), "and is among the actions")
	# once mastered it is kept: another use does not break anything more, and a fresh battle still has it
	var back := SaveCodec.decode(SaveCodec.encode(SaveGame.new_game(roster)))
	ok(back.ok and back.game.roster.king.skill_tree.is_learned(jab), "and it survives a save and a load (a library skill loads as the library's own object)")
	var fresh := RelicItem.new()
	fresh.skill = jab
	back.game.roster.king.loadout.relic_slot_2 = fresh
	var b3 := BattleController.new()
	add_child(b3)
	b3.setup(TacticalGrid.from_rows(rows))
	var k3 := b3.deployment.deploy_king(back.game.roster.king, Vector2i(2, 2))
	b3.add_enemy(make(EnemyData, "Far", 1) as EnemyData, Vector2i(7, 7))
	b3.start()
	b3.next_turn()
	eq(b3.skills_of(k3).filter(func(sk): return sk.display_name == "Quick Jab").size(), 1, "a new relic with a skill already learned does not list it twice")


## A unit carries one relic per skill at a time (owner, Nov 2026); another unit can carry its own copy.
func one_per_skill() -> void:
	var jab := SkillLibrary.find("Quick Jab")
	var hop := SkillLibrary.find("Hop")
	var mk := func(sk: SkillData) -> RelicItem:
		var r := RelicItem.new()
		r.skill = sk
		r.display_name = sk.display_name + RelicDrop.NAME_SUFFIX
		return r
	var roster := PartyRoster.new()
	roster.king = make(KingData, "King") as KingData
	var other := make(CoCaptainData, "Other") as CoCaptainData
	roster.co_captains.append(other)
	var a: RelicItem = mk.call(jab)
	var b: RelicItem = mk.call(jab)
	var c: RelicItem = mk.call(hop)
	var d: RelicItem = mk.call(jab)
	roster.relic_inventory = [a, b, c, d] as Array[RelicItem]
	eq(RosterManager.equip_relic(roster, roster.king, EquipmentLoadout.Slot.RELIC_SLOT_1, a), "", "the first Quick Jab relic is equipped")
	ok(RosterManager.equip_relic(roster, roster.king, EquipmentLoadout.Slot.RELIC_SLOT_2, b) != "", "a second relic with the same skill is refused on the same unit")
	ok(roster.relic_inventory.has(b) and roster.king.loadout.relic_slot_2 == null, "nothing changed")
	eq(RosterManager.equip_relic(roster, roster.king, EquipmentLoadout.Slot.RELIC_SLOT_2, c), "", "a relic with another skill goes into the other slot")
	eq(RosterManager.equip_relic(roster, roster.king, EquipmentLoadout.Slot.RELIC_SLOT_1, b), "", "swapping a relic for another copy of the same skill in its own slot is fine")
	eq(RosterManager.equip_relic(roster, other, EquipmentLoadout.Slot.RELIC_SLOT_1, d), "", "another unit can carry its own copy at the same time")
