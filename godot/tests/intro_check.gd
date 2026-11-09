extends Node
## Headless: the intro plays to its end. Alaric runs along the path, his wound gives out (he slumps, then limps on), two Ashen
## Squires come into the clearing, he runs for the entrance and fades into it; one squire steps up and calls out; the scene
## ends faded to black.
## godot --headless --path godot res://tests/intro_check.tscn
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
	var s: IntroCutscene = load("res://scenes/intro.tscn").instantiate()
	s.go_on = false
	add_child(s)
	s.finished.connect(func(): done = true)
	s.beat.connect(func(b): beats.append(b))
	# the map: stepped ruins, with an entrance at the end of the path that climbs one level at a time
	var map: Dictionary = s.board.map
	var rows: Array = map.tiles
	var h := func(x: int, y: int) -> int: return int(rows[y][x].h)
	var climb := true
	for x in range(0, 9):
		climb = climb and absi(h.call(x + 1, IntroCutscene.PATH_ROW) - h.call(x, IntroCutscene.PATH_ROW)) <= 1
	ok(climb, "the path up to the entrance climbs at most one level per step")
	ok(h.call(8, 4) >= h.call(8, 5) + 1 and h.call(8, 6) >= h.call(8, 5) + 1, "walls rise on both sides of the entrance gap")
	ok(h.call(9, 4) > h.call(9, 5) and h.call(9, 6) > h.call(9, 5), "the back wall frames the cave")
	ok(absf(s.board.cam.global_position.distance_to(s.board.global_position + s.board.target) - Board3D.CAMERA_DISTANCE) < 0.01 and is_equal_approx(s.board.pitch, -50.0), "the intro camera has the battle's angle and distance")
	ok(s.fade.modulate.a > 0.99, "the scene opens on black (the narration)")
	var waited := 0.0
	while not beats.has("start") and waited < 60.0:  # past the narration
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	await get_tree().create_timer(0.5).timeout
	ok(s.king.animator != null, "Alaric uses the four-direction animator")
	var run := String(s.king.sprite.animation)
	var want := "run_" + SpriteAnimator.dir_of(s.board.screen_dir(Vector2i(1, 0), Vector2i(1, IntroCutscene.PATH_ROW)))
	ok(run == want, "running along the path plays the matching four-direction run (got %s, want %s)" % [run, want])
	ok(s.king.sprite.sprite_frames.get_frame_count(run) >= 4, "his run has its own frames (%d)" % s.king.sprite.sprite_frames.get_frame_count(run))
	while not beats.has("stumble") and waited < 90.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	ok(s.king._held and s.king.sprite.frame == int(Character.meta("king").get("slump", IntroCutscene.SLUMP)) and not s.king.sprite.is_playing(), "his wound gives out: he is held slumped")
	ok(s.stumble_cell == Vector2i(IntroCutscene.STUMBLE_X, IntroCutscene.PATH_ROW), "he stumbled on the path (%s)" % s.stumble_cell)
	await get_tree().create_timer(0.1).timeout
	ok(s.wound.modulate.a > 0.0, "the screen pulses red")
	while not done and waited < 120.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	Engine.time_scale = 1.0
	ok(done, "the intro reaches its end (%.1fs)" % waited)
	ok(beats == ["start", "run", "stumble", "limp", "hunted", "cave", "knights", "fade"], "its steps in order (%s)" % [beats])
	ok(not s.king._held, "he got up again")
	ok(s.king.get_alpha() < 0.01, "Alaric has gone into the entrance")
	ok(s.knights.size() == 2, "two squires came into the clearing")
	ok(s.knights.all(func(k): return k.char_name == "squire" and k.animator != null), "the knights are Ashen Squires, drawn four-direction")
	ok(s.knight_cells[0] == Vector2i(4, IntroCutscene.PATH_ROW - 1) and s.knight_cells[1] == Vector2i(3, IntroCutscene.PATH_ROW + 1), "one squire stepped up the path, the other stayed behind him")
	ok(s.line.text == IntroCutscene.LINE_SQUIRE and s.speaker.text == "ASHEN SQUIRE", "the squire's line, with his name")
	ok(s.fade.modulate.a > 0.99, "the scene fades to black")
	print("intro checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
