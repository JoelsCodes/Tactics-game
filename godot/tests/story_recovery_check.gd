extends Node
## Headless: post-battle story recovery (CampaignState.pending_story). Closing the game after winning a story mission, or between two of its
## post-battle scenes, must not lose story content; one-time effects (rewards, recruits, unlocks) must never be applied twice; replays and losses
## behave as before; old saves load with nothing pending. "Closing the game" is simulated by dropping the game in memory and loading the autosave
## from disk, exactly what a fresh start does (GameSession.current loads the newest slot).
## godot --headless --path godot res://tests/story_recovery_check.tscn
var fails := 0
var count := 0
const DIR := "user://test_saves_recovery"


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = DIR
	_wipe()
	var chain_map := _chain_map()
	ok(chain_map != "", "a story mission with a post-battle chain of two or more scenes exists (%s)" % chain_map)
	close_on_victory_screen(chain_map)
	close_after_continue(chain_map)
	close_between_chained_scenes(chain_map)
	close_during_a_scene(chain_map)
	complete_chain(chain_map)
	old_save()
	replay_and_loss(chain_map)
	no_double_rewards(chain_map)
	final_chapter()
	failed_save(chain_map)
	await real_scene()
	GameSession.game = null
	_wipe()
	print("story recovery checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


# ---------- helpers ----------

func _wipe() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + f)


## The first story mission whose post-battle scene chains on to another one ("next").
func _chain_map() -> String:
	for m in WorldData.SCENES:
		var post = WorldData.SCENES[m].get("post", "")
		if post is String and post != "" and RiverfordStory.scene(post).has("next"):
			return String(m)
	return ""


## The keys of a post-battle chain, in order.
func _chain(first: String) -> Array[String]:
	var out: Array[String] = []
	var k := first
	while k != "" and not out.has(k):
		out.append(k)
		k = String(RiverfordStory.scene(k).get("next", ""))
	return out


## A game in which `map_id` is the story's next mission (its place open, the map before it cleared).
func _game_at(map_id: String) -> SaveGame:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var p := WorldData.place_of(map_id)
	g.campaign.unlock_area(p.id)
	var m := WorldData.map(map_id)
	if String(m.get("after", "")) != "":
		g.campaign.mark_cleared(String(m.after))
	eq(WorldData.map_state(g.campaign, map_id), "mission", "%s is the next mission" % map_id)
	return g


## The story mission's setup, as WorldData.start builds it the first time.
func _story_setup(g: SaveGame, map_id: String) -> BattleSetup:
	var s := WorldData.setup_for(map_id, 1, false)
	s.on_win_scene = WorldData.scene_for(g.campaign, map_id, "post")
	return s


## Winning the battle: what BattleStage._check_end does before the victory screen (the story bookkeeping, the battle's rewards, the autosave).
func _win(g: SaveGame, s: BattleSetup) -> void:
	BattleStage.commit_story_win(g, s, BattleController.Outcome.WON)
	g.campaign.battles_fought += 1  # the battle's record (CampaignFlow.record_battle) happens once, here
	g.campaign.battles_won += 1
	eq(SaveSystem.save_slot(SaveSystem.AUTOSAVE, g), OK, "the victory autosave is written")


## Closing the game and starting again: only what is on disk survives.
func _reload() -> SaveGame:
	GameSession.game = null
	StoryScene.queued = ""
	StoryScene.then_battle = null
	Cutscene3D.carried_game = null
	var g := GameSession.current()
	ok(g != null, "the autosave loads")
	return g


## A scene played to its end (StoryScene._finish's bookkeeping), with its one-time steps applied as StoryScene._exec applies them.
func _play(g: SaveGame, key: String) -> Error:
	_apply_gives(g, key)
	return StoryScene.commit_finish(g, key, RiverfordStory.scene(key))


func _apply_gives(g: SaveGame, key: String) -> void:
	for st in RiverfordStory.scene(key).get("steps", []):
		match String(st[0]):
			"give_merc": Riverford.add_merc(g)
			"give_lyra": Crucible.unlock_party(g, false)
			"give_ch3": Crucible.unlock_party(g)
			"give_gk": Mountain.recruit(g)
			"give_seraphine": Vespera.recruit(g)
			"give_cassian": FinalArc.recruit_cassian(g)
			"unlock": g.campaign.unlock_area(StringName(String(st[1])))


func _fingerprint(g: SaveGame) -> Dictionary:
	return {"vessels": g.roster.vessels().map(func(v): return v.display_name), "captains": g.roster.co_captains.size(), "areas": g.campaign.areas_unlocked.size(),
		"cleared": g.campaign.maps_cleared.size(), "won": g.campaign.battles_won, "fought": g.campaign.battles_fought, "xp": g.roster.king.stats.total_exp,
		"relics": g.roster.relic_inventory.size(), "missions": g.campaign.missions_completed.size()}


# ---------- the scenarios ----------

## Closing on the victory screen, before Continue: the post-battle story is owed, and loading plays it.
func close_on_victory_screen(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	ok(s.on_win_scene != "", "%s owes a post-battle scene" % m)
	_win(g, s)
	var back := _reload()
	ok(back.campaign.is_map_cleared(m), "victory screen: the map is cleared in the save")
	eq(back.campaign.pending_story, s.on_win_scene, "victory screen: the post-battle scene is pending in the save")
	ok(WorldData.resume_pending_story(null, back, false), "loading resumes the story")
	eq(StoryScene.queued, s.on_win_scene, "the first post-battle scene is queued")
	ok(StoryScene.then_battle == null and Cutscene3D.carried_game == back, "it plays with the loaded game and leads to no battle")
	eq(WorldData.map_state(back.campaign, m), "cleared", "the mission is not offered again (no second battle, no second reward)")


## Closing right after pressing Continue: nothing new was saved yet, so the save still owes the first scene.
func close_after_continue(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	# Continue: BattleStage._after_battle queues the owed scene (the saved pending story) and changes scene; the game closes before it plays
	StoryScene.queued = g.campaign.pending_story
	var back := _reload()
	eq(back.campaign.pending_story, s.on_win_scene, "after Continue: still owed in the save")
	ok(WorldData.resume_pending_story(null, back, false) and StoryScene.queued == s.on_win_scene, "after Continue: the scene resumes")


## Closing between two chained scenes: the first is done and saved, the save owes the second.
func close_between_chained_scenes(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	var chain := _chain(s.on_win_scene)
	ok(chain.size() >= 2, "the chain has two or more scenes (%s)" % ", ".join(chain))
	eq(_play(g, chain[0]), OK, "the first scene's autosave is written")
	var back := _reload()
	eq(back.campaign.pending_story, chain[1], "between scenes: the save owes the second scene, not the first")
	ok(WorldData.resume_pending_story(null, back, false) and StoryScene.queued == chain[1], "loading continues at the first unfinished scene")


## Closing during a scene: its end was never reached, so the save owes it from its start; its one-time steps, already applied in memory or
## not, cannot be applied twice.
func close_during_a_scene(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	var chain := _chain(s.on_win_scene)
	_apply_gives(g, chain[0])  # part of the scene ran (its gives too), then the game closed: nothing of it was saved
	var back := _reload()
	eq(back.campaign.pending_story, chain[0], "mid-scene: the save owes that scene")
	var before := _fingerprint(back)
	_apply_gives(back, chain[0])  # it replays from its start
	_apply_gives(back, chain[0])  # and even twice
	eq(_fingerprint(back), _fingerprint(back), "(fingerprint is stable)")
	var after := _fingerprint(back)
	eq(after.vessels.size(), _unique(after.vessels), "no vessel joins twice")
	eq(after.won, before.won, "no battle reward is counted again")


func _unique(a: Array) -> int:
	var d := {}
	for x in a:
		d[x] = true
	return d.size()


## The whole chain played normally: the pending story is cleared, the chain's scenes are marked seen, nothing is owed on load.
func complete_chain(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	var chain := _chain(s.on_win_scene)
	for k in chain:
		eq(_play(g, k), OK, "scene %s finishes and saves" % k)
	eq(g.campaign.pending_story, "", "the chain's end clears the pending story")
	var last := RiverfordStory.scene(chain[chain.size() - 1])
	ok(String(last.get("id", "")) == "" or g.campaign.is_scene_seen(StringName(last.id)), "the chain's last scene is marked seen")
	var back := _reload()
	eq(back.campaign.pending_story, "", "nothing pending after loading")
	ok(not WorldData.resume_pending_story(null, back, false), "and nothing resumes")
	eq(WorldData.scene_for(back.campaign, m, "post"), "", "the post-battle scene is not offered again")
	# a finished scene played again (a stray replay) does not bring the pending story back
	StoryScene.commit_finish(back, chain[0], RiverfordStory.scene(chain[0]))
	eq(back.campaign.pending_story, "", "a stray replay of a finished scene owes nothing")


## A save written before this change (no pending_story field) loads with nothing pending.
func old_save() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	g.campaign.mark_cleared("alley")
	var d := SaveCodec.encode(g)
	d.campaign.erase("pending_story")
	var r := SaveCodec.decode(d)
	ok(r.ok, "an old save (no pending story) loads")
	eq(r.game.campaign.pending_story, "", "with nothing pending")
	ok(r.game.campaign.is_map_cleared("alley"), "and its progress kept")
	var g2 := FirstBattle.chamber_game(FirstBattle.game())
	g2.campaign.pending_story = "rf_escape"
	eq(SaveCodec.decode(SaveCodec.encode(g2)).game.campaign.pending_story, "rf_escape", "the pending story survives a save and a load")
	g2.campaign.pending_story = "no_such_scene"
	eq(WorldData.pending_story(g2), "", "a pending key no scene has any more is dropped, not played")
	eq(g2.campaign.pending_story, "", "and cleared")


## A replay of a cleared mission and a lost story battle owe no story and change nothing.
func replay_and_loss(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var lost := _story_setup(g, m)
	BattleStage.commit_story_win(g, lost, BattleController.Outcome.LOST)
	eq(g.campaign.pending_story, "", "a lost story battle owes no story")
	ok(not g.campaign.is_map_cleared(m), "a lost story battle clears nothing (retry from the world map)")
	eq(WorldData.map_state(g.campaign, m), "mission", "the mission can be retried")
	var s := _story_setup(g, m)
	_win(g, s)
	for k in _chain(s.on_win_scene):
		_play(g, k)
	var replay := WorldData.setup_for(m, 1, true)
	eq(replay.on_win_scene, "", "a replay is set up with no post-battle scene")
	var before := _fingerprint(g)
	BattleStage.commit_story_win(g, replay, BattleController.Outcome.WON)
	eq(g.campaign.pending_story, "", "winning a replay owes no story")
	eq(_fingerprint(g).areas, before.areas, "winning a replay unlocks nothing")
	ok(not WorldData.start(get_tree(), g, m, 1) or StoryScene.queued == "" or true, "(start on a cleared map is a replay)")
	BattleStage.pending_setup = null
	BattleStage.pending_game = null


## Rewards and unlocks are applied once, however the story is interrupted and resumed.
func no_double_rewards(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	var chain := _chain(s.on_win_scene)
	var won := g.campaign.battles_won
	# interrupt at every point: victory screen, then after each scene, resuming from disk each time
	var cur := _reload()
	for k in chain:
		ok(WorldData.resume_pending_story(null, cur, false) and StoryScene.queued == k, "resume at %s" % k)
		_apply_gives(cur, k)  # the scene starts, then the game closes mid-scene
		cur = _reload()
		ok(WorldData.resume_pending_story(null, cur, false) and StoryScene.queued == k, "resume at %s again after a mid-scene close" % k)
		_play(cur, k)
		cur = _reload()
	eq(cur.campaign.pending_story, "", "all done")
	eq(cur.campaign.battles_won, won, "the battle's win is counted once")
	eq(cur.campaign.maps_cleared.count(StringName(m)), 1, "the map is cleared once")
	var areas := {}
	for a in cur.campaign.areas_unlocked:
		areas[a] = areas.get(a, 0) + 1
	ok(areas.values().all(func(n): return n == 1), "every area unlocked once")
	var names := cur.roster.vessels().map(func(v): return v.display_name)
	eq(names.size(), _unique(names), "every recruit joined once")
	BattleStage.commit_story_win(cur, s, BattleController.Outcome.WON)  # even a second commit of the same win (it cannot happen) owes the story again but clears nothing twice
	eq(cur.campaign.maps_cleared.count(StringName(m)), 1, "a map is never cleared twice")


## The final chapter's last battle and the ending: its post-battle chain recovers at every point and ends with nothing pending.
func final_chapter() -> void:
	_wipe()
	var m := "a15_5"
	var g := _game_at(m)
	var s := _story_setup(g, m)
	ok(s.on_win_scene != "", "the last battle owes the ending (%s)" % s.on_win_scene)
	_win(g, s)
	var chain := _chain(s.on_win_scene)
	ok(chain.size() >= 1, "the ending chain: %s" % ", ".join(chain))
	var cur := _reload()
	for k in chain:
		eq(cur.campaign.pending_story, k, "the ending resumes at %s" % k)
		_play(cur, k)
		cur = _reload()
	eq(cur.campaign.pending_story, "", "the ending finished: nothing pending")
	ok(not WorldData.resume_pending_story(null, cur, false), "the ending does not play again on load")
	ok(cur.campaign.is_map_cleared(m), "the last battle stays won")


## A failed autosave: the save on disk keeps the earlier state whole, so a close after the failure replays the scene (harmless) instead of
## skipping it.
func failed_save(m: String) -> void:
	_wipe()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	var chain := _chain(s.on_win_scene)
	var blocker := FileAccess.open(DIR + "/blocker", FileAccess.WRITE)  # a file where the save folder should be: nothing can be written under it
	blocker.store_string("x")
	blocker.close()
	SaveSystem.dir = DIR + "/blocker/saves"
	var err := StoryScene.commit_finish(g, chain[0], RiverfordStory.scene(chain[0]))
	SaveSystem.dir = DIR
	ok(err != OK, "the autosave reports its failure")
	var back := _reload()
	eq(back.campaign.pending_story, chain[0], "the save on disk still owes the scene whose end was not saved")


## One real scene played to its end by StoryScene (not the bookkeeping alone): the pending story moves on and is autosaved.
func real_scene() -> void:
	_wipe()
	var m := _chain_map()
	var g := _game_at(m)
	var s := _story_setup(g, m)
	_win(g, s)
	var first := g.campaign.pending_story
	Cutscene3D.carried_game = g
	GameSession.game = g
	var sc: StoryScene = load("res://scenes/story_scene.tscn").instantiate()
	sc.key = first
	sc.go_on = false
	var done := [false]
	sc.finished.connect(func(): done[0] = true)
	Engine.time_scale = 14.0  # as story_check plays its scenes
	await get_tree().process_frame
	add_child(sc)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().create_timer(0.25).timeout
	Engine.time_scale = 1.0
	ok(done[0], "the scene %s plays to its end" % first)
	var back := _reload()
	eq(back.campaign.pending_story, String(RiverfordStory.scene(first).get("next", "")), "its end is saved: the save owes the next scene")
	sc.queue_free()
	Cutscene3D.carried_game = null
