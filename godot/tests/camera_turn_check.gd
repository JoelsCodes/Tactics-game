extends Node
## The battle view turns a quarter-turn around the board (Z / C, owner Nov 2026), with the same lens, angle and distance and no zoom.
## Nothing in the battle changes: every unit keeps its tile, its facing and its place in the world; its sprite stays on its tile,
## upright and the same size on screen, and shows the same facing as seen from the new side. A long map scrolls along its long side
## in every view (across the screen or up it). Also surveys every battle map: which screen axes it overflows in each view (one axis
## means scrolling is enough, two would need free panning) and how many standing tiles the ground hides from each side.
## godot --headless --path godot res://tests/camera_turn_check.tscn
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
	get_window().size = Vector2i(1920, 1080)
	await turning()
	await wide()
	survey()
	print("camera turn checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _key(s: BattleStage, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	s._unhandled_input(e)


func _stage(setup: BattleSetup) -> BattleStage:
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = setup
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	add_child(s)
	return s


## A unit's sprite on screen: (foot, height in px, lean in px over its height).
func _on_screen(b: Board3D, v: UnitView3D) -> Array:
	var foot := b.cam.unproject_position(v.global_position)
	var up := v.sprite.global_transform.basis.y
	var top := b.cam.unproject_position(v.global_position + up * v.figure_height())
	return [foot, foot.distance_to(top), absf(top.x - foot.x)]


func turning() -> void:
	var s := _stage(Riverford.setup(1))
	await get_tree().create_timer(0.5).timeout
	var b := s.board
	var units: Array = s.views.keys().filter(func(u): return u.on_field)
	ok(units.size() >= 3, "a battle with units on the field (%d)" % units.size())
	var start := b.cam.global_transform
	var where := {}
	var heights := {}
	for u in units:
		where[u] = [u.cell, u.facing, s.views[u].global_position]
	# Q / E still turn the acting unit, never the camera
	var rot0 := b.rot
	_key(s, KEY_Q)
	_key(s, KEY_E)
	eq(b.rot, rot0, "Q / E do not turn the view")
	for turn in 4:
		_key(s, KEY_C)
		for i in 3:
			await get_tree().process_frame
		eq(b.rot, posmod(rot0 + turn + 1, 4), "C turns the view a quarter-turn")
		eq([b.cam.fov, b.pitch, b.distance], [Board3D.CAMERA_FOV, -50.0, Board3D.CAMERA_DISTANCE], "the same lens, angle and distance (turn %d)" % (turn + 1))
		eq(b.yaw, -90.0 * b.rot, "the camera's turn")
		for u in units:
			var v: UnitView3D = s.views[u]
			eq([u.cell, u.facing], [where[u][0], where[u][1]], "%s keeps its tile and facing" % u.data.display_name)
			ok(v.global_position.distance_to(where[u][2]) < 0.001, "%s's sprite does not move in the world" % u.data.display_name)
			var tp := b.top_point(u.cell.x, u.cell.y)
			ok(Vector2(v.global_position.x - tp.x, v.global_position.z - tp.z).length() < 0.01, "%s stands on its tile" % u.data.display_name)
			var want := SpriteAnimator.dir8_of(b.screen_dir(u.facing, u.cell)) if v.animator.dirs8() else SpriteAnimator.dir_of(b.screen_dir(u.facing, u.cell))
			eq(v.animator.dir, want, "%s shows its facing as seen from view %d" % [u.data.display_name, b.rot])
			var sc := _on_screen(b, v)
			ok(sc[2] < 0.06 * sc[1], "%s stands upright on screen in view %d (lean %.1f px of %.0f)" % [u.data.display_name, b.rot, sc[2], sc[1]])
			if not heights.has(u):
				heights[u] = []
			heights[u].append(sc[1])
			if Rect2(Vector2.ZERO, VIEW).has_point(b.cam.unproject_position(tp)):
				ok(_picks(b, u.cell), "a click finds %s's tile in view %d (or the taller tile in front of it)" % [u.data.display_name, b.rot])
	for u in units:
		var hs: Array = heights[u]
		ok(hs.max() / hs.min() < 1.12, "%s keeps its size on screen in every view (%.0f to %.0f px)" % [u.data.display_name, hs.min(), hs.max()])
	ok(b.cam.global_transform.is_equal_approx(start), "four turns bring the view back exactly")
	# every unit has its see-through silhouette (blue for Alaric's side, red for the enemy), on the same frame and place as its sprite
	for u in units:
		var v: UnitView3D = s.views[u]
		ok(v.ghost != null and v.ghost.material_override is ShaderMaterial, "%s has a see-through silhouette" % u.data.display_name)
		if v.ghost == null:
			continue
		var tint: Color = (v.ghost.material_override as ShaderMaterial).get_shader_parameter("tint")
		eq(tint, BattleStage.GHOST_ALLY if u.team == 0 else BattleStage.GHOST_FOE, "%s's silhouette colour" % u.data.display_name)
		ok(v.ghost.visible and v.ghost.transform.is_equal_approx(v.sprite.transform) and v.ghost.flip_h == v.sprite.flip_h, "%s's silhouette follows its sprite" % u.data.display_name)
		eq(v.ghost.texture, UnitView3D._white(v.sprite.sprite_frames.get_frame_texture(v.sprite.animation, v.sprite.frame)), "%s's silhouette shows the frame on show" % u.data.display_name)
	var fade: UnitView3D = s.views[units[0]]
	fade.set_alpha(0.3)
	fade._process(0.0)
	ok(not fade.ghost.visible, "a fading unit (a summon appearing, a knockout) has no silhouette")
	fade.set_alpha(1.0)
	_key(s, KEY_Z)
	eq(b.rot, posmod(rot0 - 1, 4), "Z turns the other way")
	s.queue_free()
	await get_tree().process_frame


## A Ford padded to 32 wide: it scrolls in every view, along the screen axis its long side runs on, and never shows its edge.
func wide() -> void:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://samples/riverford_1.json"))
	var rows: Array = src.rows.duplicate()
	var cols: int = String(rows[0]).split(" ").size()
	var rim := []
	for i in cols:
		rim.append("g0")
	var pad := 8
	var wide_rows := []
	for i in pad:
		wide_rows.append(" ".join(PackedStringArray(rim)))
	wide_rows.append_array(rows)
	for i in pad:
		wide_rows.append(" ".join(PackedStringArray(rim)))
	src.rows = wide_rows
	src.erase("spawns")
	var f := FileAccess.open("user://turn_ford.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(src))
	f.close()
	var setup := Riverford.setup(1)
	setup.map_path = "user://turn_ford.json"
	setup.king_cell += Vector2i(0, pad)
	setup.captain_cell += Vector2i(0, pad)
	for r in setup.relics:
		r[1] += Vector2i(0, pad)
	for e in setup.enemies:
		e[1] += Vector2i(0, pad)
	var s := _stage(setup)
	await get_tree().create_timer(0.5).timeout
	var b := s.board
	var free := BattleStage.free_rect(VIEW)
	for turn in 4:
		var across := b.scroll_across()
		ok(s.scrolling, "the wide map scrolls in view %d" % b.rot)
		eq(across, b.rot % 2 == 1, "view %d scrolls %s" % [b.rot, "across the screen" if b.rot % 2 == 1 else "up and down"])
		for end in [s.scroll_range.x, s.scroll_range.y]:
			s.focus(end)
			await get_tree().create_timer(1.6).timeout
			var r := b.board_screen_rect(VIEW)
			r.position += Vector2(-b.cam.h_offset, b.cam.v_offset) * VIEW.y / (2.0 * b.distance * tan(deg_to_rad(b.fov / 2.0)))
			var m := 0.0
			var covers := (r.position.x <= free.position.x + 1 and r.end.x >= free.end.x - 1) if across else (r.position.y <= free.position.y - m + 1 and r.end.y >= free.end.y + m - 1)
			ok(covers, "view %d at z %.1f: the board still fills the screen along its long side" % [b.rot, end])
			var c := Vector2i(cols / 2, clampi(int(s._cam_z), 0, b.map.d - 1))
			ok(_picks(b, c), "a click finds its tile on the scrolled view %d (or the taller tile in front of it)" % b.rot)
		var unit: BattleUnit = s.battle.deployment.king
		ok(s.views[unit].global_position.distance_to(b.top_point(unit.cell.x, unit.cell.y)) < 0.05, "the King's sprite stays on his tile while the view scrolls")
		_key(s, KEY_C)
		await get_tree().create_timer(0.2).timeout
	s.queue_free()
	await get_tree().process_frame


## True when a click on the middle of tile c finds c, or a tile in front of it that stands taller and so covers that spot (the click
## gets the tile you see).
func _picks(b: Board3D, c: Vector2i) -> bool:
	var got := b.pick(b.cam.unproject_position(b.top_point(c.x, c.y)))
	return got == c or (got != Vector2i(-1, -1) and b.top_point(got.x, got.y).y > b.top_point(c.x, c.y).y)


## Every battle map in all four views: which screen axes it overflows (needs scrolling on), and the standing tiles the ground hides.
func survey() -> void:
	var free := BattleStage.free_rect(VIEW)
	var both := 0
	var one := 0
	var none := 0
	var hidden_total := [0, 0, 0, 0]
	var worst := []
	var maps := 0
	var tiles := 0
	for fname in DirAccess.get_files_at("res://samples"):
		if not fname.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://samples/" + fname)
		if not "terrain_upgrade" in text:  # the battle maps (the upgrade tool marks every one)
			continue
		maps += 1
		var map := Terrain.load_map("res://samples/" + fname)
		var grid := TacticalGrid.from_map(map)
		var b := Board3D.new()
		b.map = map
		b.cam = Camera3D.new()
		var per_view := []
		for q in 4:
			b.rot = q
			b.yaw = -90.0 * q
			var r := b._rect_for(Vector3(map.w / 2.0, 0.6, map.d / 2.0), VIEW)
			var over := int(r.size.x > free.size.x) + int(r.size.y > free.size.y + 2.0 * Board3D.SCROLL_V_REACH)
			if over == 2:
				both += 1
			elif over == 1:
				one += 1
			else:
				none += 1
			var h := _hidden(map, grid, q)
			hidden_total[q] += h[0]
			per_view.append(h[0])
			if q == 0:
				tiles += h[1]
		b.cam.free()
		b.free()
		worst.append([per_view.max() - per_view[1], fname, per_view])
	worst.sort_custom(func(a, c): return a[0] > c[0])
	print("survey: %d battle maps x 4 views: %d views fit the screen, %d overflow one axis (scrolling), %d overflow both (would need panning)" % [maps, none, one, both])
	print("survey: standing tiles at least half hidden by the ground, per view 0..3 (1 = today's view): %s of %d" % [hidden_total, tiles])
	for w in worst.slice(0, 8):
		print("   %s: %s" % [w[1], w[2]])
	ok(both == 0, "no battle map overflows the screen both ways in any view, so scrolling along the long side is enough")


## Standing tiles where at least half of a unit standing there is hidden by the ground in view q (rays from points up the figure to
## the camera, marched over the tile tops; trees and props are not counted). Returns [hidden, standing tiles].
func _hidden(map: Dictionary, grid: TacticalGrid, q: int) -> Array:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-50.0), deg_to_rad(-90.0 * q), 0))
	var hidden := 0
	var standing := 0
	for y in map.d:
		for x in map.w:
			var c := Vector2i(x, y)
			if not grid.can_stand(c):
				continue
			standing += 1
			var foot := Vector3(x + .5, grid.height(c) * Board3D.LEVEL, y + .5)
			var target := Vector3(map.w / 2.0, 0.6, clampf(y + .5, 0.0, float(map.d)))
			var eye := target + basis * Vector3(0, 0, Board3D.CAMERA_DISTANCE)
			var blocked := 0
			for k in 5:
				var p := foot + Vector3(0, 0.2 + k * 0.4, 0)
				var d := (eye - p).normalized()
				var t := 0.05
				while t < 30.0:
					var w := p + d * t
					var cx := int(floor(w.x))
					var cy := int(floor(w.z))
					if cx < 0 or cy < 0 or cx >= map.w or cy >= map.d:
						break
					if Vector2i(cx, cy) != c:
						var tile: Dictionary = map.tiles[cy][cx]
						if tile.t != "v" and w.y < float(tile.h) * Board3D.LEVEL:
							blocked += 1
							break
					t += 0.05
			if blocked >= 3:
				hidden += 1
	return [hidden, standing]
