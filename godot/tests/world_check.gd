extends Node
## Headless: the world map. Places open one at a time as the story unlocks them. Every map is locked until its story mission has been
## played once; a replay then plays the real party (every unit at its own level, every vessel), earns and saves everything the
## enemies give, and unlocks nothing. Clearing is saved. The screen shows the open places and starts levels.
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
	eq(WorldData.PLACES.size(), 7, "seven places on the chart")
	ok(WorldData.place(&"base").kind == "base" and WorldData.place(&"keep").maps.size() == 2, "the base and the keep (two maps)")
	eq(WorldData.place_of("chamber").id, &"keep", "the chamber is in the keep")
	eq(WorldData.place(&"riverbank").maps.map(func(m): return m.id), ["alley", "paths", "interception", "stand", "wrath"], "Riverford has its five fights, in story order")
	var g := FirstBattle.game()
	var c := g.campaign
	eq(WorldData.map_state(c, "hallway"), "locked", "every map is locked at the start")
	ok(c.unlock_area(&"keep") and not c.unlock_area(&"keep"), "a place unlocks once")
	eq(WorldData.map_state(c, "hallway"), "locked", "an open place's maps stay locked until their story mission is done")
	c.unlock_area(&"riverbank")
	eq(WorldData.map_state(c, "alley"), "mission", "the first Riverford fight is the story's next mission")
	eq(WorldData.map_state(c, "paths"), "locked", "the next waits for it")
	WorldData.clear_map(c, "alley")
	eq(WorldData.map_state(c, "alley"), "cleared", "winning the mission opens the map for replays")
	eq(WorldData.map_state(c, "paths"), "mission", "and makes the next fight the next mission")
	eq(WorldData.map_state(c, "wrath"), "locked", "the last is still shut")
	var opened := WorldData.clear_map(c, "hallway")
	eq(opened.size(), 0, "the keep was already open, so clearing the hallway opens nothing new")
	eq(WorldData.map_state(c, "hallway"), "cleared", "the hallway's story mission opens the hallway")
	eq(WorldData.map_state(c, "chamber"), "locked", "but not the chamber")
	ok(not c.mark_cleared("hallway"), "clearing twice changes nothing")
	var fresh := CampaignState.new()
	eq(WorldData.clear_map(fresh, "hallway"), [&"keep"] as Array[StringName], "the hallway's story mission opens the keep")
	eq(WorldData.clear_map(fresh, "chamber"), [&"base"] as Array[StringName], "the chamber's story mission opens the base")
	# a save keeps it all
	var back := SaveCodec.decode(SaveCodec.encode(g)).game.campaign
	ok(back.is_area_unlocked(&"keep") and back.is_area_unlocked(&"riverbank") and not back.is_area_unlocked(&"base"), "the open places are saved")
	ok(back.is_map_cleared("hallway") and not back.is_map_cleared("chamber"), "the cleared maps are saved")
	# the battles of a replay: the whole party in play, no story, nothing locked in
	var h := WorldData.setup_for("hallway", 1)
	ok(h.map_id == "hallway" and h.replay and h.world and h.on_win == "res://scenes/world_map.tscn" and not h.tutorial, "hallway replay: flags, back to the world map, no tutorial")
	ok(h.max_summons == DeploymentManager.DEFAULT_SUMMON_LIMIT and h.relics.size() == 2 and h.captain_cell != TacticalGrid.NO_CELL, "with summons, two stones and a Co-Captain's place (the story fight has none)")
	var ch := WorldData.setup_for("chamber", 1)
	ok(ch.replay and not ch.tutorial and ch.enemies.size() == 2 and ch.relics.size() == 3, "chamber replay: two squires, three summon stones")
	var s3 := WorldData.setup_for("alley", 1, false)
	var s4 := WorldData.setup_for("wrath", 1)
	ok(s3.map_id == "alley" and not s3.replay and s3.world, "a story mission is not a replay (it clears the map)")
	ok(s4.replay and s4.map_id == "wrath" and s4.enemies.size() >= 2 and s4.enemies[0][0].stats.level > s3.enemies[0][0].stats.level, "the last battle is a replay with Vesper and stronger foes")
	ok(WorldData.setup_for("nowhere", 1) == null, "an unknown map has no battle")
	ok(not WorldData.start(get_tree(), g, "chamber", 1), "a locked map cannot be started")


func flow() -> void:
	# the story mission: its win clears the map and opens the keep
	var g := FirstBattle.game()
	BattleStage.pending_game = g
	BattleStage.pending_setup = FirstBattle.setup(HallwayCutscene.HALFWAY, HallwayCutscene.ENTRANCE)
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 1000.0
	add_child(b)
	await get_tree().process_frame
	ok(GameSession.game == g and not g.campaign.is_map_cleared("hallway"), "the story battle uses the session's game, nothing cleared yet")
	for e in b.battle.enemies:
		e.hp = 0
	b.battle._check_outcome()
	b._check_end()
	ok(g.campaign.is_map_cleared("hallway") and g.campaign.is_area_unlocked(&"keep"), "winning it clears the hallway and opens the keep")
	ok(SaveSystem.exists(SaveSystem.AUTOSAVE) and SaveSystem.load_slot(SaveSystem.AUTOSAVE).game.campaign.is_map_cleared("hallway"), "and the autosave holds it")
	b.queue_free()
	await get_tree().process_frame
	# a replay: the real party, everything earned is kept, nothing new opens
	FirstBattle.chamber_game(g)
	g.roster.king.stats.level = 5
	var open_before := g.campaign.areas_unlocked.duplicate()
	var cleared_before := g.campaign.maps_cleared.duplicate()
	var xp_before := g.roster.king.stats.total_exp
	SaveSystem.delete_slot(SaveSystem.AUTOSAVE)
	BattleStage.pending_game = g
	BattleStage.pending_setup = WorldData.setup_for("hallway", 1)
	GameSession.game = null
	var r: BattleStage = load("res://scenes/battle.tscn").instantiate()
	r.enemy_delay = 1000.0
	add_child(r)
	await get_tree().process_frame
	ok(GameSession.game == g and r.game == g, "a replay plays the real game")
	var dm := r.battle.deployment
	eq(dm.king.data.level, 5, "Alaric is at his own level (5), not the first-time one")
	ok(dm.summons_left() == DeploymentManager.DEFAULT_SUMMON_LIMIT and dm.props.size() == 2, "the vessels can be summoned: two stones, the usual limit")
	eq(r.game.roster.vessels().size(), 2, "Bram and Lyra are there to summon")
	ok(dm.king.cell == HallwayCutscene.HALFWAY and r.battle.enemies[0].cell == HallwayCutscene.ENTRANCE, "Alaric and the squire start where the story fight starts")
	r.end_turn()  # Alaric takes a turn, so he shares the XP
	await get_tree().process_frame
	r.battle.summary.exp_pool = 30  # (a squire's reward: a real kill adds it as the hit lands)
	for e in r.battle.enemies:
		e.hp = 0
	r.battle._check_outcome()
	r._check_end()
	ok(g.roster.king.stats.total_exp > xp_before or g.roster.king.stats.level > 5, "the squire gave its XP (%d -> %d)" % [xp_before, g.roster.king.stats.total_exp])
	ok(SaveSystem.exists(SaveSystem.AUTOSAVE), "and a replay is saved like any battle")
	eq(g.campaign.areas_unlocked, open_before, "a replay unlocks no place")
	eq(g.campaign.maps_cleared, cleared_before, "and clears no map")
	eq(r.hud.return_button.text, "Continue", "its win goes on to the world map")
	r.queue_free()
	await get_tree().process_frame


func screen() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var c := g.campaign
	c.unlock_area(&"keep")
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
	await get_tree().process_frame
	eq(w.title.text, "The Ruined Keep", "the keep's panel")
	var buttons := w.body.get_children().filter(func(n): return n is Button)
	eq(buttons.size(), 2, "it lists its two maps")
	ok(not buttons[0].disabled and buttons[1].disabled, "the hallway can be replayed; the chamber is locked until its story mission")
	w.open_map("hallway")
	ok(w.body.get_children().any(func(n): return n is Label and n.text.begins_with("Replay:")), "a map says it is a replay")
	w.start_level("hallway", 1)
	eq(w.start_requests, [["hallway", 1]], "choosing a level starts it")
	# the story opens the riverbank, then the chamber clears and opens the base; the crossing stays locked
	c.unlock_area(&"riverbank")
	WorldData.clear_map(c, "chamber")
	w.select(&"riverbank")
	await get_tree().process_frame
	var rb := w.body.get_children().filter(func(n): return n is Button)
	ok(rb.size() == 5 and not rb[0].disabled and rb[1].disabled and rb[2].disabled and rb[3].disabled, "Riverford: the first fight is the next story mission, the rest are locked")
	w.open_map("alley")
	ok(w.body.get_children().any(func(n): return n is Label and n.text.begins_with("Story mission:")), "it says it is a story mission")
	eq(w.open_places().size(), 3, "the keep, the base (opened by the chamber) and the riverbank are open")
	w.select(&"base")
	w.enter_base()
	eq(w.start_requests.back(), ["base", 0], "the base place enters the base")
	w.queue_free()
