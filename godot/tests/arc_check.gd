extends Node
## Headless: the final arc (chapters twelve to fifteen): twenty defeat-all-enemies battles, the chapter chain (11 -> 12 -> 13 -> 14 -> 15 -> the ending), the new enemy
## variants and factions, Vaelor's last stand, Reave and Elowen fought together and both surviving, Cassian joining, the story canon (the reveals at the right chapter, the
## lovers devoted, the King alive and reforming) and the true ending with the credits.
## godot --headless --path godot res://tests/arc_check.tscn
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
	SaveSystem.dir = "user://test_saves_arc"
	battles()
	world()
	story()
	await final_battle()
	await party()
	print("arc checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func battles() -> void:
	var total := 0
	for ch in [12, 13, 14, 15]:
		for n in range(1, 6):
			total += 1
			var map := Terrain.load_map(FinalArc.map_path(ch, n))
			eq(map.w, 16, "%d-%d (%s): depth 16" % [ch, n, FinalArc.CH[ch][n - 1]])
			var s := FinalArc.setup(ch, n)
			var grid := TacticalGrid.from_map(map)
			ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "%d-%d: everyone starts on open ground" % [ch, n])
			ok(s.objective.begins_with("Defeat all enemies") and s.max_summons == 6 and s.relics.size() == 3, "%d-%d: defeat all enemies, normal summoning" % [ch, n])
			ok(s.enemies.size() >= 4 and s.enemies.size() <= 9 and not s.opening_line.is_empty(), "%d-%d: %d foes and a bark" % [ch, n, s.enemies.size()])
			ok(WorldData.setup_for("a%d_%d" % [ch, n], 1, false) != null, "a%d_%d starts from the world map" % [ch, n])
	eq(total, 20, "twenty final-arc battles")
	for want in ["Revolutionary Swordsman", "Revolutionary Archer", "Revolutionary Duelist", "Revolutionary Battle Mage", "Revolutionary Heavy Infantry", "Revolutionary Champion",
			"Revolutionary Commander", "Falcon Guard Elite Honor Guard", "Falcon Guard Commander", "Reave", "Elowen", "Commander Vaelor"]:
		ok(FinalArc.KINDS.values().any(func(k): return k.name == want), "the variant exists: " + want)
	for k in ["fheavy", "fcav", "fmage", "fstd"]:
		ok(FinalArc.kind(k).name.begins_with("Falcon Guard"), "Falcon Guard %s is in rotation" % k)
	var rev: EnemyData = FinalArc.enemy("rsword", 13, 2, 1)
	ok(UnitLook.tint_for(rev) == UnitLook.REVOLT_TINT and UnitLook.tint_for(FinalArc.enemy("felite", 15, 4, 1)) == UnitLook.FALCON_TINT, "revolutionaries and the Falcon Guard look apart from each other and from the royal troops")
	# Vaelor: the same name and look each time, yielding in 12-5 and 15-2
	for pair in [[12, 5], [15, 2]]:
		var s := FinalArc.setup(pair[0], pair[1])
		ok(s.flee.has("Commander Vaelor") and s.flee_style == "yield" and s.objective.contains("Vaelor"), "%d-%d: Vaelor yields, never dies" % pair)
	eq(UnitLook.sheet_for(FinalArc.enemy("vaelor3", 15, 2, 1)), UnitLook.sheet_for(Falcon.enemy("vaelor", 3, 1)), "Vaelor keeps his look from chapter eleven")
	# enemies unlock the same ranks as the player, bosses one up
	for key in FinalArc.KINDS:
		var e: EnemyData = FinalArc.enemy(key, 15, 3, 1)
		ok(e.skills.any(func(sk): return sk.rank >= SkillData.Rank.B), "%s carries a rank B or higher skill" % e.display_name)
	ok(FinalArc.enemy("elowen", 15, 5, 1).skills.any(func(sk): return sk.rank == SkillData.Rank.S), "Elowen (a boss) reaches rank S")


func world() -> void:
	var c := CampaignState.new()
	for m in ["wrath", "judgment", "mheart", "bwstay", "exgeneral", "vstoll", "cwgates", "pking", "alast"]:
		WorldData.clear_map(c, m)
	ok(not c.is_area_unlocked(&"heir"), "chapter twelve is closed until chapter eleven ends")
	for pair in [["fdead", &"heir"], ["a12_5", &"divided"], ["a13_5", &"lovers"], ["a14_5", &"hollowmark"]]:
		ok(WorldData.clear_map(c, pair[0]).has(pair[1]), "clearing %s opens %s" % pair)
	for pair in [["a12_1", "c12_open"], ["a13_1", "c13_open"], ["a14_1", "c14_open"], ["a15_1", "c15_open"]]:
		eq(WorldData.scene_for(c, pair[0], "pre"), pair[1], "%s opens its chapter" % pair[0])
	eq(WorldData.UNLOCKED_BY_CLEARING.get("a15_5", []), [], "the last battle opens nothing: the story is complete")
	for pair in [["c12_reveal", "divided"], ["c13_final", "lovers"], ["c14_final", "hollowmark"]]:
		ok(FinalStory.SCENES[pair[0]].steps.any(func(st): return st[0] == "unlock" and st[1] == pair[1]), "%s unlocks the next chapter" % pair[0])
	# the ending chain
	var chain := ["c15_b5_post", "c15_father", "c15_kingdom", "c15_village", "c15_epilogues", "c15_first_stone"]
	for i in chain.size() - 1:
		eq(FinalStory.SCENES[chain[i]].get("next", ""), chain[i + 1], "%s leads to %s" % [chain[i], chain[i + 1]])
	ok(not FinalStory.SCENES.c15_first_stone.has("next"), "the first stone is the last scene")
	var last: Dictionary = FinalStory.SCENES.c15_first_stone
	var titles: Array = last.steps.filter(func(st): return st[0] == "title").map(func(st): return st[1])
	ok(titles.has("HOLLOWMARK TACTICS") and titles.has("THE END") and titles.has("CREDITS"), "the true ending and the credits roll")
	ok(not JSON.stringify(last).contains("STORY CONTINUES") and not JSON.stringify(last).contains("unlock"), "no false ending, no further chapter")


func _text(prefix: String) -> String:
	var t := ""
	for key in FinalStory.SCENES:
		if not String(key).begins_with(prefix):
			continue
		for st in FinalStory.SCENES[key].steps:
			for part in st:
				if part is String:
					t += part + "\n"
	return t


func story() -> void:
	var t12 := _text("c12")
	var t13 := _text("c13")
	var t14 := _text("c14")
	var t15 := _text("c15")
	ok(t12.contains("Elowen?") and t12.contains("I was.") and t12.contains("So did you."), "chapter twelve reveals that Elowen is alive")
	ok(not t12.contains("I planned it.") and not t12.contains("I gave the soldiers their form"), "chapter twelve does not yet say who planned the massacre")
	ok(t13.contains("Your village was meant to turn the kingdom against its King.") and t13.contains("You surviving was never part of the plan."), "chapter thirteen: Reave planned it, Alaric was never the target")
	ok(t13.contains("Understanding isn't forgiving."), "Lyra's choice")
	ok(t14.contains("I gave the soldiers their form. I knew what they were sent to do.") and t14.contains("Together."), "chapter fourteen: Elowen admits it; the lovers stay together")
	ok(t14.contains("I regret the suffering. I don't regret the cause."), "Reave does not repent")
	ok(t15.contains("I called it duty.") and t15.contains("It was a choice."), "Vaelor answers for his choice")
	ok(t15.contains("Together?") and t15.contains("Always.") and t15.contains("Build."), "the last summoners, and Alaric's last word")
	ok(t15.contains("I love you too, Father.") and t15.contains("That doesn't change what you've done."), "the King and Elowen: love, not absolution")
	var all := t12 + t13 + t14 + t15
	for word in ["demon", "ancient god", "mind-controlled", "controlled her", "betray"]:
		ok(not all.contains(word), "no secret villain or betrayal: \"%s\"" % word)
	for line in ["That cannot be.", "My daughter.", "I buried her.", "She said I already knew it.", "Your oath burned my village.", "You shouldn't have come here.",
			"I wish I knew.", "Then you're going to be disappointed.", "I didn't know you existed.", "It's the world we inherited.", "I need to hear it from her.",
			"Hello, Father.", "I came to your grave every week.", "I never asked you to.", "Then you haven't learned anything.", "I will not look away from what she's become.",
			"People willing to follow you without being ordered.", "Don't become accustomed to them.", "Do you want to stop?", "Then we finish what we started.",
			"I'm trying to appreciate the craftsmanship before someone hits me.", "Build something better.", "Then stop burning the people who have to live in it.",
			"You really are remarkable.", "If I believed it was necessary.", "I cannot defend that.", "You can surrender.", "I was going to say we came rather close.",
			"You'd leave the future to the people?", "Shouldn't that be what you wanted?", "I thought I had lost you forever.", "But I can make sure this place isn't forgotten."]:
		ok(all.contains(line), "the owner's line is played: " + line.left(48))
	ok(JSON.stringify(FinalStory.SCENES.c14_cassian.steps).contains("give_cassian"), "Cassian joins in chapter fourteen")


func final_battle() -> void:
	var s5 := FinalArc.setup(15, 5)
	var names: Array = s5.enemies.map(func(e): return e[0].display_name)
	ok(names.has("Reave") and names.has("Elowen"), "Reave and Elowen are both on the field")
	ok(s5.flee.has("Reave") and s5.flee.has("Elowen") and s5.flee_style == "yield", "both yield (incapacitated), neither dies")
	ok(s5.rules.boss_summon.unit == "Elowen" and s5.rules.boss_summon.has("max"), "Elowen summons, within a limit")
	ok(not FinalArc.enemy("reave", 15, 5, 1).skills.is_empty() and FinalArc.KINDS.reave.skills.has("Feinting Lunge"), "Reave fights as a duelist, with no summoning")
	BattleStage.pending_game = FinalArc.recruit_cassian(Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))))
	BattleStage.pending_setup = s5
	var st: BattleStage = load("res://scenes/battle.tscn").instantiate()
	st.enemy_delay = 1000.0
	st.animate = false
	add_child(st)
	await get_tree().process_frame
	var el: BattleUnit = null
	for e in st.battle.enemies:
		if e.data.display_name == "Elowen":
			el = e
	ok(el != null and st.battle.fleeing.has(el), "Elowen is set to yield in the real battle")
	var before := st.battle.enemies.size()
	for r in [3, 6, 9, 12, 15]:
		st.scenario.on_round(r)
		await get_tree().process_frame
	ok(st.battle.enemies.size() > before and st.battle.enemies.size() <= before + 3, "she calls her vessels, at most three (%d -> %d)" % [before, st.battle.enemies.size()])
	st.queue_free()
	await get_tree().process_frame


func party() -> void:
	var g := FinalArc.recruit_cassian(Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))))
	var names: Array = g.roster.vessels().map(func(v): return v.display_name)
	for n in ["Bram", "Merc", "Gideon", "Kaelen", "Seraphine", "Cassian Vale"]:
		ok(names.has(n), "%s is in the party" % n)
	ok(not names.has("Reave") and not names.has("Elowen") and not names.has("Commander Vaelor"), "no antagonist is recruited")
	var again := FinalArc.recruit_cassian(g).roster.vessels().size()
	eq(again, names.size(), "Cassian joins once")
	await get_tree().process_frame
