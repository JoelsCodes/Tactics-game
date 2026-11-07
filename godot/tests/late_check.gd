extends Node
## Headless: chapters six (the Ashen Expanse) and seven (Vespera): ten maps, plain defeat-all-enemies battles, rank D and C enemy skills, common rank C summon stones,
## the world-map chain after Bellwether, Cassian who never joins, Seraphine who joins once as an ordinary vessel, and the story canon (no Reave, no Elowen, no explanation).
## godot --headless --path godot res://tests/late_check.tscn
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
	SaveSystem.dir = "user://test_saves_late"
	maps_and_foes()
	world()
	canon()
	seraphine()
	stones()
	await battle_smoke()
	print("late checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _sets() -> Array:
	return [["expanse", Expanse], ["vespera", Vespera]]


func maps_and_foes() -> void:
	for pair in _sets():
		var kinds: Dictionary = pair[1].KINDS
		for n in range(1, 6):
			var map := Terrain.load_map(pair[1].MAPS[n])
			eq(map.w, 16, "%s %d: depth 16" % [pair[0], n])
			ok(map.d >= 18 and map.d <= 26, "%s %d: %d wide" % [pair[0], n, map.d])
			var s: BattleSetup = pair[1].setup(n)
			var grid := TacticalGrid.from_map(map)
			ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "%s %d: everyone starts on open ground" % [pair[0], n])
			ok(s.rules.is_empty() and s.objective == "Defeat all enemies" and s.max_summons == 6 and s.relics.size() == 3, "%s %d: a plain defeat-all-enemies battle with normal summoning" % [pair[0], n])
			ok(not s.opening_line.is_empty(), "%s %d: an opening bark" % [pair[0], n])
		var with_c := 0
		for kind in kinds:
			var e: EnemyData = pair[1].enemy(kind, 3, 1)
			ok(e.skills.all(func(s): return s.rank <= Crucible.enemy_top_rank(Crucible.chapter_of(String(e.id)), kinds[kind].get("boss", false))) and e.skills.any(func(s): return s.rank >= SkillData.Rank.D or true), "%s: %s within the chapter's ranks" % [pair[0], kinds[kind].name])
			ok(e.skills.any(func(s): return s.rank == SkillData.Rank.D or s.rank == SkillData.Rank.C), "%s: %s has a rank D or C skill" % [pair[0], kinds[kind].name])
			if e.skills.any(func(s): return s.rank == SkillData.Rank.C):
				with_c += 1
			ok(UnitLook.sheet_for(e) != "", "%s has a sheet" % kinds[kind].name)
		ok(with_c * 10 >= kinds.size() * 6, "%s: rank C is common among the foes (%d of %d kinds)" % [pair[0], with_c, kinds.size()])
	ok(Expanse.KINDS.cassian.skills.has("Battle Hymn") and Vespera.KINDS.malrec.skills.has("Battle Hymn"), "the two bosses lift their allies (Battle Hymn)")
	for stage in ["expanse_academy", "archive", "palace", "vespera_city"]:
		ok(Terrain.load_map("res://samples/%s.json" % stage).w == 16, "scene stage %s exists" % stage)


func world() -> void:
	var c := CampaignState.new()
	ok(not c.is_area_unlocked(&"ashen") and not c.is_area_unlocked(&"vespera"), "both places are locked at first")
	for m in ["wrath", "judgment", "mheart", "bwstay"]:
		WorldData.clear_map(c, m)
	ok(c.is_area_unlocked(&"ashen") and not c.is_area_unlocked(&"vespera"), "clearing Bellwether opens the Ashen Expanse")
	eq(WorldData.scene_for(c, "exash", "pre"), "ex_opening", "chapter six opens on the old battlefield")
	for m in ["exash", "exgate", "exlesson", "exprice", "exgeneral"]:
		WorldData.clear_map(c, m)
	ok(c.is_area_unlocked(&"vespera"), "clearing the Unbowed General opens Vespera")
	eq(WorldData.scene_for(c, "vsstreets", "pre"), "vs_arrival", "chapter seven opens at the silent towers")
	for id in ["exash", "exgate", "exlesson", "exprice", "exgeneral", "vsstreets", "vscemetery", "vscatacombs", "vschoir", "vstoll"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)
	eq(ExpanseStory.SCENES.ex_b3_post.next, "ex_archive", "the archive follows the lesson")
	eq(ExpanseStory.SCENES.ex_b5_post.next, "ex_decision", "Cassian's decision follows the duel")
	eq(ExpanseStory.SCENES.ex_decision.next, "ex_king", "the King's scene follows")
	eq(ExpanseStory.SCENES.ex_king.next, "ex_leaving", "then the road")
	eq(VesperaStory.SCENES.vs_b5_post.next, "vs_decision", "Seraphine's decision follows the last toll")
	eq(VesperaStory.SCENES.vs_decision.next, "vs_archive", "then the archive")
	eq(VesperaStory.SCENES.vs_archive.next, "vs_king", "then the King")
	eq(VesperaStory.SCENES.vs_king.next, "vs_leaving", "then the road")
	ok(not ExpanseStory.SCENES.ex_leaving.has("next") and not VesperaStory.SCENES.vs_leaving.has("next"), "each chapter ends on its last scene")


func _text(scenes: Dictionary) -> String:
	var t := ""
	for key in scenes:
		for st in scenes[key].steps:
			for part in st:
				if part is String:
					t += part + "\n"
	return t


func canon() -> void:
	# godot/STORY_CANON.md: the conspiracy stays hidden through chapter seven
	for pair in [["six", _text(ExpanseStory.SCENES)], ["seven", _text(VesperaStory.SCENES)]]:
		for word in ["Reave", "Elowen", "princess", "Princess", "conspiracy", "summoned the dead soldiers"]:
			ok(not pair[1].contains(word), "chapter %s never says \"%s\"" % [pair[0], word])
	var six := _text(ExpanseStory.SCENES)
	ok(six.contains("Find out who gave the order.") and six.contains("either someone revived a forgotten regiment, or someone wanted you to recognize it."), "chapter six keeps Cassian's questions open")
	ok(not six.contains("the King ordered") and not six.contains("the King did not"), "chapter six does not settle who gave the order")
	ok(_text(VesperaStory.SCENES).contains("this says he died a hundred and twelve years ago") and _text(VesperaStory.SCENES).contains("Someone brought him back."), "chapter seven shows the second clue")
	ok(six.contains("They say he can call the dead.") and six.contains("Please."), "the King's scenes hint at his grief and nothing more")
	# Cassian never joins: nothing in chapter six recruits anyone, and no function exists for it
	ok(not six.contains("give_") and not Expanse.new().has_method("recruit"), "Cassian does not join in chapter six")
	eq(ExpanseStory.SCENES.ex_leaving.steps[ExpanseStory.SCENES.ex_leaving.steps.size() - 1][0], "title", "chapter six ends on its title")


func seraphine() -> void:
	var g := Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))
	var before := g.roster.vessels().size()
	ok(not g.roster.vessels().any(func(v): return v.display_name == "Seraphine"), "Seraphine is not in the party before the end of chapter seven")
	Vespera.recruit(g)
	Vespera.recruit(g)
	eq(g.roster.vessels().size(), before + 1, "she joins once")
	var v: VesselData = g.roster.vessels().filter(func(x): return x.display_name == "Seraphine").front()
	ok(v.fade_turns == Crucible.gideon().fade_turns, "she follows the normal vessel rules (an ordinary Fade Clock)")
	var names: Array = [v.loadout.relic_slot_1.skill.display_name, v.loadout.relic_slot_2.skill.display_name]
	ok(names.has("Battle Hymn") and names.has("Lullaby"), "support kit: a hymn that lifts the company and a lullaby that dulls the foe (%s)" % [names])
	ok(v.stats.magic > v.stats.attack * 3 and v.stats.base_max_hp < Crucible.gideon().stats.base_max_hp, "a caster with low durability")
	ok(g.roster.co_captains.any(func(c): return c.display_name == "Lyra"), "Lyra is still the Co-Captain")
	ok(g.roster.vessels().any(func(x): return x.display_name == "Gideon") and g.roster.vessels().any(func(x): return x.display_name == "Kaelen"), "nobody already recruited is lost")
	eq(CharacterLook.base_of(v), "sorc", "her stand-in sheet")


func stones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for pair in _sets():
		var c := 0
		for i in 600:
			if SummonStone.make(rng, pair[1].STONE_D_CHANCE, pair[1].STONE_C_CHANCE).skill.rank == SkillData.Rank.C:
				c += 1
		ok(c > 200 and c < 340, "%s: rank C stones are common (%d of 600)" % [pair[0], c])


func battle_smoke() -> void:
	for pair in [["expanse", Expanse], ["vespera", Vespera]]:
		BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
		BattleStage.pending_setup = pair[1].setup(5)
		var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
		s.enemy_delay = 1000.0
		s.animate = false
		add_child(s)
		await get_tree().process_frame
		ok(s.battle.enemies.size() == 7 and s.battle.deployment.summons_left() == 6, "%s 5 loads with its boss group and six summons" % pair[0])
		ok(s.battle.deployment.owned_vessels.any(func(v): return v.display_name == "Seraphine"), "%s: Seraphine can be summoned once recruited" % pair[0])
		s.queue_free()
		await get_tree().process_frame
