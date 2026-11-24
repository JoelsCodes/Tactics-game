extends Node
## Headless: the party's items (Claude, Nov 2026; ConsumableItem, ItemBag, ItemCatalog, BattleController's item path, the ITEMS command).
## A Potion heals a neighbour by its amount and no further than full, takes the action, costs no SP and leaves the bag one fewer; nothing is used when
## there is none left or nobody it would help is in reach; an Ether restores SP; an Antidote cures poison and only reaches the poisoned; a Phoenix Down
## gets a knocked-out ally back on its feet and into the turn order; a thrown Firebomb hits every foe round the tile and never a friend, and can finish one
## (which wins the battle); a won battle drops war trophies into the bag; the roster keeps the bag through a save and gets the starter kit once; hidden finds
## lie away from the party, and a party unit that ends its turn on one finds its item.
## godot --headless --path godot res://tests/item_check.tscn
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
	DamageFormula.legacy_numbers(false)
	catalog()
	potion_and_ether()
	cures_and_revive()
	firebomb_and_trophies()
	roster_and_save()
	hidden_finds()
	print("item checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func board(n := 10) -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(n)
	row.fill("g0")
	for y in n:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func make(cls, name: String, speed := 6) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.speed = speed
	var s := WeaponStyle.new()
	s.geometry = TacticalMath.Geometry.ROOK
	s.reach = 1
	var w := WeaponItem.new()
	w.base_power = 8
	u.loadout = EquipmentLoadout.make(w, s)
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


func battle() -> BattleController:
	var b := BattleController.new()
	add_child(b)
	b.setup(board())
	b.miss_chance = 0.0
	b.crit_scale = 0.0
	b.bag = ItemBag.starter()
	return b


## The King's turn with a co-captain next to him and a foe far off.
func party() -> Array:
	var b := battle()
	var king := b.deployment.deploy_king(make(KingData, "King", 20) as KingData, Vector2i(2, 2))
	var cap := b.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 5) as CoCaptainData, Vector2i(2, 3))
	var foe := b.add_enemy(make(EnemyData, "Foe", 4) as EnemyData, Vector2i(8, 8))
	b.start()
	ok(b.next_turn() == king, "the King goes first")
	return [b, king, cap, foe]


func catalog() -> void:
	ok(ItemCatalog.all().size() >= 12, "a dozen or more items")
	var ids := {}
	for it in ItemCatalog.all():
		ok(not ids.has(it.id), "item ids are unique (%s)" % it.id)
		ids[it.id] = true
		ok(it.display_name != "" and it.description != "" and it.effect_text() != "", "%s has a name, a description and an effect line" % it.id)
		eq(it.item_type(), ItemResource.ItemType.CONSUMABLE, "%s is a consumable" % it.id)
	for id in ItemCatalog.STARTER:
		ok(ItemCatalog.get_item(id) != null, "starter item %s exists" % id)
	var remedy := ItemCatalog.get_item(&"remedy")
	for s in BattleUnit.NEGATIVE:
		ok(remedy.cures.has(s), "a Remedy cures %s" % s)


func potion_and_ether() -> void:
	var p := party()
	var b: BattleController = p[0]
	var king: BattleUnit = p[1]
	var cap: BattleUnit = p[2]
	var potion := BattleAction.use_item(ItemCatalog.get_item(&"potion"))
	ok(not b.highlights(king, potion).has(cap.cell), "nobody to heal: the Potion has no target at full HP")
	cap.hp = 3
	ok(b.highlights(king, potion).has(cap.cell), "a hurt neighbour can be given a Potion")
	ok(not b.highlights(king, potion).has(Vector2i(8, 8)), "nor out of reach")
	var before := b.bag.count(&"potion")
	var sp := king.sp
	var want := mini(potion.item.restore_for(cap), cap.max_hp() - 3)
	var r := b.perform(king, potion, cap.cell)
	ok(r.ok, "the Potion is used")
	eq(cap.hp, 3 + want, "it heals its amount")
	eq(b.bag.count(&"potion"), before - 1, "one fewer in the bag")
	eq(king.sp, sp, "it costs no SP")
	ok(b.acted, "it takes the action")
	ok(not b.perform(king, potion, cap.cell).ok, "no second action this turn")
	eq(BattleAction.use_item(potion.item).sp_cost(), 0, "items cost no SP")
	ok(not potion.is_attack() and potion.is_item(), "an item is not an attack")
	# never past full
	b.end_turn()
	while b.next_turn() != king:
		b.end_turn()
	cap.hp = cap.max_hp() - 1
	b.perform(king, BattleAction.use_item(ItemCatalog.get_item(&"x_potion")) if b.bag.count(&"x_potion") > 0 else potion, cap.cell)
	eq(cap.hp, cap.max_hp(), "healing stops at full")
	# Ether: SP back, not past full
	b.end_turn()
	while b.next_turn() != king:
		b.end_turn()
	king.sp = 0
	var ether := BattleAction.use_item(ItemCatalog.get_item(&"ether"))
	ok(b.highlights(king, ether).has(king.cell), "an item can be used on oneself")
	b.perform(king, ether, king.cell)
	eq(king.sp, mini(6, king.max_sp()), "an Ether restores 6 SP")
	# none left
	b.end_turn()
	while b.next_turn() != king:
		b.end_turn()
	b.bag.counts.erase(&"ether")
	king.sp = 0
	ok(not b.perform(king, ether, king.cell).ok, "nothing is used when the bag has none")
	eq(king.sp, 0, "and nothing happens")


func cures_and_revive() -> void:
	var p := party()
	var b: BattleController = p[0]
	var king: BattleUnit = p[1]
	var cap: BattleUnit = p[2]
	var anti := BattleAction.use_item(ItemCatalog.get_item(&"antidote"))
	ok(not b.highlights(king, anti).has(cap.cell), "an Antidote only reaches the poisoned")
	cap.add_status(BattleUnit.POISON, 3)
	cap.add_status(BattleUnit.SLEEP, 2)
	ok(b.highlights(king, anti).has(cap.cell), "a poisoned ally can be given one")
	ok(b.perform(king, anti, cap.cell).ok, "the Antidote is used")
	ok(not cap.has_status(BattleUnit.POISON), "poison is cured")
	ok(cap.has_status(BattleUnit.SLEEP), "sleep is not (that takes Smelling Salts)")
	b.end_turn()
	while b.next_turn() != king:
		b.end_turn()
	cap.hp = 0
	ok(not b.turns.upcoming(8).has(cap), "a knocked-out ally gets no turns")
	var potion := BattleAction.use_item(ItemCatalog.get_item(&"potion"))
	ok(not b.highlights(king, potion).has(cap.cell), "a Potion does not reach the fallen")
	var down := BattleAction.use_item(ItemCatalog.get_item(&"phoenix_down"))
	ok(b.highlights(king, down).has(cap.cell), "a Phoenix Down does")
	var r := b.perform(king, down, cap.cell)
	ok(r.ok and r.hits.size() == 1 and r.hits[0].revived, "the Phoenix Down revives")
	eq(cap.hp, maxi(1, cap.max_hp() / 4), "with a quarter of its HP")
	ok(not cap.has_status(BattleUnit.SLEEP), "and up on its feet with no ailment")
	ok(b.turns.upcoming(12).has(cap), "back in the turn order")


func firebomb_and_trophies() -> void:
	var b := battle()
	var king := b.deployment.deploy_king(make(KingData, "King", 20) as KingData, Vector2i(2, 2))
	var cap := b.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 5) as CoCaptainData, Vector2i(3, 4))
	var f1 := b.add_enemy(make(EnemyData, "Foe A", 4) as EnemyData, Vector2i(2, 5))
	var f2 := b.add_enemy(make(EnemyData, "Foe B", 4) as EnemyData, Vector2i(2, 4))
	b.start()
	ok(b.next_turn() == king, "the King's turn")
	var bomb := BattleAction.use_item(ItemCatalog.get_item(&"firebomb"))
	ok(b.highlights(king, bomb).has(Vector2i(2, 5)), "a Firebomb is thrown three tiles")
	ok(not b.highlights(king, bomb).has(Vector2i(2, 6)), "but no farther")
	var cap_hp := cap.hp
	var a := f1.hp
	var c := f2.hp
	var r := b.perform(king, bomb, Vector2i(2, 4))
	ok(r.ok, "the Firebomb is thrown")
	eq(f2.hp, maxi(0, c - 14), "the foe on the tile takes 14")
	eq(f1.hp, maxi(0, a - 14), "and the foe next to it")
	eq(cap.hp, cap_hp, "the ally next to it is spared")
	ok(r.hits.all(func(h): return not h.missed and not h.crit), "an item never misses and is never critical")
	f1.hp = 1
	f2.hp = 1
	b.end_turn()
	while b.next_turn() != king:
		b.end_turn()
	b.perform(king, bomb, Vector2i(2, 4))
	eq(b.outcome, BattleController.Outcome.WON, "a Firebomb can finish the fight")
	var roster := PartyRoster.new()
	b.bag = ItemBag.of(roster)
	var held := 0
	for id in roster.items:
		held += int(roster.items[id])
	var s := b.finish(roster)
	var found := 0
	for id in s.items_found:
		found += int(s.items_found[id])
		ok(ItemCatalog.get_item(id) != null, "a trophy is a real item")
	eq(found, 1, "a won battle against two foes leaves one item")
	var after := 0
	for id in roster.items:
		after += int(roster.items[id])
	eq(after, held + found, "the trophy goes into the roster's bag")
	ok(not ItemCatalog.trophies(RandomNumberGenerator.new(), 6).is_empty(), "trophies are drawn")
	var big := 0
	var tr := ItemCatalog.trophies(RandomNumberGenerator.new(), 6)
	for id in tr:
		big += int(tr[id])
	eq(big, 2, "five foes or more leave two")


func roster_and_save() -> void:
	var roster := PartyRoster.new()
	var bag := ItemBag.of(roster)
	ok(roster.items_given, "the roster is given the starter kit")
	eq(bag.count(&"potion"), int(ItemCatalog.STARTER[&"potion"]), "the kit's Potions are in it")
	bag.take(&"potion")
	var again := ItemBag.of(roster)
	eq(again.count(&"potion"), int(ItemCatalog.STARTER[&"potion"]) - 1, "the kit is given once: the bag is the roster's")
	bag.add(&"potion", 500)
	eq(bag.count(&"potion"), ItemCatalog.MAX_STACK, "a stack stops at %d" % ItemCatalog.MAX_STACK)
	bag.add(&"nonsense", 3)
	eq(bag.count(&"nonsense"), 0, "an unknown item cannot be added")
	var game := SaveGame.new()
	game.roster = roster
	var kd := make(KingData, "King") as KingData
	roster.king = kd
	var data := SaveCodec.encode(game)
	ok(data.has("items"), "the save holds the bag")
	var res := SaveCodec.decode(JSON.parse_string(JSON.stringify(data)))
	ok(res.ok and res.game != null, "the save loads (%s)" % res.error)
	if res.game != null:
		eq(int(res.game.roster.items.get(&"potion", 0)), ItemCatalog.MAX_STACK, "the Potions come back from the save")
		eq(int(res.game.roster.items.get(&"firebomb", 0)), int(ItemCatalog.STARTER[&"firebomb"]), "and the Firebombs")
		ok(res.game.roster.items_given, "the kit is not given again after loading")


func hidden_finds() -> void:
	var b := battle()
	var king := b.deployment.deploy_king(make(KingData, "King", 20) as KingData, Vector2i(1, 1))
	var foe := b.add_enemy(make(EnemyData, "Foe", 4) as EnemyData, Vector2i(9, 9))
	b.start()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cells := b.hide_treasures(2, rng)
	eq(cells.size(), 2, "two finds are hidden")
	for c in cells:
		ok(absi(c.x - 1) + absi(c.y - 1) >= 5, "a find lies away from the party (%s)" % c)
		ok(ItemCatalog.get_item(b.treasures[c]) != null, "a find is a real item")
		ok(c != foe.cell, "never under a unit")
	ok(absi(cells[0].x - cells[1].x) + absi(cells[0].y - cells[1].y) >= 4, "the finds are spread out")
	var found := []
	b.treasure_found.connect(func(u, c, it): found.append([u, c, it]))
	var target: Vector2i = cells[0]
	var id: StringName = b.treasures[target]
	var before := b.bag.count(id)
	ok(b.next_turn() == king, "the King's turn")
	b.grid.move_occupant(king, target)  # put him on it (the walk itself is the battle checks' business)
	king.cell = target
	b.end_turn()
	eq(b.bag.count(id), before + 1, "ending the turn on a find puts its item in the bag")
	ok(not b.treasures.has(target), "the find is gone")
	eq(found.size(), 1, "the find is announced")
	eq(int(b.summary.items_found.get(id, 0)), 1, "and counted in the summary")
	b.end_turn()
	ok(b.treasures.size() == 1, "the other find is still there")
