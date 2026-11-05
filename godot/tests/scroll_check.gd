extends Node
## Wide maps (owner, Nov 2026): the battle camera scrolls along a map wider than the screen, with the same lens, angle and distance, and
## the unit sprites stay upright on screen wherever they stand (the lean a perspective camera gives them is turned back).
## godot --headless --path godot res://tests/scroll_check.tscn
var fails := 0
var count := 0
const VIEW := Vector2(1920, 1080)


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)  # a 16:9 screen like the game's, whatever the headless window is
	await lean()
	await ranges()
	await stage()
	print("scroll checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## A flat map `depth` deep and `width` wide.
func _wide_map(depth: int, width: int) -> Dictionary:
	var rows := []
	for y in width:
		var r := []
		for x in depth:
			r.append("g0")
		rows.append(" ".join(PackedStringArray(r)))
	var f := FileAccess.open("user://scroll_probe.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows}))
	f.close()
	return Terrain.load_map("user://scroll_probe.json")


func _free() -> Rect2:
	var k := VIEW.y / 1080.0
	return Rect2(Vector2(80, BattleHud.TOP_BAND) * k, Vector2(VIEW.x - 160 * k, VIEW.y - (BattleHud.TOP_BAND + BattleHud.BOTTOM_BAND) * k))


## The on-screen angle (degrees, positive: top to the right) of a sprite's up direction.
func _sprite_lean(b: Board3D, v: UnitView3D) -> float:
	var foot := v.global_position
	var up: Vector3 = v.sprite.global_transform.basis.y.normalized()
	var a := b.cam.unproject_position(foot)
	var t := b.cam.unproject_position(foot + up)
	return rad_to_deg(atan2(t.x - a.x, a.y - t.y))


func lean() -> void:
	var raw := {}  # z -> the lean without the correction
	for corrected in [false, true]:
		var b := Board3D.new()
		add_child(b)
		b.lean_correction = corrected
		b.setup(_wide_map(16, 32))
		BattleStage.lock_camera(b, VIEW)
		await get_tree().process_frame
		for z in [3, 8, 16, 24, 29]:
			var v := b.add_unit("king", 8, z)
			await get_tree().process_frame
			await get_tree().process_frame
			var l := _sprite_lean(b, v)
			if not corrected:
				raw[z] = l
				continue
			var cap := Board3D.LEAN_CAP
			if absf(raw[z]) <= cap:
				ok(absf(l) < 1.0, "a unit leaning %.1f degrees stands upright when corrected (%.1f)" % [raw[z], l])
			else:  # past the cap it is turned back by the cap and no more
				ok(absf(l) < absf(raw[z]) - cap * 0.85 and absf(l) < absf(raw[z]), "a unit leaning %.1f degrees is turned back by the cap (%.1f left)" % [raw[z], l])
		b.queue_free()


func _corner_xs(b: Board3D) -> Vector2:
	var lo := INF
	var hi := -INF
	for x in [0.0, float(b.map.w)]:
		for z in [0.0, float(b.map.d)]:
			for y in [-Board3D.BASE, 4.0 * Board3D.LEVEL]:
				var p := b.cam.unproject_position(Vector3(x, y, z))
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
	return Vector2(lo, hi)


## Which boards need scrolling, where the camera may go, and that the camera stays the same camera.
func ranges() -> void:
	for width in [16, 20, 22, 24]:
		var b := Board3D.new()
		add_child(b)
		b.setup(_wide_map(16, width))
		BattleStage.lock_camera(b, VIEW)
		var r := b.scroll_range(_free(), VIEW)
		ok(r.x > r.y, "a 16 x %d board fits the screen: no scrolling" % width)
		b.queue_free()
	var b := Board3D.new()
	add_child(b)
	b.setup(_wide_map(16, 32))
	BattleStage.lock_camera(b, VIEW)
	var free := _free()
	var r := b.scroll_range(free, VIEW)
	ok(r.x < r.y and r.x > 0.0 and r.y < 32.0, "a 16 x 32 board scrolls between z %.2f and %.2f" % [r.x, r.y])
	b.scroll_to(r.x - 5.0, r, free, VIEW)  # asking for more than the range is clamped to it
	eq(b.target.z, r.x, "the camera stops at the left end")
	ok(_corner_xs(b).x <= free.position.x + 2.0, "at the left end the board's edge is at or past the screen's left margin (%.0f)" % _corner_xs(b).x)
	b.scroll_to(r.y + 5.0, r, free, VIEW)
	eq(b.target.z, r.y, "...and at the right end")
	ok(_corner_xs(b).y >= free.end.x - 2.0, "at the right end the board's edge is at or past the right margin (%.0f)" % _corner_xs(b).y)
	b.scroll_to((r.x + r.y) / 2.0, r, free, VIEW)
	ok(_corner_xs(b).x <= free.position.x + 2.0 and _corner_xs(b).y >= free.end.x - 2.0, "in the middle both edges stay outside the margins")
	# the same camera: lens, angle and distance never change as it scrolls, so sprites keep their size
	for z in [r.x, (r.x + r.y) / 2.0, r.y]:
		b.scroll_to(z, r, free, VIEW)
		eq([b.cam.fov, b.pitch, b.yaw, b.distance], [Board3D.CAMERA_FOV, -50.0, -90.0, Board3D.CAMERA_DISTANCE], "the lens, angle and distance at z=%.1f" % z)
	# picking still finds the tile under the pointer wherever the camera is
	for z in [r.x, (r.x + r.y) / 2.0, r.y]:
		b.scroll_to(z, r, free, VIEW)
		for tile in [Vector2i(8, int(z)), Vector2i(4, int(z) + 3), Vector2i(12, int(z) - 3)]:
			var shown := b.cam.unproject_position(b.top_point(tile.x, tile.y))
			eq(b.pick(shown), tile, "picking the tile at %s with the camera at z=%.1f" % [tile, z])
	# an unit's size on screen does not change with the scroll
	var v := b.add_unit("king", 8, 16)
	var sizes := []
	for z in [r.x, r.y]:
		b.scroll_to(z, r, free, VIEW)
		await get_tree().process_frame
		await get_tree().process_frame
		var foot := b.cam.unproject_position(v.global_position)
		var top := b.cam.unproject_position(v.global_position + v.sprite.global_transform.basis.y.normalized() * 1.9)
		sizes.append(foot.distance_to(top))
	b.queue_free()


## A Ford padded to a wide map in a real battle: the stage scrolls along it, follows whoever acts and stays within the board.
func stage() -> void:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://samples/riverbank_1.json"))
	var rows: Array = src.rows.duplicate()
	var cols: int = String(rows[0]).split(" ").size()
	var rim := []
	for i in cols:
		rim.append("g0" if i % 5 != 2 else "t0")
	var pad := 8
	var wide := []
	for i in pad:
		wide.append(" ".join(PackedStringArray(rim)))
	wide.append_array(rows)
	for i in pad:
		wide.append(" ".join(PackedStringArray(rim)))
	src.rows = wide
	src.erase("spawns")
	var f := FileAccess.open("user://scroll_ford.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(src))
	f.close()
	var setup := Riverbank.setup(1)
	setup.map_path = "user://scroll_ford.json"
	setup.king_cell += Vector2i(0, pad)
	setup.captain_cell += Vector2i(0, pad)
	for r in setup.relics:
		r[1] += Vector2i(0, pad)
	for e in setup.enemies:
		e[1] += Vector2i(0, pad)
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = setup
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	add_child(s)
	await get_tree().create_timer(0.5).timeout
	ok(s.scrolling, "a 32-wide battle map scrolls")
	ok(s._cam_z >= s.scroll_range.x - 0.01 and s._cam_z <= s.scroll_range.y + 0.01, "the camera starts inside its range (%.2f)" % s._cam_z)
	s.focus_cell(Vector2i(8, 100))
	eq(s._goal_z, s.scroll_range.y, "a far focus is clamped to the right end")
	await get_tree().create_timer(2.0).timeout
	ok(absf(s._cam_z - s.scroll_range.y) < 0.05, "the camera glides there (%.2f of %.2f)" % [s._cam_z, s.scroll_range.y])
	s.focus_cell(Vector2i(8, -5))
	await get_tree().create_timer(2.5).timeout
	ok(absf(s._cam_z - s.scroll_range.x) < 0.05, "...and back to the left end (%.2f of %.2f)" % [s._cam_z, s.scroll_range.x])
	# a tap on the tile under a point finds it with the camera scrolled
	var c := Vector2i(8, int(s._cam_z) + 2)
	eq(s.board.pick(s.board.cam.unproject_position(s.board.top_point(c.x, c.y))), c, "a tap finds its tile on the scrolled battle")
	s.queue_free()
	await get_tree().process_frame
	# a normal map does not scroll, and focus does nothing
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = Riverbank.setup(1)
	var s2: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s2.enemy_delay = 1000.0
	add_child(s2)
	await get_tree().create_timer(0.5).timeout
	ok(not s2.scrolling, "the standard 16 x 16 map does not scroll")
	var before := s2.board.cam.global_transform
	s2.focus_cell(Vector2i(8, 12))
	for i in 10:
		await get_tree().process_frame
	ok(s2.board.cam.global_transform.is_equal_approx(before), "so a focus changes nothing")
	s2.queue_free()
