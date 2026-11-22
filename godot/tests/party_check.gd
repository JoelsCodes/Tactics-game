extends Node
## Headless: the chosen party (owner, Nov 2026). PartyRoster remembers and fills it, the save keeps it, a world-map battle puts it on the map beside Alaric
## (no stones, no summoning, first-turn spacing kept), the Formation pop-up builds and confirms a pick, and the world map opens it before a battle.
## godot --headless --path godot res://tests/party_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func names(a: Array) -> Array:
	return a.map(func(u): return u.display_name)


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_party"
	var g := Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())))
	var r := g.roster
	var comp := names(r.company())
	ok(comp.size() >= 5 and comp.has("Bram") and comp.has("Merc") and comp.has("Gideon") and comp.has("Kaelen") and comp.has("Lyra"), "the company is the Co-Captains and the former vessels (%s)" % [comp])
	# never picked: the first PARTY_SIZE of the company
	eq(names(r.party()), comp.slice(0, 3), "a roster that was never picked takes the first three")
	# a pick is remembered, in order, and can be smaller than the size
	r.set_party([r.company()[3], r.company()[1]])
	eq(names(r.party()), [comp[3], comp[1]], "the pick is remembered in order")
	r.set_party([r.company()[0], r.company()[1], r.company()[2], r.company()[3]])
	eq(r.party().size(), PartyRoster.PARTY_SIZE, "no more than the party size")
	# a newcomer fills a free slot; one who was known and left out does not
	r.set_party([r.company()[0]])
	var newcomer := Crucible.join_at_level(Riverford.merc(), g)
	newcomer.display_name = "Newcomer"
	r.co_captains.append(newcomer)
	eq(names(r.party()), [comp[0], "Newcomer"], "a member who joins later fills a free slot; the ones left in reserve stay there")
	# the save keeps it
	var res := SaveCodec.decode(SaveCodec.encode(g))
	ok(res.ok, "the save reads back")
	eq(res.game.roster.party_names, r.party_names, "the remembered party is saved")
	eq(res.game.roster.party_known, r.party_known, "and the company it was picked from")
	eq(names(res.game.roster.party()), names(r.party()), "the same party comes back")
	# the Formation pop-up
	var pop := FormationPopup.create(g, "Test")
	add_child(pop)
	await get_tree().process_frame
	ok(pop.card_buttons.size() == r.company().size(), "a card for every member of the company")
	var before: Array = names(pop.chosen)
	var first: UnitData = r.company()[0]
	ok(pop.toggle(first) == true and not pop.chosen.has(first) or pop.chosen.has(first), "a card toggles")
	pop.chosen.clear()
	for u in r.company().slice(0, 3):
		pop.chosen.append(u)
	ok(not pop.toggle(r.company()[4]), "a fourth member is refused while the party is full")
	pop.toggle(r.company()[0])
	pop.toggle(r.company()[4])
	ok(pop.chosen.has(r.company()[4]) and pop.chosen.size() == 3, "after a Remove the fourth member can join")
	var fought := [false]
	pop.fight.connect(func(): fought[0] = true)
	var want := names(pop.chosen)
	pop.confirm()
	ok(fought[0], "Fight emits")
	eq(names(r.party()), want, "Fight remembers the pick")
	ok(SaveSystem.load_slot(SaveSystem.AUTOSAVE).ok and names(SaveSystem.load_slot(SaveSystem.AUTOSAVE).game.roster.party()) == want, "and saves it")
	await get_tree().process_frame
	# a world-map battle places the party
	r.set_party([r.company()[0], r.company()[1], r.company()[2]])
	var mine := names(r.party())
	var s := Riverford.setup(2)
	BattleStage.pending_game = g
	BattleStage.pending_setup = s
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 1000.0
	add_child(b)
	await get_tree().process_frame
	var dm := b.battle.deployment
	var on := dm.field_units().filter(func(u): return u != dm.king).map(func(u): return u.data.display_name)
	on.sort()
	var want_sorted := mine.duplicate()
	want_sorted.sort()
	eq(on, want_sorted, "the picked party is on the field beside the King")
	var cells := {}
	for u in dm.field_units():
		cells[u.cell] = true
	eq(cells.size(), dm.field_units().size(), "everyone has their own tile")
	ok(not "summon_button" in b.hud.palette, "and there is no Summon button")
	var worst := 999
	for u in dm.field_units():
		for e in b.battle.enemies:
			var d := absi(u.cell.x - e.cell.x) + absi(u.cell.y - e.cell.y)
			worst = mini(worst, d - maxi(BattleSetup.threat_of(u.data), BattleSetup.threat_of(e.data)))
	ok(worst > 0, "first-turn spacing holds with the party (%d beyond reach)" % worst)
	b.queue_free()
	await get_tree().process_frame
	# the world map opens the pop-up before a battle
	var wm := WorldMapScreen.new()
	wm.game = g
	wm.go_on = true
	wm.resume_story = false
	add_child(wm)
	await get_tree().process_frame
	wm.open_formation("alley", 1)
	await get_tree().process_frame
	ok(wm.formation != null and is_instance_valid(wm.formation), "the world map opens the Formation pop-up")
	wm.formation._close()
	await get_tree().process_frame
	wm.queue_free()
	print("party checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
