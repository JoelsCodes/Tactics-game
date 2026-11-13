extends Node
## The Last Benediction battlefield (the owner's GLB and navigation JSON) in Godot: the 11x11 grid and the existing movement rules, scenery with no
## collision, the playable floors as the only collision, the isometric camera and light, the 2D sprites on the tiles, how many floors the camera
## can see (floor-to-floor occlusion; the scenery has no collision, so it is not part of this), and how heavy the scene is.
## godot --headless --path godot res://tests/last_benediction_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, str(a), str(b)])


var _log: FileAccess


func mark(s: String) -> void:
	if _log:
		_log.store_line("%d ms: %s" % [Time.get_ticks_msec(), s])
		_log.flush()


func _ready() -> void:
	var lp := OS.get_environment("LB_LOG")
	if lp != "":
		_log = FileAccess.open(lp, FileAccess.WRITE)
	var t0 := Time.get_ticks_msec()
	var board := LastBenedictionBoard.new()
	add_child(board)
	mark("building")
	ok(board.build(), "the board builds")
	mark("built")
	print("built in %d ms" % (Time.get_ticks_msec() - t0))
	if board.grid == null:
		print("last benediction checks: stopped")
		get_tree().quit(1)
		return
	mark("waiting for physics")
	await get_tree().physics_frame
	await get_tree().physics_frame
	mark("physics ready")
	mark("scene_structure(board)")
	scene_structure(board)
	mark("grid_and_movement(board)")
	grid_and_movement(board)
	mark("units(board)")
	units(board)
	mark("camera_and_light(board)")
	camera_and_light(board)
	mark("occlusion(board)")
	occlusion(board)
	mark("scenery_occlusion(board)")
	await scenery_occlusion(board)
	mark("budget(board)")
	budget(board)
	print("last benediction checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func scene_structure(b: LastBenedictionBoard) -> void:
	eq(b.floors.size(), 121, "121 playable floors (the 11x11 grid)")
	var bodies := 0
	for c in b.floors:
		var mi: MeshInstance3D = b.floors[c]
		for k in mi.get_children():
			if k is StaticBody3D:
				bodies += 1
	eq(bodies, 121, "every playable floor has a collision slab")
	var scenery_bodies := 0
	for m in b.merged:
		scenery_bodies += m.find_children("*", "CollisionObject3D", true, false).size()
	eq(scenery_bodies, 0, "the scenery has no collision")
	ok(b.scenery_meshes > 1500, "the scenery came in as separate meshes (%d)" % b.scenery_meshes)
	ok(b.merged.size() <= 40 and b.merged.size() >= 10, "the scenery is merged by material (%d meshes, was %d)" % [b.merged.size(), b.scenery_meshes])
	# every floor sits where the navigation JSON says: x, row and raised or not
	var mism := 0
	for t in b.nav.tiles:
		var c := Vector2i(int(t.x), int(t.y))
		var w := b.cell_to_world(c)
		var raised: bool = b.tops[c] > 0.5
		if absf(w.x - (c.x + 0.5)) > 0.01 or (raised != (int(t.elevation) == 1)):
			mism += 1
	eq(mism, 0, "every floor's height matches its elevation in the navigation JSON")
	# the root is scaled to 1-unit tiles: the floor centres of neighbours are one unit apart
	var a: MeshInstance3D = b.floors[Vector2i(3, 3)]
	var d: MeshInstance3D = b.floors[Vector2i(4, 3)]
	ok(absf(a.global_position.distance_to(Vector3(d.global_position.x, a.global_position.y, d.global_position.z)) - 1.0) < 0.01, "tiles are one unit apart in the scene")


func grid_and_movement(b: LastBenedictionBoard) -> void:
	var g := b.grid
	eq([g.width, g.depth], [11, 11], "the combat grid is 11x11")
	var blocked := 0
	for t in b.nav.tiles:
		var c := Vector2i(int(t.x), int(t.y))
		if g.is_obstacle(c):
			blocked += 1
	eq(blocked, 13, "13 blocked tiles from the navigation JSON")
	ok(not g.can_stand(Vector2i(5, 9)), "the altar (5,9) cannot be stood on")
	ok(g.can_stand(b.objective()), "the objective in front of the altar can be stood on")
	eq(b.objective(), Vector2i(5, 8), "the objective is the tile in front of the altar")
	for s in b.spawns():
		ok(g.can_stand(s), "spawn %s can be stood on" % s)
	# stepping up one level is allowed and costs the tile entered; down needs Jump; two levels would be a wall
	var up_from := Vector2i(-1, -1)
	var up_to := Vector2i(-1, -1)
	for y in 11:
		for x in 11:
			var c := Vector2i(x, y)
			for n in g.neighbors4(c):
				if up_from.x < 0 and g.can_stand(c) and g.can_stand(n) and g.height(n) - g.height(c) == 1:
					up_from = c
					up_to = n
	ok(up_from.x >= 0, "the map has a step up (%s to %s)" % [up_from, up_to])
	eq(g.step_cost(up_from, up_to, 1), 1, "a step up of one level is allowed and costs 1")
	eq(g.step_cost(up_to, up_from, 1), 1, "a step down of one level is allowed with Jump 1")
	eq(g.step_cost(up_to, up_from, 0), -1, "a step down needs Jump")
	var r := g.reachable(b.spawns()[0], 30, 1)
	ok(r.can_reach(b.objective()), "the objective is reachable from the spawn")
	var open := 0
	for t in b.nav.tiles:
		if not t.blocked:
			open += 1
	eq(r.cells().size(), open - 0, "every open tile is reachable from the spawn (%d open)" % open)
	ok(not r.can_reach(Vector2i(5, 9)) and not r.can_reach(Vector2i(1, 1)), "blocked tiles are not reachable")
	var path := g.find_path(b.spawns()[0], b.objective(), 1)
	ok(path.size() > 2 and path[path.size() - 1] == b.objective(), "a path runs from the spawn to the objective (%d steps)" % path.size())
	# the climb is on the way: some step of the path goes up a level
	var climbs := 0
	for i in range(1, path.size()):
		if g.height(path[i]) > g.height(path[i - 1]):
			climbs += 1
	ok(climbs >= 1, "the path to the objective climbs a level (%d step up)" % climbs)
	# a short move range from the spawn stays on the board and off the blocked tiles
	var short := g.reachable(b.spawns()[0], 4, 1)
	var bad := 0
	for c in short.cells():
		if g.is_obstacle(c) or not g.in_bounds(c):
			bad += 1
	eq(bad, 0, "a short move range never includes a blocked or off-board tile")


func units(b: LastBenedictionBoard) -> void:
	var placed := []
	var names := ["alaric_v2", "warden"]
	for i in 2:
		var c: Vector2i = b.spawns()[i]
		var u := b.place_unit(names[i], c)
		ok(u != null and b.grid.cell_of(u) == c, "%s is placed on the grid at %s" % [names[i], c])
		placed.append(u)
	ok(placed[0].sprite.sprite_frames != null and placed[1].sprite.sprite_frames != null, "the units' 2D sprite frames loaded")
	eq(b.grid.cell_of(placed[0]), Vector2i(4, 1), "Alaric stands on spawn (4,1)")
	# walk one unit along the path and keep the sprite on the floor's top at every step, including the step up
	var path := b.grid.find_path(Vector2i(4, 1), b.objective(), 1)
	var worst := 0.0
	for c in path:
		b.grid.move_occupant(placed[0], c)
		placed[0].position = b.cell_to_world(c)
		worst = maxf(worst, absf(placed[0].position.y - b.tops[c]))
	eq(b.grid.cell_of(placed[0]), b.objective(), "the unit walked to the objective")
	ok(worst < 0.001, "the sprite follows the floor's height on every step")


func camera_and_light(b: LastBenedictionBoard) -> void:
	eq(b.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "the camera is orthographic (isometric)")
	var pitch := rad_to_deg(asin(-b.camera.global_transform.basis.z.y))
	ok(absf(pitch + 35.264) < 0.5 or absf(pitch - 35.264) < 0.5, "the camera's pitch is the true isometric 35.264 degrees (%.2f)" % pitch)
	ok(b.sun.shadow_enabled and b.sun.light_energy > 0.0, "the sun casts shadows")
	var env: WorldEnvironment = b.get_node("Environment")
	ok(env.environment.ambient_light_energy > 0.0, "the scene has ambient light")


## Floor-to-floor occlusion: a ray from the camera to each floor's centre; the floor is visible if nothing else in the grid is hit first.
## The scenery has no collision, so it does not count here (the screenshot is where it shows).
func occlusion(b: LastBenedictionBoard) -> void:
	var space := b.get_world_3d().direct_space_state
	var seen := 0
	var hidden: Array = []
	for c in b.floors:
		var target := b.cell_to_world(c) + Vector3(0, 0.02, 0)
		var from: Vector3 = b.camera.global_position + (target - b.camera.global_position).normalized() * 0.0
		var dir: Vector3 = -b.camera.global_transform.basis.z   # an orthographic ray runs parallel to the view
		var origin := target - dir * 40.0
		var q := PhysicsRayQueryParameters3D.create(origin, target + dir * 0.05)
		q.collision_mask = LastBenedictionBoard.FLOOR_LAYER
		var hit := space.intersect_ray(q)
		var floor_body: Node = b.floors[c].get_node("FloorBody")
		if hit.size() > 0 and hit.collider == floor_body:
			seen += 1
		else:
			hidden.append(c)
	var pct := 100.0 * seen / b.floors.size()
	print("floors visible from the camera: %d of %d (%.0f%%); hidden: %s" % [seen, b.floors.size(), pct, str(hidden)])
	ok(pct >= 85.0, "at least 85%% of the floors are visible to the camera (%.0f%%)" % pct)


## How many floors scenery stands in front of, from each camera corner (the camera never zooms, it only turns by quarters). The default corner is the
## one that covers the fewest.
func scenery_occlusion(b: LastBenedictionBoard) -> void:
	var best := -1
	var least := 999
	for corner in 4:
		b.set_view(corner)
		var cov: Array[Vector2i] = await b.covered_tiles()
		print("corner %d: scenery stands in front of %d of 121 floors" % [corner, cov.size()])
		if cov.size() < least:
			least = cov.size()
			best = corner
	b.set_view(LastBenedictionBoard.DEFAULT_VIEW)
	var chosen: int = (await b.covered_tiles()).size()
	eq(LastBenedictionBoard.DEFAULT_VIEW, best, "the default camera corner is the one with the least scenery in the way")
	var cov_default: Array[Vector2i] = await b.covered_tiles()
	var on_open := []
	for c in cov_default:
		if not b.grid.is_obstacle(c):
			on_open.append(c)
	print("default corner: %d floors have scenery in front, %d of them are walkable: %s" % [chosen, on_open.size(), str(on_open)])
	var cov0: Array[Vector2i] = await b.covered_tiles()
	for s in b.spawns():
		ok(not (s in cov0), "spawn %s is not hidden by scenery" % s)
	ok(not (b.objective() in cov0), "the objective is not hidden by scenery")
	var left := 0
	for m in b.merged:
		left += m.find_children("*", "CollisionObject3D", true, false).size()
	eq(left, 0, "the survey's temporary colliders are gone: the scenery has no collision")


func budget(b: LastBenedictionBoard) -> void:
	var meshes := b.find_children("*", "MeshInstance3D", true, false).size()
	print("scene: %d MeshInstance3D (%d floors, %d merged scenery), %d scenery triangles" % [meshes, b.floors.size(), b.merged.size(), b.triangles])
	ok(meshes <= 200, "the scene is about a hundred and fifty draw calls, not two thousand (%d meshes)" % meshes)
	ok(b.triangles < 3000000, "the scenery stays under three million triangles (%d)" % b.triangles)
