extends Node
## Headless: the world map. Places open one at a time as the story unlocks them; a map has levels; the first play writes down the
## party's levels and a replay carries them (on a copy that keeps nothing); a cleared story map unlocks the next place; the
## records survive a save. The screen shows the open places and starts levels.
## godot --headless --path godot res://tests/world_check.tscn
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
	SaveSystem.dir = "user://test_saves_world"
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
	data()
	await flow()
	await screen()
	print("world checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func data() -> void:
	eq(WorldData.PLACES.size(), 5, "five places on the chart")
	ok(WorldData.place(&"base").kind == "base" and WorldData.place(&"keep").maps.size() == 2, "the base and the keep (two maps)")
	eq(WorldData.place_of("chamber").id, &"keep", "the chamber is in the keep")
	eq(WorldData.map("crossing").levels.size(), 3, "the crossing has three levels")
	var g := FirstBattle.game()  # Alaric alone, as in the hallway
	var c := g.campaign
	eq(WorldData.map_state(c, "hallway"), "locked", "nothing is open at the start")
	ok(c.unlock_area(&"keep") and not c.unlock_area(&"keep"), "an area unlocks once")
	eq(WorldData.map_state(c, "hallway"), "locked", "a story map stays shut until the story clears it")
	eq(WorldData.map_state(c, "crossing"), "locked", "a place that is not open has shut maps")
	c.unlock_area(&"riverbank")
	eq(WorldData.map_state(c, "crossing"), "new", "an open place's map is new")
	c.record_first_play("hallway", g.roster)
	eq(c.first_levels("hallway")[CampaignState.unit_key(g.roster.king)], 1, "the first play writes down Alaric's level")
	g.roster.king.stats.level = 4
	c.record_first_play("hallway", g.roster)
	eq(c.first_levels("hallway")[CampaignState.unit_key(g.roster.king)], 1, "and a second call changes nothing")
	var opened := WorldData.clear_map(c, "hallway")
	ok(opened == [&"keep"] or c.is_area_unlocked(&"keep"), "clearing the hallway opens the keep")
	eq(WorldData.map_state(c, "hallway"), "cleared", "the hallway is cleared")
	FirstBattle.chamber_game(g)  # Bram and Lyra join before the chamber
	g.roster.king.stats.level = 2
	c.record_first_play("chamber", g.roster)
	ok(WorldData.clear_map(c, "chamber") == [&"base"], "clearing the chamber opens the base")
	g.roster.king.stats.level = 1
	# a save keeps it all
	var back := SaveCodec.decode(SaveCodec.encode(g)).game.campaign
	ok(back.is_area_unlocked(&"base") and back.is_area_unlocked(&"keep") and back.is_area_unlocked(&"riverbank"), "the open places are saved")
	ok(back.is_map_cleared("hallway") and back.is_map_cleared("chamber") and not back.is_map_cleared("crossing"), "the cleared maps are saved")
	eq(back.first_levels("hallway"), c.first_levels("hallway"), "and the first-play levels")
	# a replay: a copy at the first-time levels
	var replay := WorldData.game_for(g, "hallway")
	ok(replay != g and replay.roster.king != g.roster.king, "a replay is a copy")
	eq(replay.roster.king.stats.level, 1, "carrying Alaric at his first-time level (he is level 4 now)")
	var chamber_replay := WorldData.game_for(g, "chamber")
	eq(chamber_replay.roster.king.stats.level, 2, "the chamber's replay has Alaric at 2, as he was then")
	eq(chamber_replay.roster.king.vessel_roster.size(), 2, "with Bram and Lyra")
	g.roster.king.stats.level = 4
	eq(g.roster.king.stats.level, 4, "the real game is untouched")
	ok(replay.roster.king.vessel_roster.is_empty(), "the hallway had no vessels, so the replay has none")
	ok(WorldData.game_for(g, "crossing") == g, "a map not cleared yet is played with the real game")
	# the battles
	var s1 := WorldData.setup_for(g, "hallway", 1)
	ok(s1.map_id == "hallway" and s1.replay and s1.world and s1.on_win == "res://scenes/world_map.tscn" and not s1.tutorial, "hallway replay: ids, flags, back to the world map, no tutorial")
	var s2 := WorldData.setup_for(g, "chamber", 1)
	ok(s2.replay and not s2.tutorial and s2.enemies.size() == 2 and s2.max_summons == 2, "chamber replay: two squires, two summons, no tutorial")
	var s3 := WorldData.setup_for(g, "crossing", 1)
	var s4 := WorldData.setup_for(g, "crossing", 3)
	ok(not s3.replay and s3.enemies.size() == 4, "the crossing is a first play: four foes")
	ok(s4.enemies[0][0].stats.level > s3.enemies[0][0].stats.level, "level 3 has stronger foes than level 1 (%d > %d)" % [s4.enemies[0][0].stats.level, s3.enemies[0][0].stats.level])
	ok(WorldData.setup_for(g, "nowhere", 1) == null, "an unknown map has no battle")


func flow() -> void:
	# a story battle's first play writes the levels and its win opens the next place
	var g := FirstBattle.game()
	var s := FirstBattle.setup(HallwayCutscene.HALFWAY, HallwayCutscene.ENTRANCE)
	BattleStage.pending_game = g
	BattleStage.pending_setup = s
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 1000.0
	add_child(b)
	await get_tree().process_frame
	ok(g.campaign.has_played("hallway") and GameSession.game == g, "starting the story battle writes down the levels and sets the session game")
	for e in b.battle.enemies:
		e.hp = 0
	b.battle._check_outcome()
	b._check_end()
	ok(g.campaign.is_map_cleared("hallway") and g.campaign.is_area_unlocked(&"keep"), "winning it clears the hallway and opens the keep")
	ok(SaveSystem.exists(SaveSystem.AUTOSAVE) and SaveSystem.load_slot(SaveSystem.AUTOSAVE).game.campaign.is_area_unlocked(&"keep"), "and the autosave holds it")
	b.queue_free()
	await get_tree().process_frame
	# a replay of it plays a copy: nothing is saved, the real game is untouched
	g.roster.king.stats.level = 5
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
	var played := WorldData.game_for(g, "hallway")
	var rs := WorldData.setup_for(g, "hallway", 1)
	BattleStage.pending_game = played
	BattleStage.pending_setup = rs
	GameSession.game = g
	var r: BattleStage = load("res://scenes/battle.tscn").instantiate()
	r.enemy_delay = 1000.0
	add_child(r)
	await get_tree().process_frame
	ok(GameSession.game == g, "a replay leaves the session's game alone")
	eq(r.battle.deployment.king.data.level, 1, "the replay's Alaric is at his first-time level")
	for e in r.battle.enemies:
		e.hp = 0
	r.battle._check_outcome()
	r._check_end()
	ok(not SaveSystem.exists(SaveSystem.AUTOSAVE), "a replay is not saved")
	eq(r.hud.return_button.text, "Continue", "a replay's win goes on to the world map")
	ok(g.roster.king.stats.level == 5 and g.roster.king.stats.exp == 0, "and the real Alaric kept his own level and XP")
	r.queue_free()
	await get_tree().process_frame


func screen() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var c := g.campaign
	c.unlock_area(&"keep")
	c.record_first_play("hallway", g.roster)
	WorldData.clear_map(c, "hallway")
	GameSession.game = g
	var w: WorldMapScreen = load("res://scenes/world_map.tscn").instantiate()
	w.go_on = false
	add_child(w)
	await get_tree().process_frame
	eq(w.open_places().map(func(p): return p.id), [&"keep"], "only the keep is open")
	eq(w.selected, &"keep", "and it is the place chosen")
	ok(not w.art.unlocked.call(&"riverbank") and w.art.unlocked.call(&"keep"), "the chart fogs what is not open")
	w.select(&"riverbank")
	ok(w.title.text == "Not yet reached", "a closed place shows nothing of itself")
	w.select(&"keep")
	eq(w.title.text, "The Ruined Keep", "the keep's panel")
	ok(w.body.get_child_count() >= 3, "it lists its maps")
	w.open_map("hallway")
	ok(w.body.get_children().any(func(n): return n is Label and n.text.begins_with("Replay:")), "a cleared map says it is a replay")
	w.start_level("hallway", 1)
	eq(w.start_requests, [["hallway", 1]], "choosing a level starts it")
	# the story opens the riverbank, then the base
	c.unlock_area(&"riverbank")
	WorldData.clear_map(c, "chamber")
	w.select(&"riverbank")
	w.open_map("crossing")
	ok(w.body.get_children().any(func(n): return n is Label and n.text.begins_with("First time:")), "a new map says it is a first time")
	eq(w.open_places().size(), 3, "the keep, the base (opened by the chamber) and the riverbank are open")
	w.select(&"base")
	w.enter_base()
	eq(w.start_requests.back(), ["base", 0], "the base place enters the base")
	w.queue_free()
