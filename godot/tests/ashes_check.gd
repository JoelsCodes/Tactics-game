extends Node
## Headless: chapter ten (Ashes of a Lie): five plain defeat-all-enemies battles on the Falcon Guard trail, rank D and C enemy skills (the Last Sentinel alone is a boss kind), the world
## chain after the palace, the unchanged party (nobody recruited), the story canon (Reave is introduced as a public figure and nothing proves him; Elowen is never named or shown; no document
## names the summoner), the King alive and accountable, and the cliffhanger that opens chapter eleven.
## godot --headless --path godot res://tests/ashes_check.tscn
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
	SaveSystem.dir = "user://test_saves_ashes"
	maps_and_foes()
	world()
	story()
	await party()
	print("ashes checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps_and_foes() -> void:
	var with_c := 0
	for n in range(1, 6):
		var map := Terrain.load_map(Ashes.MAPS[n])
		eq(map.w, 16, "map %d (%s): depth 16" % [n, Ashes.NAMES[n]])
		ok(map.d >= 22 and map.d <= 26, "map %d: %d wide" % [n, map.d])
		var s := Ashes.setup(n)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "map %d: everyone starts on open ground" % n)
		ok(s.rules.is_empty() and s.objective == "Defeat all enemies" and s.max_summons == 6 and s.relics.size() == 3 and s.flee.is_empty(), "map %d: a plain defeat-all-enemies battle, normal summoning" % n)
		ok(s.enemies.size() >= 5 and not s.opening_line.is_empty(), "map %d: %d foes and an opening bark" % [n, s.enemies.size()])
	eq(Ashes.setup(5).enemies.filter(func(e): return e[0].display_name == "The Last Sentinel").size(), 1, "Battle 5 has the Last Sentinel")
	for kind in Ashes.KINDS:
		var e: EnemyData = Ashes.enemy(kind, 3, 1)
		if kind != "lsent":
			ok(e.skills.all(func(sk): return sk.rank <= SkillData.Rank.C), "%s: nothing above rank C" % Ashes.KINDS[kind].name)
		ok(e.skills.any(func(sk): return sk.rank == SkillData.Rank.D or sk.rank == SkillData.Rank.C), "%s: rank D and C skills" % Ashes.KINDS[kind].name)
		if e.skills.any(func(sk): return sk.rank == SkillData.Rank.C):
			with_c += 1
		ok(UnitLook.sheet_for(e) != "", "%s has a sheet" % Ashes.KINDS[kind].name)
	ok(with_c * 10 >= Ashes.KINDS.size() * 6, "rank C is common (%d of %d kinds)" % [with_c, Ashes.KINDS.size()])
	for stage in ["ashes_town", "ashes_memorial", "ashes_night", "archive", "palace"]:
		ok(Terrain.load_map("res://samples/%s.json" % stage).w == 16, "scene stage %s exists" % stage)
	var names4: Array = Ashes.setup(4).enemies.map(func(e): return e[0].display_name)
	ok(names4.all(func(n): return n.begins_with("Falcon Guard")), "Battle 4 fields Falcon Guard vessels only: %s" % [names4])
	ok(Ashes.setup(1).enemies.all(func(e): return not e[0].display_name.contains("Falcon")), "the deserters of Battle 1 are not the Falcon Guard (nobody's agents)")


func world() -> void:
	var c := CampaignState.new()
	for m in ["wrath", "judgment", "mheart", "bwstay", "exgeneral", "vstoll", "cwgates"]:
		WorldData.clear_map(c, m)
	ok(c.is_area_unlocked(&"palace") and not c.is_area_unlocked(&"records"), "the palace is open; chapter ten is not yet")
	WorldData.clear_map(c, "pking")
	ok(c.is_area_unlocked(&"records") and not c.is_area_unlocked(&"falcon"), "clearing the King opens chapter ten, not chapter eleven")
	eq(WorldData.map_state(c, "aroad"), "mission", "its first battle is the next mission")
	eq(WorldData.scene_for(c, "aroad", "pre"), "an_morning", "chapter ten begins the morning after, with the guest chamber")
	for id in ["aroad", "aapproach", "asentinels", "astolen", "alast"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)
	eq(AshesStory.SCENES.an_morning.next, "an_offer", "the morning leads to the King's offer")
	eq(AshesStory.SCENES.an_offer.next, "an_archives", "...and the archives")
	ok(not AshesStory.SCENES.an_archives.has("next"), "the archives lead into Battle 1")
	eq(WorldData.scene_for(c, "aapproach", "pre"), "an_speech", "Reave's speech comes before Battle 2")
	eq(AshesStory.SCENES.an_speech.next, "an_reave", "...and the meeting follows it")
	eq(AshesStory.SCENES.an_b2_post.next, "an_memorial", "the memorial chamber follows the Approach")
	eq(AshesStory.SCENES.an_b3_post.next, "an_cost", "the lie's cost follows the sentinels")
	eq(AshesStory.SCENES.an_b5_post.next, "an_king", "the King's accountability follows the last battle")
	eq(AshesStory.SCENES.an_king.next, "an_reave_private", "Reave's private scene follows")
	eq(AshesStory.SCENES.an_reave_private.next, "an_final", "...and the last scene")
	var steps: Array = AshesStory.SCENES.an_final.steps
	ok(steps.any(func(st): return st[0] == "unlock" and st[1] == "falcon"), "the last scene unlocks chapter eleven")
	var opened := WorldData.clear_map(c, "alast")
	ok(opened.has(&"falcon") and c.is_area_unlocked(&"falcon"), "clearing the Last Sentinel opens chapter eleven")
	eq(WorldData.place(&"falcon").maps.size(), 5, "chapter eleven (Greyhaven) is the next place, with its five maps")
	var last: Array = steps[steps.size() - 2]
	ok(last[0] == "title" and String(last[1]) == "CHAPTER TEN COMPLETE", "the chapter ends on its title card")


func _text() -> String:
	var t := ""
	for key in AshesStory.SCENES:
		for st in AshesStory.SCENES[key].steps:
			for part in st:
				if part is String:
					t += part + "\n"
	return t


func story() -> void:
	var t := _text()
	for word in ["Elowen", "princess", "Princess", "his daughter is alive", "returned to life", "Reave planned", "Reave burned", "signed by Reave", "his lover", "Elowen summoned"]:
		ok(not t.contains(word), "chapter ten never says \"%s\"" % word)
	for line in ["You didn't sleep.", "Then I'm consistent.", "I nearly killed a man who didn't destroy my home.", "Because you chose not to.", "Then we'll find them.",
			"I trust you slept better than I did.", "Then we have something in common.", "Your Majesty, perhaps we should begin.", "No orders. No deployments. No missing soldiers.",
			"You owe me no allegiance.", "I expect you to judge me by what I do next.", "There hasn't been a living Falcon Guard soldier in over a century.", "Then someone summoned them.",
			"A summoner could materialize soldiers who died long ago.", "That would require extraordinary ability.", "You fought your way through the capital.", "Neither did mine.",
			"A kingdom should not depend upon the mood of one man.", "When the crown grieves, the people starve. When the crown looks away, the roads crumble. And when the crown fails, who answers for it?",
			"I don't ask you to hate your King. I ask you to imagine a kingdom that doesn't need one.", "He's not wrong about everything.", "He hasn't done enough lately.",
			"You're Alaric.", "Reave. I make speeches. Occasionally people listen.", "And yet he's still alive.", "Curious.", "Then I hope you find them.",
			"My grandfather told stories about them.", "That's what we're here to find out.", "This place remembers them.", "Not all of them.",
			"Then it wasn't our army.", "Someone wanted you to think it was.", "And it worked.", "Someone prepared the story before the attack.", "And they wanted you to believe it.",
			"I gave them exactly what they wanted.", "You survived. They didn't plan for that.", "Then I'll make sure they regret it.",
			"Who summoned you?", "I serve the crown.", "Which crown?", "The rightful one.", "Summoned vessels may stay loyal to beliefs and causes from their former lives.",
			"Someone used the soldiers of my ancestors to destroy your village.", "Then this was never only about your village.", "And while I was grieving, I gave them every opportunity.",
			"But you weren't watching your kingdom.", "No. I wasn't.", "The summoner has found the old records.", "Then he's cleverer than I expected.", "Not yet.", "Let's see what he does with the truth.",
			"You finally know what happened.", "Someone used the dead to start a war.", "And if you don't like the answer?", "Then I'll decide what to do.",
			"Another village has been attacked.", "And the witnesses say the soldiers were already dead.", "CHAPTER TEN COMPLETE"]:
		ok(t.contains(line), "the owner's line is played: " + line.left(48))
	ok(t.contains("REAVE") and not t.contains("VILLAIN"), "Reave speaks, and nobody calls him the villain")
	var priv := JSON.stringify(AshesStory.SCENES.an_reave_private.steps)
	ok(priv.contains("\"shadow\""), "Reave's associate is a shadow, unnamed")
	ok(not JSON.stringify(AshesStory.SCENES).contains("give_"), "nobody joins in chapter ten")
	ok(not t.contains("KING dies") and JSON.stringify(AshesStory.SCENES.an_king.steps).contains("king_npc"), "the King is alive and in the scene")
	for key in ["an_b1_post", "an_b4_post"]:
		ok(JSON.stringify(AshesStory.SCENES[key].steps).contains("\"ko\"") or JSON.stringify(AshesStory.SCENES[key].steps).contains("\"hit\""), "%s shows defeated foes" % key)


func party() -> void:
	var g := Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
	var names: Array = g.roster.vessels().map(func(v): return v.display_name)
	for n in ["Bram", "Merc", "Gideon", "Kaelen", "Seraphine"]:
		ok(names.has(n), "%s is in the party" % n)
	ok(not names.has("Cassian Vale") and not names.has("Aldren") and not names.has("Captain Aldren"), "neither Cassian nor Aldren is a party member")
	BattleStage.pending_game = g
	BattleStage.pending_setup = Ashes.setup(4)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	await get_tree().process_frame
	eq(s.battle.deployment.summons_left(), 6, "Battle 4: six summons")
	ok(s.battle.deployment.owned_vessels.any(func(v): return v.display_name == "Seraphine"), "Battle 4: the whole company can be summoned")
	s.queue_free()
	await get_tree().process_frame
	eq(g.roster.vessels().size(), names.size(), "nothing was added or lost by the chapter")
