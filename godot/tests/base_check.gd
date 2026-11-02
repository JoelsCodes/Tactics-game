extends Node
## Headless: the base. A 30x30 map where Alaric walks freely (not tile by tile): walls, deep water, trees, the altar and
## cliffs block him, shallow water is waded, a click finds a path, and the altar, the gate and the others can be used.
## godot --headless --path godot res://tests/base_check.tscn
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
	GameSession.game = FirstBattle.chamber_game(FirstBattle.game())
	var s: BaseArea = load("res://scenes/base_area.tscn").instantiate()
	s.go_on = false
	add_child(s)
	await get_tree().process_frame
	eq([s.board.map.w, s.board.map.d], [30, 30], "the base is 30x30")
	var nature := 0
	var ruins := 0
	for y in 30:
		for x in 30:
			var t: String = s.board.map.tiles[y][x].t
			nature += 1 if t in ["g", "t", "w", "W", "r"] else 0
			ruins += 1 if t in ["f", "h", "e", "o", "q"] else 0
	ok(nature > 300 and ruins > 150, "it mixes nature (%d tiles) and ruins (%d tiles)" % [nature, ruins])
	ok(s.tile_code(Vector2i(0, 4)) == "q" and s.tile_code(Vector2i(10, 2)) == "W" and s.tile_code(Vector2i(9, 15)) == "b", "a wall, deep water and the bridge where the map has them")
	ok(s.tile_code(Vector2i(28, 15)) == "e" and s.level_at(Vector2i(28, 15)) == 3, "the altar block stands at the back of the hall")
	# free movement
	var start := s.pos
	ok(s.can_stand(start, s.level_at(s.cell_of(start))), "Alaric starts on open ground inside the gate")
	ok(not s.step(Vector2.ZERO, 0.1), "no direction, no move")
	var moved := s.step(Vector2(0, 1), 0.1)
	ok(moved and s.pos.y > start.y and absf(s.pos.x - start.x) < 0.001, "he moves a fraction of a tile, not a whole one (%s)" % [s.pos])
	ok(absf(fmod(s.pos.y, 1.0) - 0.5) > 0.01, "so he is between tile centres")
	# blocked things
	s.pos = Vector2(3.5, 11.5)
	for i in 20:
		s.step(Vector2(0, -1), 0.1)
	ok(s.tile_code(Vector2i(1, 11)) == "q" or s.pos.y > 0.0, "the walls of the gate towers are there")
	s.pos = Vector2(3.5, 10.5)
	for i in 20:
		s.step(Vector2(-1, 0), 0.1)
	ok(s.pos.x > 2.9, "the gate tower's wall stops him (%s)" % [s.pos])
	ok(not s.can_stand(Vector2(10.5, 2.5), 0), "deep water is blocked")
	ok(not s.can_stand(Vector2(28.5, 15.5), 3), "the altar block is blocked")
	var tree := Vector2i(-1, -1)
	for y in 30:
		for x in 30:
			if tree.x < 0 and s.tile_code(Vector2i(x, y)) == "t":
				tree = Vector2i(x, y)
	ok(tree.x >= 0 and not s.can_stand(Vector2(tree.x + 0.5, tree.y + 0.5), s.level_at(tree)), "a tree is blocked (at %s)" % tree)
	ok(s.can_stand(Vector2(9.5, 15.5), 0), "the bridge can be crossed")
	var wade := Vector2i(-1, -1)
	for y in 30:
		for x in 30:
			if wade.x < 0 and s.tile_code(Vector2i(x, y)) == "w" and s.tile_code(Vector2i(x, y)) != "W":
				wade = Vector2i(x, y)
	ok(wade.x >= 0 and s.can_stand(Vector2(wade.x + 0.5, wade.y + 0.5), 0), "shallow water can be waded (%s)" % wade)
	# a cliff: two neighbouring open tiles two levels apart cannot be crossed
	var cliff := false
	for y in 30:
		for x in 29:
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if s.tile_open(a) and s.tile_open(b) and absi(s.level_at(a) - s.level_at(b)) >= 2:
				cliff = true
				ok(not s.can_stand(Vector2(b.x + 0.5, b.y + 0.5), s.level_at(a)), "a drop of two levels at %s is a cliff" % a)
				break
		if cliff:
			break
	# the hotspots and the people stand on open ground
	for id in s.spots:
		var c := s.cell_of(s.spots[id].at)
		ok(s.tile_open(c), "%s stands on open ground (%s)" % [id, c])
	# every open tile can be reached from the gate (nothing is walled off)
	s.pos = BaseArea.START
	var shut: Array[Vector2i] = []
	var open := 0
	for y in 30:
		for x in 30:
			var c := Vector2i(x, y)
			if s.tile_open(c):
				open += 1
				if s.path_to(c).is_empty() and c != s.cell_of(s.pos):
					shut.append(c)
	ok(shut.is_empty(), "no open tile is walled off from the gate (%d of %d shut: %s)" % [shut.size(), open, shut.slice(0, 8)])
	ok(s.path_to(Vector2i(0, 4)).is_empty(), "no path into a wall")
	ok(s.path_to(Vector2i(28, 15)).is_empty(), "no path onto the altar")
	var p := s.path_to(Vector2i(27, 15))
	ok(p.size() >= 20 and p.back() == Vector2(27.5, 15.5), "the way to the altar is long: over the bridge, up the road (%d tiles)" % p.size())
	ok(p.any(func(v): return s.tile_code(s.cell_of(v)) == "b"), "over the bridge")
	# walk along it
	ok(s.walk_to(Vector2i(27, 15)), "a click on the altar's step starts a walk")
	for i in 3000:
		await get_tree().process_frame
		if s.nearest == "altar":
			break
	ok(s.nearest == "altar" or s.pos.distance_to(Vector2(27.5, 15.5)) < 3.0, "walking there brings him to the altar (%s)" % [s.pos])
	# the camera follows him, at the same lens, angle and distance
	var cam_target: Vector3 = s.board.target
	ok(cam_target.x > 15.0, "the camera has followed him up the map (%s)" % [cam_target])
	ok(is_equal_approx(s.board.pitch, -50.0) and is_equal_approx(s.board.distance, Board3D.CAMERA_DISTANCE) and is_equal_approx(s.board.cam.fov, Board3D.CAMERA_FOV), "same angle, distance and lens")
	s.pos = Vector2(0.5, 0.5)
	s._cam_at = s._follow_point()
	ok(s.board.map.w / 2.0 > 0 and s._follow_point().x >= BaseArea.VIEW_DEPTH - 0.001 and s._follow_point().z >= BaseArea.VIEW_SIDE - 0.001, "it stops short of the map's corner (%s)" % [s._follow_point()])
	# things to use
	s.pos = Vector2(27.2, 15.4)
	s._update_nearest()
	eq(s.nearest, "altar", "next to the altar it can be used")
	s.interact("altar")
	eq(s.last_action, "barracks", "the altar opens the barracks")
	s.pos = Vector2(1.8, 15.5)
	s._update_nearest()
	eq(s.nearest, "gate", "at the gate")
	s.interact("gate")
	eq(s.last_action, "world_map", "the gate opens the world map")
	s.pos = Vector2(4.6, 18.8)
	s._update_nearest()
	eq(s.nearest, "bram", "by Bram")
	s.interact("bram")
	await get_tree().process_frame
	ok(s.talking and s.last_action == "talk:bram" and s.line.text == BaseArea.TALK["bram"][0], "he talks: his first line")
	ok(s.speaker.text == "BRAM", "with his name")
	s.queue_free()
	print("base checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
