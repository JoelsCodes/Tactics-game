extends Node
## Headless: the intro plays to its end. The King walks up the path, stops right before the entrance, goes in and
## fades away; two Ashen Squires come into the clearing and one walks forward; the scene ends faded to black.
## godot --headless --path godot res://tests/intro_check.tscn
var fails := 0
var count := 0
var done := false


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var s: IntroCutscene = load("res://scenes/intro.tscn").instantiate()
	s.go_on = false
	add_child(s)
	s.finished.connect(func(): done = true)
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
	await get_tree().create_timer(3.0).timeout  # the King is walking up the path by now
	ok(s.king.animator != null, "the King uses the four-direction animator")
	var walk := String(s.king.sprite.animation)
	var want := "walk_" + SpriteAnimator.dir_of(s.board.screen_dir(Vector2i(1, 0), Vector2i(3, 5)))
	ok(walk == want, "walking along the path plays the matching four-direction walk (got %s, want %s)" % [walk, want])
	ok(s.king.sprite.sprite_frames.get_frame_count(walk) == 4, "his walk is exactly the four new frames (no stray old ones)")
	var waited := 3.0
	while not done and waited < 90.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	ok(done, "the intro reaches its end (%.1fs)" % waited)
	ok(s.stopped_cell == Vector2i(IntroCutscene.STOP_X, IntroCutscene.PATH_ROW), "he stopped right before the entrance (%s)" % s.stopped_cell)
	ok(s.king.get_alpha() < 0.01, "the King has faded away into the entrance")
	ok(s.knights.size() == 2, "two squires came into the clearing")
	ok(s.knights.all(func(k): return k.char_name == "squire" and k.animator != null), "the knights are Ashen Squires, drawn four-direction")
	ok(s.knight_cells[0] == Vector2i(3, IntroCutscene.PATH_ROW) and s.knight_cells[1] == Vector2i(0, IntroCutscene.PATH_ROW + 1), "one squire walked forward, the other stayed")
	ok(s.fade.modulate.a > 0.99, "the scene fades to black")
	print("intro checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
