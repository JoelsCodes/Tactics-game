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
	ok(s.squire_cell == HallwayCutscene.ENTRANCE, "the squire was driven six tiles back, to the entrance (%s)" % s.squire_cell)
	ok(s.king.position.is_equal_approx(s.board.top_point(7, 4)) and s.squire.position.is_equal_approx(s.board.top_point(0, 4)), "both stand on those tiles")
	ok(s.line.text == HallwayCutscene.LINE_SQUIRE and s.speaker.text == "ASHEN SQUIRE", "the squire's line, with his name")
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
	ok(king.cell == Vector2i(7, 4) and b.battle.enemies[0].cell == Vector2i(0, 4), "they stand where the scene left them")
	ok(b.battle.deployment.props.is_empty() and b.battle.deployment.summons_left() == 0, "no summon stones, no summons")
	ok(king.data.display_name == "Alaric" and king.data.loadout.weapon_style.geometry == TacticalMath.Geometry.ROOK and king.data.loadout.weapon_style.display_name == "Rook", "the King is Alaric, with the Rook weapon style")
	var foe: BattleUnit = b.battle.enemies[0]
	ok(UnitLook.sheet_for(foe.data) == "squire", "the enemy is an Ashen Squire")
	var acts := b.battle.actions(foe)
	ok(acts.size() == 1 and acts[0].skill == null, "the squire can only attack (%d actions)" % acts.size())
	ok(b.setup.on_win == FirstBattle.AFTER_FIRST, "a win leads to Alaric's return to the hallway")
	for e in b.battle.enemies:
		e.hp = 0
	b.battle._check_outcome()
	b._check_end()
	ok(b.hud.return_button.text == "Continue", "the result panel goes on (%s)" % b.hud.return_button.text)
	var after_first: SaveGame = b.game
	b.queue_free()
	await get_tree().process_frame
	# the return to the hallway: Alaric hears more squires and limps for the far doors
	Cutscene3D.carried_game = after_first
	Engine.time_scale = 4.0
	var r: HallwayReturnCutscene = load("res://scenes/hallway_return.tscn").instantiate()
	r.go_on = false
	add_child(r)
	beats.clear()
	done = false
	r.finished.connect(func(): done = true)
	r.beat.connect(func(n): beats.append(n))
	ok(r.king._held and r.king.sprite.frame == int(Character.meta("king").get("slump", HallwayReturnCutscene.SLUMP)), "he starts slumped, worn out")
	waited = 0.0
	while not done and waited < 90.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	Engine.time_scale = 1.0
	ok(done and beats == ["start", "boots", "doors"], "the return scene plays to its end (%s)" % [beats])
	ok(r.king_cell == HallwayReturnCutscene.DOORS, "he reached the far doors (%s)" % r.king_cell)
	ok(r.king.get_alpha() < 0.01 and r.fade.modulate.a > 0.99, "he goes through and the scene fades to black")
	ok(Cutscene3D.carried_game == after_first, "the game he fought with is kept for the chamber")
	print("hallway checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
