extends Node
## Headless: chapter eight (the Crown): five plain defeat-all-enemies battles, rank D and C enemy skills, honorable royal defenders, the world chain after Vespera, the unchanged
## party (seven, nobody recruited), the story canon (no Reave, no Elowen, no grave, no explanation) and the cliffhanger at the throne room's doors.
## godot --headless --path godot res://tests/crown_check.tscn
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
	SaveSystem.dir = "user://test_saves_crown"
	maps_and_foes()
	world()
	story()
	await party()
	print("crown checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps_and_foes() -> void:
	var with_c := 0
	for n in range(1, 6):
		var map := Terrain.load_map(Crown.MAPS[n])
		eq(map.w, 16, "map %d (%s): depth 16" % [n, Crown.NAMES[n]])
		ok(map.d >= 22 and map.d <= 28, "map %d: %d wide" % [n, map.d])
		var s := Crown.setup(n)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "map %d: everyone starts on open ground" % n)
		ok(s.rules.is_empty() and s.objective == "Defeat all enemies" and s.max_summons == 6 and s.relics.size() == 3, "map %d: a plain defeat-all-enemies battle, normal summoning" % n)
		ok(s.enemies.size() >= 7 and not s.opening_line.is_empty(), "map %d: %d defenders and an opening bark" % [n, s.enemies.size()])
	for kind in Crown.KINDS:
		var e: EnemyData = Crown.enemy(kind, 3, 1)
		ok(e.skills.all(func(sk): return sk.rank <= SkillData.Rank.C) and e.skills.any(func(sk): return sk.rank == SkillData.Rank.D or sk.rank == SkillData.Rank.C), "%s: rank D and C skills" % Crown.KINDS[kind].name)
		if e.skills.any(func(sk): return sk.rank == SkillData.Rank.C):
			with_c += 1
		ok(UnitLook.sheet_for(e) != "", "%s has a sheet" % Crown.KINDS[kind].name)
	ok(with_c * 10 >= Crown.KINDS.size() * 7, "rank C is common among the defenders (%d of %d kinds)" % [with_c, Crown.KINDS.size()])
	ok(Crown.KINDS.aldren.skills.has("Battle Hymn") and Crown.KINDS.aldren.skills.has("Fortify"), "Captain Aldren lifts the allies near him")
	for stage in ["crown_hill", "crown_street", "crown_hall"]:
		ok(Terrain.load_map("res://samples/%s.json" % stage).w == 16, "scene stage %s exists" % stage)


func world() -> void:
	var c := CampaignState.new()
	ok(not c.is_area_unlocked(&"capital"), "the capital is locked at first")
	for m in ["wrath", "judgment", "mheart", "bwstay", "exgeneral", "vstoll"]:
		WorldData.clear_map(c, m)
	ok(c.is_area_unlocked(&"capital"), "clearing the Last Toll opens the capital")
	eq(WorldData.map_state(c, "cwhighway"), "mission", "its first battle is the next mission")
	eq(WorldData.scene_for(c, "cwhighway", "pre"), "cw_hill", "chapter eight opens on the hill")
	for id in ["cwhighway", "cwouter", "cwoath", "cwcity", "cwgates"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)
	eq(CrownStory.SCENES.cw_hill.next, "cw_b1_pre", "the hill leads into the patrol")
	eq(CrownStory.SCENES.cw_b4_post.next, "cw_king", "the King's private scene follows Battle 4")
	eq(CrownStory.SCENES.cw_b5_post.next, "cw_throne", "the throne room doors follow Battle 5")
	ok(not CrownStory.SCENES.cw_throne.has("next"), "chapter eight ends at the doors")


func _text() -> String:
	var t := ""
	for key in CrownStory.SCENES:
		for st in CrownStory.SCENES[key].steps:
			for part in st:
				if part is String:
					t += part + "\n"
	return t


func story() -> void:
	var t := _text()
	for word in ["Reave", "Elowen", "princess", "Princess", "conspiracy", "grave", "alive again"]:
		ok(not t.contains(word), "chapter eight never says \"%s\"" % word)
	ok(t.contains("Alive?") and t.contains("Riders were sent weeks ago. None of them reached you."), "the King wants him alive and the invitations never arrived")
	ok(t.contains("Whatever you believe he's done... he is not the man you think."), "the commander's warning is there")
	ok(t.contains("Then remember that when you get them.") and t.contains("Withdraw the remaining soldiers from the streets."), "Lyra's line and the King's order are there")
	ok(not t.contains("give_") and not t.contains("joins the party"), "nobody joins in chapter eight")
	var last: Array = CrownStory.SCENES.cw_throne.steps[CrownStory.SCENES.cw_throne.steps.size() - 1]
	eq(last[0], "title", "the chapter ends on its title")
	ok(String(last[1]) == "CHAPTER EIGHT COMPLETE", "the chapter-complete card")
	# the defenders are honourable: the after scenes show them down or retreating, none dead
	for key in ["cw_b1_post", "cw_b2_post", "cw_b3_post", "cw_b5_post"]:
		var s := JSON.stringify(CrownStory.SCENES[key].steps)
		ok(s.contains("\"hit\"") or s.contains("\"ko\""), "%s shows the defenders beaten, not slaughtered" % key)
		ok(not s.contains("fadeout") , "%s: no defender fades away as if dead" % key)


func party() -> void:
	var g := Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
	var names: Array = g.roster.vessels().map(func(v): return v.display_name)
	for n in ["Bram", "Merc", "Gideon", "Kaelen", "Seraphine"]:
		ok(names.has(n), "%s is in the party" % n)
	ok(not names.has("Cassian Vale") and not names.has("Cassian"), "Cassian is not recruited")
	ok(g.roster.co_captains.any(func(c): return c.display_name == "Lyra"), "Lyra is the Co-Captain")
	BattleStage.pending_game = g
	BattleStage.pending_setup = Crown.setup(5)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	eq(s.battle.deployment.summons_left(), 6, "Battle 5: six summons")
	ok(s.battle.deployment.owned_vessels.size() >= 5 and s.battle.deployment.owned_vessels.any(func(v): return v.display_name == "Seraphine"), "Battle 5: the whole company can be summoned")
	s.queue_free()
	await get_tree().process_frame
	eq(g.roster.vessels().size(), names.size(), "nothing was added or lost by the chapter")
