extends Node
## Headless: the hallway scene plays to its end, then the first battle starts as it says.
## godot --headless --path godot res://tests/hallway_check.tscn
var fails := 0
var count := 0
var done := false
var beats: Array[String] = []


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	Engine.time_scale = 4.0
	var s: HallwayCutscene = load("res://scenes/hallway.tscn").instantiate()
	s.start_battle = false
	add_child(s)
	s.finished.connect(func(): done = true)
	s.beat.connect(func(b): beats.append(b))
	var waited := 0.0
	while not done and waited < 60.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	Engine.time_scale = 1.0
	ok(done, "the hallway scene reaches its end")
	ok(beats == ["start", "squire", "lunge", "dodge", "slash", "pushed"], "its steps in order (%s)" % [beats])
	ok(s.king_cell == HallwayCutscene.HALFWAY, "the King is back halfway down the hall after his slash (%s)" % s.king_cell)
	ok(s.squire_cell == HallwayCutscene.ENTRANCE, "the squire was driven three tiles back, to the entrance (%s)" % s.squire_cell)
	ok(s.king.position.is_equal_approx(s.board.top_point(4, 4)) and s.squire.position.is_equal_approx(s.board.top_point(0, 4)), "both stand on those tiles")
	ok(s.line.text == HallwayCutscene.LINE_SQUIRE, "the squire's line")
	var scene_cam := s.board.cam.global_transform
	# the first battle, with both where the scene left them
	BattleStage.pending_game = FirstBattle.game()
	BattleStage.pending_setup = FirstBattle.setup(s.king_cell, s.squire_cell)
	s.queue_free()
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.0
	add_child(b)
	await get_tree().process_frame
	var units := b.battle.all_units()
	var king := b.battle.deployment.king
	ok(b.map_path == FirstBattle.MAP, "the battle is in the hallway")
	ok(b.board.cam.global_transform.is_equal_approx(scene_cam), "the battle's camera is exactly the scene's (no shift)")
	ok(units.size() == 2 and king != null and b.battle.enemies.size() == 1, "only the King and one enemy")
	ok(king.data.level == 1, "the King is level 1")
	ok(king.cell == Vector2i(4, 4) and b.battle.enemies[0].cell == Vector2i(0, 4), "they stand where the scene left them")
	ok(b.battle.deployment.props.is_empty() and b.battle.deployment.summons_left() == 0, "no summon stones, no summons")
	var foe: BattleUnit = b.battle.enemies[0]
	ok(UnitLook.sheet_for(foe.data) == "squire", "the enemy is an Ashen Squire")
	var acts := b.battle.actions(foe)
	ok(acts.size() == 1 and acts[0].skill == null, "the squire can only attack (%d actions)" % acts.size())
	print("hallway checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
