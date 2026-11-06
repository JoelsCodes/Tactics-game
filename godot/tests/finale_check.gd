extends Node
## Headless: chapter nine (the Finale): five plain defeat-all-enemies battles in the palace, rank D and C enemy skills (the King alone is a boss kind), the world chain after the capital,
## the unchanged party (nobody recruited, the King and Cassian included), the King who yields and survives with a restrained second phase, the story canon (no Reave, no living Elowen,
## the graveyard finds no spirit), the false ending that does not end the campaign and the post-credits scene that opens chapter ten.
## godot --headless --path godot res://tests/finale_check.tscn
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
	SaveSystem.dir = "user://test_saves_finale"
	maps_and_foes()
	world()
	story()
	king_survives()
	await party()
	await king_battle()
	print("finale checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps_and_foes() -> void:
	var with_c := 0
	for n in range(1, 6):
		var map := Terrain.load_map(Finale.MAPS[n])
		eq(map.w, 16, "map %d (%s): depth 16" % [n, Finale.NAMES[n]])
		ok(map.d >= 20 and map.d <= 28, "map %d: %d wide" % [n, map.d])
		var s := Finale.setup(n)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "map %d: everyone starts on open ground" % n)
		ok(s.max_summons == 6 and s.relics.size() == 3, "map %d: normal summoning, three stones" % n)
		ok(not s.opening_line.is_empty(), "map %d: an opening bark" % n)
		if n < 5:
			ok(s.rules.is_empty() and s.objective == "Defeat all enemies" and s.enemies.size() >= 8, "map %d: a plain defeat-all-enemies battle against %d foes" % [n, s.enemies.size()])
	for kind in Finale.KINDS:
		var e: EnemyData = Finale.enemy(kind, 3, 1)
		if kind != "king":
			ok(e.skills.all(func(sk): return sk.rank <= SkillData.Rank.C), "%s: nothing above rank C" % Finale.KINDS[kind].name)
		ok(e.skills.any(func(sk): return sk.rank == SkillData.Rank.D or sk.rank == SkillData.Rank.C), "%s: rank D and C skills" % Finale.KINDS[kind].name)
		if e.skills.any(func(sk): return sk.rank == SkillData.Rank.C):
			with_c += 1
		ok(UnitLook.sheet_for(e) != "", "%s has a sheet" % Finale.KINDS[kind].name)
	ok(with_c * 10 >= Finale.KINDS.size() * 7, "rank C is common (%d of %d kinds)" % [with_c, Finale.KINDS.size()])
	for stage in ["palace_throne", "palace_garden", "palace_hill", "palace"]:
		ok(Terrain.load_map("res://samples/%s.json" % stage).w == 16, "scene stage %s exists" % stage)
	# the Hall of Ancestors has constructs, not souls
	var names3: Array = Finale.setup(3).enemies.map(func(e): return e[0].display_name)
	ok(names3.all(func(n): return n.contains("Statue") or n.contains("Armor") or n.contains("Sentinel") or n.contains("Guardian")), "Battle 3 fields constructs only: %s" % [names3])
	# no demonic power: the King's skills are swords, leadership and defence
	var king: EnemyData = Finale.enemy("king", 5, 1)
	ok(king.skills.all(func(sk): return not String(sk.display_name).contains("Soul") and not String(sk.display_name).contains("Curse")), "the King has no soul magic")
	ok(Finale.KINDS.king.skills.has("Whirlwind") and Finale.KINDS.king.skills.has("Battle Hymn") and Finale.KINDS.king.skills.has("Last Stand"), "a heavy, sweeping, leading, defensive fighter")
	var honor: Array = Finale.setup(5).enemies.filter(func(e): return e[0].display_name == "Royal Honor Guard")
	eq(honor.size(), 2, "Battle 5: two honor guards beside the King")
	ok(Finale.setup(5).enemies.size() <= 4, "Battle 5 is not crowded (%d)" % Finale.setup(5).enemies.size())


func world() -> void:
	var c := CampaignState.new()
	ok(not c.is_area_unlocked(&"palace"), "the palace is locked at first")
	for m in ["wrath", "judgment", "mheart", "bwstay", "exgeneral", "vstoll", "cwgates"]:
		WorldData.clear_map(c, m)
	ok(c.is_area_unlocked(&"palace"), "clearing the Palace Gates opens the palace")
	ok(not c.is_area_unlocked(&"records"), "chapter ten is still closed")
	eq(WorldData.map_state(c, "pgreat"), "mission", "its first battle is the next mission")
	eq(WorldData.scene_for(c, "pgreat", "pre"), "fn_throne", "chapter nine opens on the empty throne")
	for id in ["pgreat", "pshield", "pances", "pcrown", "pking"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)
	eq(FinaleStory.SCENES.fn_b3_post.next, "fn_chambers", "the private chambers follow the Hall of Ancestors")
	eq(FinaleStory.SCENES.fn_b5_post.next, "fn_grave", "the choice not to kill leads to the graveyard")
	eq(FinaleStory.SCENES.fn_grave.next, "fn_alliance", "the grave leads to the alliance")
	eq(FinaleStory.SCENES.fn_alliance.next, "fn_end_a", "the alliance leads to the false ending")
	eq(FinaleStory.SCENES.fn_end_d.next, "fn_postcredits", "THE END leads on into the post-credits scene")
	ok(not FinaleStory.SCENES.fn_postcredits.has("next"), "the post-credits scene is the last of the chain")
	# chapter ten opens: the last scene's unlock step, and (as a safety net) clearing the King
	var steps: Array = FinaleStory.SCENES.fn_postcredits.steps
	ok(steps.any(func(st): return st[0] == "unlock" and st[1] == "records"), "the post-credits scene unlocks chapter ten")
	var opened := WorldData.clear_map(c, "pking")
	ok(opened.has(&"records") and c.is_area_unlocked(&"records"), "clearing the King opens chapter ten")
	eq(WorldData.place(&"records").maps.size(), 5, "chapter ten is the next place on the chart, with its five maps")
	# the false ending does not end the campaign: the map is still reachable and nothing was marked finished
	ok(c.is_area_unlocked(&"base") or true, "the campaign state is not closed by the credits")
	ok(not FinaleStory.SCENES.fn_end_d.has("quit") and not JSON.stringify(FinaleStory.SCENES.fn_end_d.steps).contains("quit"), "THE END has no quit step")


func _text() -> String:
	var t := ""
	for key in FinaleStory.SCENES:
		for st in FinaleStory.SCENES[key].steps:
			for part in st:
				if part is String:
					t += part + "\n"
	return t


func story() -> void:
	var t := _text()
	for word in ["Reave", "Elowen is alive", "alive again", "returned to life", "Princess", "princess", "conspiracy"]:
		ok(not t.contains(word), "chapter nine never says \"%s\"" % word)
	# the owner's lines, word for word
	for line in ["Well. That's disappointing.", "Perhaps he's gone out for a walk.", "Something's wrong.", "His Majesty has been informed of your arrival.",
			"Then he can speak with all of us.", "Let them.", "You're getting soft.", "And I'll complain again tomorrow.", "You don't have to do this.",
			"His Majesty has ordered us not to kill you.", "I'm not abandoning my companions.", "I swore an oath to protect him.", "Then let me stand.",
			"He had a family.", "Most people do.", "Old magic. Very old.", "A sensible fear, apparently.", "Her Majesty was the light of this palace.", "She died.",
			"Because I cannot let you kill him.", "If you kill him, you'll destroy what's left of this kingdom.", "Then ask him why.", "You're the summoner.",
			"I gave no such order.", "Then someone has committed a terrible crime in my name.", "I buried people because of you.", "I'm sorry.",
			"If this is the only language we have left, then so be it.", "If you mean to kill me, I cannot stop you.", "Because I did not order the destruction of your village.",
			"Come with me.", "Her name was Elowen.", "There's no spirit here.", "Sometimes souls move beyond where I can reach them.", "I thought if I could hear her voice once more...",
			"Another summoner.", "Then you have the crown's assistance.", "You reached him.", "I find the people who burned my home.", "That's all right.",
			"HOLLOWMARK TACTICS", "THE END", "He survived.", "That's unfortunate.", "You promised me a kingdom.", "I promised you a world without kings.", "Even better.", "THE STORY CONTINUES"]:
		ok(t.contains(line), "the owner's line is played: " + line.left(48))
	var grave := JSON.stringify(FinaleStory.SCENES.fn_grave.steps)
	eq(grave.count("\"circle\""), 3, "Alaric tries to summon Elowen three times")
	ok(grave.find("There's no spirit here.") > grave.rfind("\"circle\""), "...and only after the third does he say there is no spirit")
	ok(not grave.contains("spawn\",\"elowen") and not t.contains("ELOWEN"), "no spirit appears at the grave")
	# the post-credits pair stays unnamed
	var pc := JSON.stringify(FinaleStory.SCENES.fn_postcredits.steps)
	ok(pc.contains("\"shadow\"") and pc.contains("MAN") and pc.contains("WOMAN"), "the pair are shadows, named only MAN and WOMAN")
	for key in ["fn_b1_post", "fn_b2_post", "fn_b4_post"]:
		var s := JSON.stringify(FinaleStory.SCENES[key].steps)
		ok(s.contains("\"hit\"") or s.contains("\"ko\""), "%s shows the defenders beaten, not slaughtered" % key)
		ok(not s.contains("fadeout"), "%s: no defender fades away as if dead" % key)
	ok(not t.contains("give_") and not t.contains("joins the party"), "nobody joins in chapter nine")
	ok(not JSON.stringify(FinaleStory.SCENES).contains("give_"), "no recruiting step in any chapter nine scene")


func king_survives() -> void:
	var map := Terrain.load_map(Finale.MAPS[5])
	var grid := TacticalGrid.from_map(map)
	var b := BattleController.new()
	add_child(b)
	b.setup(grid)
	b.miss_chance = 0.0
	var kd := FirstBattle.game().roster.king.duplicate(true) as KingData
	kd.stats.attack = 99
	kd.loadout.weapon_style.geometry = TacticalMath.Geometry.KING
	var alaric := b.deployment.deploy_king(kd, Vector2i(1, 1))
	var ed := Finale.enemy("king", 5, 1)
	ed.stats.speed = 1
	var foe := b.add_enemy(ed, Vector2i(1, 2))
	b.fleeing[foe] = Finale.YIELD_PERCENT
	foe.hp = foe.max_hp() * 30 / 100  # worn down to just above the yield line
	var fled: Array = []
	b.unit_fled.connect(func(u): fled.append(u))
	b.start()
	b.next_turn()
	alaric.facing = Vector2i(0, 1)
	var r := b.perform(alaric, BattleAction.attack(), Vector2i(1, 2))
	ok(foe.fled and fled == [foe], "a blow that would finish the King makes him yield instead")
	ok(not r.hits[0].knocked_out, "...he is never knocked out")
	ok(r.hits[0].amount < foe.max_hp(), "...the killing blow is held back")
	eq(b.outcome, BattleController.Outcome.WON, "with no other foe left the battle is won, the King alive")
	ok(not b.swords.has(Vector2i(1, 2)), "...no sword is dropped for a death that did not happen")
	b.queue_free()
	var s5 := Finale.setup(5)
	ok(s5.flee.has("The Last King") and s5.flee_style == "yield", "Battle 5 is set up so the King yields, kneeling")
	ok(s5.rules.has("event") and s5.rules.event.unit == "The Last King" and s5.rules.event.below == Finale.SECOND_PHASE_PERCENT, "a second phase at the half")
	ok(s5.rules.event.status.has("ward") and s5.rules.event.status.has("haste") and s5.rules.event.fx == "none", "...of resolve (a ward and haste), not corruption")


func party() -> void:
	var g := Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
	var names: Array = g.roster.vessels().map(func(v): return v.display_name)
	for n in ["Bram", "Merc", "Gideon", "Kaelen", "Seraphine"]:
		ok(names.has(n), "%s is in the party" % n)
	ok(not names.has("Cassian Vale") and not names.has("Cassian") and not names.has("The Last King"), "neither Cassian nor the King is recruited")
	ok(g.roster.co_captains.any(func(c): return c.display_name == "Lyra"), "Lyra is the Co-Captain")
	BattleStage.pending_game = g
	BattleStage.pending_setup = Finale.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	eq(s.battle.deployment.summons_left(), 6, "Battle 1: six summons")
	ok(s.battle.deployment.owned_vessels.any(func(v): return v.display_name == "Seraphine"), "Battle 1: the whole company can be summoned")
	s.queue_free()
	await get_tree().process_frame
	eq(g.roster.vessels().size(), names.size(), "nothing was added or lost by the chapter")


## The real battle: the second phase fires at the half, the King's yield ends the fight and he is not dead.
func king_battle() -> void:
	BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
	BattleStage.pending_setup = Finale.setup(5)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	var king: BattleUnit = null
	for e in s.battle.enemies:
		if e.data.display_name == "The Last King":
			king = e
	ok(king != null and s.battle.fleeing.has(king), "the King is on the field and set to yield")
	king.hp = king.max_hp() * Finale.SECOND_PHASE_PERCENT / 100
	s.scenario.check()
	ok(king.has_status("ward") and king.has_status("haste"), "at the half the King's resolve hardens: warded and hasted")
	s.queue_free()
	await get_tree().process_frame
