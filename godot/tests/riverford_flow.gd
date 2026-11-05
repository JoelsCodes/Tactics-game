extends Node
## Headless, end to end: the world map's way into chapter two. Starts map 1 as a story mission: its opening scene plays (once), the battle follows, a win
## clears the map and unlocks the next; the last map's win plays the closing scene and returns to the world map; a second time through plays no scene.
## The test lives under the root so it survives the scene changes.
## godot --headless --path godot res://tests/riverford_flow.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


var runner_mode := false


## The test scene is only a trampoline: it adds a copy of this script under the root (which survives scene changes) and the copy does the work.
func _ready() -> void:
	SaveSystem.dir = "user://test_saves_flow"
	if runner_mode:
		run.call_deferred()
		return
	var r := Node.new()
	r.set_script(get_script())
	r.set("runner_mode", true)
	get_tree().root.add_child.call_deferred(r)


func current() -> Node:
	return get_tree().current_scene


func wait_for(pred: Callable, seconds := 120.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not pred.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().create_timer(0.1).timeout
	return pred.call()


func run() -> void:
	Engine.time_scale = 14.0
	var game := FirstBattle.chamber_game(FirstBattle.game())
	game.campaign.unlock_area(&"riverbank")
	WorldData.clear_map(game.campaign, "chamber")
	GameSession.game = game
	# map 1: scene, then battle
	ok(WorldData.start(get_tree(), game, "alley", 1), "the first Riverford map starts")
	ok(await wait_for(func(): return current() is StoryScene), "its opening scene plays first")
	ok(await wait_for(func(): return current() is BattleStage), "and the battle follows it straight away")
	var stage: BattleStage = current()
	ok(stage.setup != null and stage.setup.map_id == "alley" and not stage.setup.replay, "the battle is the story mission")
	ok(game.campaign.is_scene_seen(&"rf_market"), "the scene is marked seen")
	win(stage)
	ok(await wait_for(func(): return stage.summary != null), "winning ends the battle")
	ok(game.campaign.is_map_cleared("alley") and WorldData.map_state(game.campaign, "paths") == "mission", "the win clears the map and makes the next the story's next mission")
	stage._after_battle()
	ok(await wait_for(func(): return current() != stage and current() != null and not (current() is BattleStage)), "back to the world map")
	# the same map as a replay: no scene
	ok(WorldData.start(get_tree(), game, "alley", 1), "a cleared map can be replayed")
	await get_tree().process_frame
	await get_tree().process_frame
	ok(current() is BattleStage, "a replay goes straight to the battle, with no scene")
	var replay: BattleStage = current()
	ok(replay.setup.replay, "...and it is a replay")
	replay.queue_free()
	await get_tree().process_frame
	# the last map: opening scene, battle, closing scene
	for id in ["alley", "paths", "interception", "stand"]:
		WorldData.clear_map(game.campaign, id)
	ok(WorldData.start(get_tree(), game, "wrath", 1), "the last map starts")
	ok(await wait_for(func(): return current() is StoryScene), "the awakening plays first")
	ok(await wait_for(func(): return current() is BattleStage), "then the battle")
	ok(game.roster.king.vessel_roster.any(func(v): return v.display_name == "Merc"), "Merc has joined by then")
	var last: BattleStage = current()
	ok(last.battle.enemies.size() >= 4 and last.battle.fleeing.size() == 1, "Vesper's guard stands, and Vesper is set to flee")
	win(last)
	ok(await wait_for(func(): return last.summary != null), "the last battle is won")
	last._after_battle()
	ok(await wait_for(func(): return current() is StoryScene), "the closing scene plays")
	ok(await wait_for(func(): return not (current() is StoryScene) and not (current() is BattleStage)), "and then the world map")
	ok(game.campaign.is_scene_seen(&"rf_escape") and game.campaign.is_scene_seen(&"rf_awakening"), "both are marked seen")
	Engine.time_scale = 1.0
	print("riverford flow checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## Every enemy goes down (or flees), as if the player had won.
func win(stage: BattleStage) -> void:
	for e in stage.battle.enemies:
		e.hp = 0
	stage.battle._check_outcome()
	stage._check_end()
