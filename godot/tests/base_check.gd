extends Node
## Headless: the base. A 15x15 map where Alaric walks freely (not tile by tile): walls, deep water, trees, the altar and
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
	eq([s.board.map.w, s.board.map.d], [15, 15], "the base is 15x15")
	var nature := 0
	var ruins := 0
	for y in 15:
		for x in 15:
			var t: String = s.board.map.tiles[y][x].t
			nature += 1 if t in ["g", "t", "w", "W", "r"] else 0
			ruins += 1 if t in ["f", "h", "e", "o", "q"] else 0
	ok(nature > 60 and ruins > 40, "it mixes nature (%d tiles) and ruins (%d tiles)" % [nature, ruins])
	ok(s.tile_code(Vector2i(0, 4)) == "q" and s.tile_code(Vector2i(4, 2)) == "W" and s.tile_code(Vector2i(4, 7)) == "b", "a wall, deep water and the bridge where the map has them")
	# free movement
	var start := s.pos
	ok(s.can_stand(start, s.level_at(s.cell_of(start))), "Alaric starts on open ground inside the gate")
	ok(not s.step(Vector2.ZERO, 0.1), "no direction, no move")
	var moved := s.step(Vector2(0, 1), 0.1)
	ok(moved and s.pos.y > start.y and absf(s.pos.x - start.x) < 0.001, "he moves a fraction of a tile, not a whole one (%s)" % [s.pos])
	ok(absf(fmod(s.pos.y, 1.0) - 0.5) > 0.01, "so he is between tile centres")
	# blocked things
	s.pos = Vector2(2.5, 4.5)
	var before := s.pos
	for i in 20:
		s.step(Vector2(-1, 0), 0.1)
	ok(s.pos.x > 1.9 and not s.can_stand(Vector2(1.5, 4.5), 1), "the gate tower's wall stops him (%s)" % [s.pos])
	ok(not s.can_stand(Vector2(4.5, 2.5), 0), "deep water is blocked")
	ok(not s.can_stand(Vector2(13.5, 7.5), 2), "the altar block is blocked")
	ok(not s.can_stand(Vector2(6.5, 4.5) if s.tile_code(Vector2i(6, 4)) == "t" else Vector2(7.5, 0.5), 1), "a tree is blocked")
	ok(s.can_stand(Vector2(4.5, 6.5), 0), "the bridge can be crossed")
	ok(s.can_stand(Vector2(4.5, 5.5), 0), "shallow water can be waded")
	# a cliff: two neighbouring open tiles two levels apart cannot be crossed
	var cliff := false
	for y in 15:
		for x in 14:
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if s.tile_open(a) and s.tile_open(b) and absi(s.level_at(a) - s.level_at(b)) >= 2:
				cliff = true
				ok(not s.can_stand(Vector2(b.x + 0.5, b.y + 0.5), s.level_at(a)), "a drop of two levels at %s is a cliff" % a)
				break
		if cliff:
			break
	# walls, trees, water: nothing walks through them; the whole open ground can be reached from the gate
	s.pos = Vector2(2.5, 7.5)
	for target in [Vector2i(12, 7), Vector2i(12, 5), Vector2i(2, 9), Vector2i(9, 2), Vector2i(8, 11), Vector2i(14, 12)]:
		var p := s.path_to(target)
		ok(not p.is_empty() or s.tile_open(target) == false, "a path to %s" % target)
	# every open tile can be reached from the gate (nothing is walled off)
	var shut: Array[Vector2i] = []
	for y in 15:
		for x in 15:
			var c := Vector2i(x, y)
			if s.tile_open(c) and s.path_to(c).is_empty() and c != s.cell_of(s.pos):
				shut.append(c)
	ok(shut.is_empty(), "no open tile is walled off from the gate (%s)" % [shut])
	ok(s.path_to(Vector2i(0, 4)).is_empty(), "no path into a wall")
	ok(s.path_to(Vector2i(13, 7)).is_empty(), "no path onto the altar")
	var p := s.path_to(Vector2i(12, 7))
	ok(p.size() >= 10 and p.back() == Vector2(12.5, 7.5), "the way to the altar crosses the bridge and the stone path (%d tiles)" % p.size())
	ok(p.any(func(v): return s.tile_code(s.cell_of(v)) == "b"), "over the bridge")
	# walk along it
	ok(s.walk_to(Vector2i(12, 7)), "a click on the altar's step starts a walk")
	for i in 400:
		await get_tree().process_frame
		if s.nearest == "altar":
			break
	ok(s.nearest == "altar" or s.pos.distance_to(Vector2(12.5, 7.5)) < 2.0, "walking there brings him to the altar (%s)" % [s.pos])
	# things to use
	s.pos = Vector2(12.2, 7.4)
	s._update_nearest()
	eq(s.nearest, "altar", "next to the altar it can be used")
	s.interact("altar")
	eq(s.last_action, "barracks", "the altar opens the barracks")
	s.pos = Vector2(1.8, 7.5)
	s._update_nearest()
	eq(s.nearest, "gate", "at the gate")
	s.interact("gate")
	eq(s.last_action, "world_map", "the gate opens the world map")
	s.pos = Vector2(2.8, 8.8)
	s._update_nearest()
	eq(s.nearest, "bram", "by Bram")
	s.interact("bram")
	await get_tree().process_frame
	ok(s.talking and s.last_action == "talk:bram" and s.line.text == BaseArea.TALK["bram"][0], "he talks: his first line")
	ok(s.speaker.text == "BRAM", "with his name")
	s.queue_free()
	print("base checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
