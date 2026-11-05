extends Node
## Headless: chapter two's story scenes (RiverfordStory, played by StoryScene). Each scene's steps are checked (known steps, known units), the owner's
## lines are there word for word, each scene is played to its end and marks itself seen, and a scene is offered once: the first time a story mission is
## started or won, never on a replay.
## godot --headless --path godot res://tests/story_check.tscn
var fails := 0
var count := 0
const STEPS := ["give_ch3", "cam", "fade", "wait", "beat", "title", "narrate", "bars", "tint", "spawn", "say", "walk", "join", "look", "play", "act", "hold", "hide", "show", "fadeout", "fadein", "jump", "slide", "fx", "bubble", "flash", "red", "shake", "give_merc", "give_ch3"]
const NEEDS_ID := ["say", "walk", "look", "play", "act", "hold", "hide", "show", "fadeout", "fadein", "jump", "slide", "fx", "bubble"]


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_story"
	scripts()
	flow()
	await play_all()
	print("story checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _all_keys() -> Array:
	var keys: Array = RiverfordStory.SCENES.keys()
	keys.append_array(CrucibleStory.SCENES.keys())
	return keys


func scripts() -> void:
	var texts := ""
	for key in _all_keys():
		var d: Dictionary = RiverfordStory.scene(key)
		ok(d.id == key and ResourceLoader.exists(d.map) or FileAccess.file_exists(d.map), "%s: has an id and a map" % key)
		var ids := {}
		var last := ""
		for step in d.steps:
			ok(step[0] in STEPS, "%s: step %s is known" % [key, step[0]])
			if step[0] == "spawn":
				ids[String(step[1])] = true
				ok(Character.names().has(String(step[2])), "%s: sheet %s exists" % [key, step[2]])
			elif step[0] in NEEDS_ID:
				ok(ids.has(String(step[1])), "%s: %s uses %s after it exists" % [key, step[0], step[1]])
			if step[0] in ["say", "narrate"]:
				texts += String(step[3] if step[0] == "say" else step[1]) + "\n"
		ok(d.steps.size() > 10, "%s: a scene with substance (%d steps)" % [key, d.steps.size()])
	# the owner's text, word for word
	for line in [RiverfordStory.MERC_1, RiverfordStory.VESPER_1, RiverfordStory.MERC_2, RiverfordStory.VESPER_2, RiverfordStory.AIDE_1, RiverfordStory.MERC_3, RiverfordStory.VESPER_3,
			RiverfordStory.MERC_4, RiverfordStory.VESPER_4, RiverfordStory.MERC_5, RiverfordStory.MERC_6, RiverfordStory.MERC_7, RiverfordStory.ALARIC_1]:
		ok(texts.contains(line), "the owner's line is played: " + line.left(40))
	ok(RiverfordStory.MERC_1.begins_with("It was a farming settlement!") and RiverfordStory.VESPER_3 == "I know. But peace of mind is priceless.", "the owner's wording is kept")
	for p in ["The stone of the borderland trade town of Oakhaven's shadow", "The blade flashes downward. A sickening crunch echoes off the stone.", "The dust settles. The rebellion has its third soul"]:
		ok(texts.contains(p), "the narration is kept: " + p.left(40))


func flow() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var c := g.campaign
	c.unlock_area(&"riverbank")
	eq(WorldData.scene_for(c, "alley", "pre"), "rf_market", "the first mission opens with the market scene")
	eq(WorldData.scene_for(c, "alley", "post"), "", "...and has no closing scene")
	eq(WorldData.scene_for(c, "wrath", "post"), "rf_escape", "the last has a closing scene")
	eq(WorldData.scene_for(c, "wrath", "pre"), "rf_awakening", "and an opening one")
	c.mark_scene_seen(&"rf_market")
	eq(WorldData.scene_for(c, "alley", "pre"), "", "a scene seen once is never offered again")
	eq(WorldData.scene_for(c, "hallway", "pre"), "", "maps with no scene have none")
	for id in ["alley", "paths", "interception", "stand", "wrath"]:
		ok(WorldData.scene_for(FirstBattle.game().campaign, id, "pre") != "", "map %s has an opening scene on a fresh save" % id)
	# chapter three opens when chapter two ends
	ok(not c.is_area_unlocked(&"irongate"), "the Iron Gate is shut until the Riverford chapter is done")
	WorldData.clear_map(c, "wrath")
	ok(c.is_area_unlocked(&"irongate") and WorldData.map_state(c, "phalanx") == "mission", "clearing Vesper's Wrath opens the Iron Gate, and its first battle is the next mission")
	eq(WorldData.scene_for(c, "phalanx", "pre"), "cr_table", "chapter three opens at the war table")
	eq(WorldData.scene_for(c, "breaking", "post"), "cr_end", "and ends with its closing scene")
	# a replay never plays a scene: WorldData.start only offers a scene for a story mission, never for a cleared map
	eq(WorldData.map_state(c, "alley"), "mission", "an uncleared first map is a story mission")
	WorldData.clear_map(c, "alley")
	eq(WorldData.map_state(c, "alley"), "cleared", "a cleared one is a replay")
	var replay := WorldData.setup_for("alley", 1, true)
	eq(replay.on_win_scene, "", "a replay leads to no scene")
	for n in ["alley", "paths", "interception", "stand", "wrath"]:
		var s := WorldData.setup_for(n, 1, false)
		ok(s != null and s.map_id == n and not s.replay, "%s: the story mission builds" % n)


func play_all() -> void:
	Engine.time_scale = 14.0
	for key in _all_keys():
		var game := FirstBattle.chamber_game(FirstBattle.game())
		Cutscene3D.carried_game = game
		GameSession.game = game
		var s: StoryScene = load("res://scenes/story_scene.tscn").instantiate()
		s.go_on = false
		s.key = key
		add_child(s)
		var done := [false]
		s.finished.connect(func(): done[0] = true)
		var t0 := Time.get_ticks_msec()
		while not done[0] and Time.get_ticks_msec() - t0 < 180000:  # real seconds: a scene is minutes of story time, run 14 times faster
			await get_tree().create_timer(0.25).timeout
		ok(done[0], "%s plays to its end" % key)
		ok(game.campaign.is_scene_seen(StringName(key)) or RiverfordStory.scene(key).has("next"), "%s marks itself seen (or chains on to the scene that does)" % key)
		if key == "rf_awakening":
			ok(game.roster.king.vessel_roster.any(func(v): return v.display_name == "Merc"), "after Merc's rise he is Alaric's vessel")
		s.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
