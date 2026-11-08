extends Node
## Headless: chapter eleven (the Falcon): five plain defeat-all-enemies battles against the Falcon Guard (rank D and C skills; Vaelor alone a boss kind), Vaelor's two fights (he yields and
## survives both, stronger the second time), the Falcon Guard's ten variants and their spectral tint, the world chain after Greyhaven's predecessor, the unchanged party, the story canon
## ("the rightful heir" points at the bloodline without naming anyone; Elowen is never named; Reave is never shown to have done anything) and the cliffhanger that opens chapter twelve.
## godot --headless --path godot res://tests/falcon_check.tscn
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
	SaveSystem.dir = "user://test_saves_falcon"
	maps_and_foes()
	world()
	story()
	vaelor()
	await party()
	print("falcon checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps_and_foes() -> void:
	var with_c := 0
	for n in range(1, 6):
		var map := Terrain.load_map(Falcon.MAPS[n])
		eq(map.w, 16, "map %d (%s): depth 16" % [n, Falcon.NAMES[n]])
		ok(map.d >= 22 and map.d <= 26, "map %d: %d wide" % [n, map.d])
		var s := Falcon.setup(n)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "map %d: everyone starts on open ground" % n)
		ok(s.rules.is_empty() and s.max_summons == 6 and s.relics.size() == 3, "map %d: no special rule, normal summoning" % n)
		ok(s.enemies.size() >= 6 and s.enemies.size() <= 9 and not s.opening_line.is_empty(), "map %d: %d foes (not overwhelming) and an opening bark" % [n, s.enemies.size()])
		ok(s.objective.begins_with("Defeat all enemies"), "map %d: defeat-all-enemies" % n)
	for kind in Falcon.KINDS:
		var e: EnemyData = Falcon.enemy(kind, 3, 1)
		if not Falcon.KINDS[kind].get("boss", false):
			ok(e.skills.all(func(sk): return sk.rank <= Crucible.enemy_top_rank(11, false)), "%s: nothing above the player's rank" % Falcon.KINDS[kind].name)
		ok(e.skills.any(func(sk): return sk.rank == SkillData.Rank.D or sk.rank == SkillData.Rank.C), "%s: rank D and C skills" % Falcon.KINDS[kind].name)
		if e.skills.any(func(sk): return sk.rank == SkillData.Rank.C):
			with_c += 1
		ok(UnitLook.sheet_for(e) != "", "%s has a sheet" % Falcon.KINDS[kind].name)
	ok(with_c * 10 >= Falcon.KINDS.size() * 6, "rank C is common (%d of %d kinds)" % [with_c, Falcon.KINDS.size()])
	ok(Terrain.load_map("res://samples/falcon_village.json").w == 16, "the Greyhaven scene stage exists")
	# the Falcon Guard variants the owner listed
	var names: Array = Falcon.KINDS.values().map(func(k): return k.name)
	for want in ["Falcon Guard Swordsman", "Falcon Guard Archer", "Falcon Guard Shield Soldier", "Falcon Guard Spearman", "Falcon Guard Heavy Infantry", "Falcon Guard Cavalry",
			"Falcon Guard Battle Mage", "Falcon Guard Honor Guard", "Falcon Guard Standard Bearer", "Commander Vaelor"]:
		ok(names.has(want), "the Falcon Guard variant exists: " + want)
	# visibly not the living soldiers of chapter eight
	var fg: EnemyData = Falcon.enemy("fsword", 1, 1)
	var living: EnemyData = Crown.enemy("infantry", 1, 1)
	ok(UnitLook.tint_for(fg) == UnitLook.FALCON_TINT and UnitLook.tint_for(living) == UnitLook.ENEMY_TINT, "the Falcon Guard carry a spectral tint the living royal soldiers do not")
	# who is on which field
	var n4: Array = Falcon.setup(4).enemies.map(func(e): return e[0].display_name)
	for want in ["Falcon Guard Heavy Infantry", "Falcon Guard Cavalry", "Falcon Guard Battle Mage", "Falcon Guard Archer", "Falcon Guard Standard Bearer"]:
		ok(n4.has(want), "Battle 4 fields " + want)
	var n2: Array = Falcon.setup(2).enemies.map(func(e): return e[0].display_name)
	ok(n2.has("Falcon Guard Spearman") and n2.has("Armored Field Construct") and n2.has("Falcon Guard Captain"), "Battle 2 mixes spearmen, constructs, beasts and a captain")
	ok(Falcon.KINDS.fstd.skills.has("Battle Hymn"), "the standard bearer lifts those around it")


func world() -> void:
	var c := CampaignState.new()
	for m in ["wrath", "judgment", "mheart", "bwstay", "exgeneral", "vstoll", "cwgates", "pking"]:
		WorldData.clear_map(c, m)
	ok(c.is_area_unlocked(&"records") and not c.is_area_unlocked(&"falcon"), "chapter eleven is closed until the Last Sentinel falls")
	WorldData.clear_map(c, "alast")
	ok(c.is_area_unlocked(&"falcon") and not c.is_area_unlocked(&"heir"), "clearing the Last Sentinel opens Greyhaven, not chapter twelve")
	eq(WorldData.map_state(c, "fashes"), "mission", "its first battle is the next mission")
	eq(WorldData.scene_for(c, "fashes", "pre"), "fl_report", "chapter eleven opens on the report from Greyhaven")
	for id in ["fashes", "ffarm", "ftower", "farmy", "fdead"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)
	eq(FalconStory.SCENES.fl_report.next, "fl_greyhaven", "the report leads to Greyhaven")
	eq(FalconStory.SCENES.fl_greyhaven.next, "fl_ashes_pre", "...and Greyhaven to the lane")
	eq(FalconStory.SCENES.fl_b1_post.next, "fl_survivors", "the soldier's words lead to the survivors")
	eq(FalconStory.SCENES.fl_survivors.next, "fl_reave_greyhaven", "...and Reave's relief column")
	eq(FalconStory.SCENES.fl_b3_post.next, "fl_king_response", "the King's response follows the Last Falcon")
	eq(FalconStory.SCENES.fl_b4_post.next, "fl_reave_offer", "Reave's offer follows the army")
	eq(FalconStory.SCENES.fl_b5_post.next, "fl_king_heir", "the King hears about the heir")
	eq(FalconStory.SCENES.fl_king_heir.next, "fl_reave_private", "Reave's private scene follows")
	eq(FalconStory.SCENES.fl_reave_private.next, "fl_final", "...and the last scene")
	ok(FalconStory.SCENES.fl_final.steps.any(func(st): return st[0] == "unlock" and st[1] == "heir"), "the last scene unlocks chapter twelve")
	var opened := WorldData.clear_map(c, "fdead")
	ok(opened.has(&"heir") and c.is_area_unlocked(&"heir"), "clearing the Dead King's Army opens chapter twelve")
	eq(WorldData.place(&"heir").maps.size(), 5, "chapter twelve (Silvermere) follows, with its five maps")
	var last: Array = FalconStory.SCENES.fl_final.steps[FalconStory.SCENES.fl_final.steps.size() - 2]
	ok(last[0] == "title" and String(last[1]) == "CHAPTER ELEVEN COMPLETE", "the chapter ends on its title card")


func _text() -> String:
	var t := ""
	for key in FalconStory.SCENES:
		for st in FalconStory.SCENES[key].steps:
			for part in st:
				if part is String:
					t += part + "\n"
	return t


func story() -> void:
	var t := _text()
	for word in ["Elowen", "princess", "Princess", "his daughter is alive", "returned to life", "Reave planned", "Reave burned", "Reave summoned", "his lover", "Elowen summoned"]:
		ok(not t.contains(word), "chapter eleven never says \"%s\"" % word)
	for line in ["Again?", "How many dead?", "We don't have a final count.", "The same soldiers?", "Then we stop them.", "You don't have to stay here.", "Someone stayed for me once.",
			"There is more than one claim to a crown.", "They said the crown had abandoned us.", "While wearing its colors?", "We meet again.", "So does bad news.",
			"Occasionally I do something useful.", "That sounds inconvenient.", "They were dead before they attacked.", "A summoner, then.", "Perhaps he's finally remembered he has a kingdom.",
			"Trying is a beginning.", "Whether it's enough is another question.", "An army that doesn't need roads or provisions.", "It still needs a summoner.",
			"And that summoner must be somewhere close enough to sustain them.", "You survived.", "I remember the village.", "I carried out my orders.", "My oath did not end with my death.",
			"Then perhaps it should have.", "You seek a name.", "Then we are not so different.", "I didn't burn a village.", "We cannot defend every village.", "Then defend the ones most at risk.",
			"The capital has walls. They do not.", "Whoever is doing this has been summoning for a long time.", "Longer than me?", "Almost certainly.", "You could have stayed in the palace.",
			"That's what makes you dangerous.", "People follow someone who acts.", "You can replace one King with another. The problem remains.", "A kingdom where no one inherits the right to rule.",
			"And how many people have to die to build it?", "Fewer than will die if nothing changes.", "That's not an answer.", "No. I suppose it isn't.", "You again.", "My duty remains.",
			"My duty is to the rightful heir.", "The rightful heir?", "You will go no further.", "Who is the heir?", "The bloodline survives.", "He said he served the rightful heir.",
			"The Falcon Guard served my ancestors.", "There are distant branches of the royal family.", "He knows the soldiers serve an heir.", "Then perhaps we should stop waiting.",
			"First, we give the people something to believe in.", "You think someone in the royal family summoned those soldiers?", "But it means someone wants the crown.",
			"To make sure no one else loses their home because of it.", "A name.", "CHAPTER ELEVEN COMPLETE"]:
		ok(t.contains(line), "the owner's line is played: " + line.left(48))
	ok(t.contains("rightful heir"), "\"the rightful heir\" is the chapter's mystery")
	ok(not JSON.stringify(FalconStory.SCENES).contains("give_"), "nobody joins in chapter eleven")
	ok(JSON.stringify(FalconStory.SCENES.fl_reave_private.steps).contains("\"shadow\""), "Reave's associate is an unnamed shadow")
	var heir := JSON.stringify(FalconStory.SCENES.fl_king_heir.steps)
	ok(not heir.contains("daughter") and not heir.contains("Elowen"), "the King does not think of his daughter")
	for key in ["fl_b1_post", "fl_b3_post", "fl_b5_post"]:
		ok(JSON.stringify(FalconStory.SCENES[key].steps).contains("\"ko\""), "%s shows the Falcon Guard beaten" % key)
	# Reave is generous in person: the relief column, a kneeling kindness, nothing worse
	ok(t.contains("volunteers carrying food and bandages"), "Reave is shown helping the survivors")



func vaelor() -> void:
	var s3 := Falcon.setup(3)
	var s5 := Falcon.setup(5)
	ok(s3.flee.has("Commander Vaelor") and s5.flee.has("Commander Vaelor"), "Vaelor yields in both of his battles: he is never destroyed")
	ok(s3.flee_style == "yield" and s5.flee_style == "yield", "...fading, not vanishing in smoke")
	ok(s3.objective.contains("including Vaelor") and s5.objective.contains("including Vaelor"), "both objectives name Vaelor")
	ok(not s3.flee_line.is_empty() and s3.flee_line[2] != s5.flee_line[2], "he says something different each time")
	eq(s5.flee_line[2], "The bloodline survives.", "his second fading word is the owner's line")
	var v3: EnemyData = Falcon.enemy("vaelor", 3, 1)
	var v5: EnemyData = Falcon.enemy("vaelor2", 5, 1)
	ok(v5.stats.base_max_hp > v3.stats.base_max_hp and v5.stats.attack > v3.stats.attack and v5.skills.size() > v3.skills.size(), "Vaelor is stronger and knows more in Battle 5")
	ok(v3.skills.any(func(sk): return sk.display_name == "Battle Hymn") and v5.skills.any(func(sk): return sk.display_name == "Phalanx"), "he lifts his soldiers (Battle Hymn), then commands a Phalanx")
	eq(UnitLook.sheet_for(v3), UnitLook.sheet_for(v5), "he looks the same in both battles")
	# a blow that would finish him makes him yield (the same mechanism as the King)
	var map := Terrain.load_map(Falcon.MAPS[5])
	var b := BattleController.new()
	add_child(b)
	b.setup(TacticalGrid.from_map(map))
	b.miss_chance = 0.0
	b.crit_scale = 0.0  # exact damage: no random critical hits
	var kd := FirstBattle.game().roster.king.duplicate(true) as KingData
	kd.stats.attack = 99
	kd.loadout.weapon_style.geometry = TacticalMath.Geometry.KING
	var alaric := b.deployment.deploy_king(kd, Vector2i(1, 1))
	v5.stats.speed = 1
	var foe := b.add_enemy(v5, Vector2i(1, 2))
	b.fleeing[foe] = Falcon.YIELD_PERCENT
	foe.hp = foe.max_hp() * 30 / 100
	b.start()
	b.next_turn()
	alaric.facing = Vector2i(0, 1)
	var r := b.perform(alaric, BattleAction.attack(), Vector2i(1, 2))
	ok(foe.fled and not r.hits[0].knocked_out, "a blow that would finish Vaelor makes him fade instead")
	eq(b.outcome, BattleController.Outcome.WON, "with no other foe left the battle is won, Vaelor unbroken")
	b.queue_free()


func party() -> void:
	var g := Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
	var names: Array = g.roster.vessels().map(func(v): return v.display_name)
	for n in ["Bram", "Merc", "Gideon", "Kaelen", "Seraphine"]:
		ok(names.has(n), "%s is in the party" % n)
	ok(not names.has("Cassian Vale") and not names.has("Vaelor") and not names.has("Commander Vaelor"), "neither Cassian nor Vaelor is a party member")
	BattleStage.pending_game = g
	BattleStage.pending_setup = Falcon.setup(3)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	eq(s.battle.deployment.summons_left(), 6, "Battle 3: six summons")
	var vael: BattleUnit = null
	for e in s.battle.enemies:
		if e.data.display_name == "Commander Vaelor":
			vael = e
	ok(vael != null and s.battle.fleeing.has(vael), "Vaelor is on the field and set to yield")
	s.queue_free()
	await get_tree().process_frame
	eq(g.roster.vessels().size(), names.size(), "nothing was added or lost by the chapter")
