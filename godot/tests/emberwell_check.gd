extends Node
## The Emberwell Village battle (Proving Grounds 5, samples/emberwell_village.json, the owner's GLB and terrace-test map): the board shows the village from the GLB in place of the
## procedural terrain, repaired materials, burning animations, the owner's blocked cells, the terrace and its ramps, units on the ground, and the real battle running on it.
## godot --headless --path godot res://tests/emberwell_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [str(a), str(b), what])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_emberwell"
	var map := Terrain.load_map("res://samples/emberwell_village.json")
	eq([map.w, map.d], [20, 20], "the map is 20 x 20")
	var setup := WorldData.setup_for("pg_5", 1, true)
	ok(setup != null and setup.enemies.size() == 3, "pg_5 builds a battle with the owner's three enemies")
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = setup
	var t0 := Time.get_ticks_msec()
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	for i in 3:
		await get_tree().process_frame
	print("battle with the village built in %d ms" % (Time.get_ticks_msec() - t0))
	scenery(b)
	grid(b)
	framing(b)
	await playing(b)
	print("emberwell checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func scenery(b: BattleStage) -> void:
	var sc := b.board.scenery
	ok(not sc.is_empty(), "the board shows the village scenery, not the procedural terrain")
	ok(b.board.get_node_or_null("Terrain") == null, "no procedural terrain under it")
	eq(b.board.level, 0.42, "one level is the owner's 0.42")
	eq(b.board.floor_base, 0.0, "the village ground is at height 0")
	ok(sc.scenery_meshes > 500, "the village came in as separate meshes (%d)" % sc.scenery_meshes)
	ok(sc.merged.size() >= 20 and sc.merged.size() <= 80, "the static meshes are merged by material (%d meshes)" % sc.merged.size())
	ok(sc.animated >= 100, "the burning nodes stay separate and animated (%d)" % sc.animated)
	print("scenery: %d static meshes merged into %d, %d animated nodes with %d players, %d scenery triangles (merged only), %d materials repaired" % [sc.scenery_meshes, sc.merged.size(), sc.animated, sc.players, sc.triangles, sc.repaired])
	eq(sc.players, 140, "every one of the 140 animations has its own looping player")
	ok(sc.hidden >= 1, "the art-only smoke is hidden (%d nodes)" % sc.hidden)
	ok(sc.repaired >= 14, "the white materials were repaired (%d)" % sc.repaired)
	var white := 0
	for n in sc.root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m != null and m.albedo_color == Color.WHITE and m.albedo_texture == null and m.resource_name != "" and m.resource_name != "Well water":
				white += 1
	eq(white, 0, "no material is left plain white with no texture")
	var looping := 0
	for p in sc.root.find_children("Burn*", "AnimationPlayer", false, false):
		var a: Animation = (p as AnimationPlayer).get_animation(&"burn")
		if a.loop_mode == Animation.LOOP_LINEAR and (p as AnimationPlayer).is_playing():
			looping += 1
	eq(looping, 140, "all 140 are playing and looping")
	var coll := 0
	for m in sc.merged:
		coll += m.find_children("*", "CollisionObject3D", true, false).size()
	eq(coll, 0, "the scenery has no collision")
	# the village ground spans the board: x 0..20 and z 0..20 once placed
	var gx := false
	for m in sc.merged:
		if String(m.name).contains("Soil"):
			var ab: AABB = sc.root.transform * m.get_aabb()
			print("soil mesh spans x %.1f..%.1f, z %.1f..%.1f" % [ab.position.x, ab.end.x, ab.position.z, ab.end.z])
			gx = ab.position.x < 0.2 and ab.end.x > 19.8 and ab.position.z < 0.2 and ab.end.z > 19.8
	ok(gx, "the village ground covers the whole board (x 0 to 20, z 0 to 20)")


func grid(b: BattleStage) -> void:
	var g := b.battle.grid
	eq([g.width, g.depth], [20, 20], "the combat grid is 20 x 20")
	var blocked := 0
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://samples/emberwell_village.json")).rows
	for y in 20:
		for x in 20:
			if (rows[y].split(" ")[x] as String).ends_with("!"):
				blocked += 1
				ok(not g.can_stand(Vector2i(x, y)), "the owner's blocked cell (%d,%d) cannot be stood on" % [x, y])
	eq(blocked, 82, "82 blocked cells")
	# the terrace: one level (0.42), half-step ramps at both ends, at x 10 to 12
	for x in [10, 11, 12]:
		eq(g.height(Vector2i(x, 4)), 1.0, "the terrace at (%d,4) is one level" % x)
		eq(g.height(Vector2i(x, 3)), 0.5, "the ramp at (%d,3) is half a level" % x)
		eq(g.height(Vector2i(x, 7)), 0.5, "the ramp at (%d,7) is half a level" % x)
	eq(snappedf(b.board.top_point(11, 5).y, 0.001), 0.42, "a unit on the terrace stands 0.42 above the village ground")
	eq(snappedf(b.board.top_point(11, 10).y, 0.001), 0.0, "a unit on the street stands on the village ground")
	# a step from the ramp onto the terrace costs the cell entered and is allowed; the climb from the street is half steps
	eq(g.step_cost(Vector2i(11, 3), Vector2i(11, 4), 1), 1, "stepping from the ramp up onto the terrace is allowed")
	var r := g.reachable(Vector2i(9, 18), 99, 1)
	var open := 0
	for y in 20:
		for x in 20:
			if g.can_stand(Vector2i(x, y)):
				open += 1
	ok(r.cells().size() >= 300, "the King can walk to most of the village (%d of %d open cells)" % [r.cells().size(), open])
	for e in b.battle.enemies:
		ok(TacticalMath.ORTHOGONAL.any(func(d): return r.costs.has(e.cell + d)), "Alaric can walk up to %s" % e.data.display_name)


## The board against the screen's free area (between the HUD's top and bottom bands), from each quarter-turn view. The map is 20 rows deep, past the 16 to 19 the
## repo asks for, so this prints how far the board runs under the HUD (informational: it is the owner's own map).
func framing(b: BattleStage) -> void:
	var view := Vector2(1920, 1080)
	var free := BattleStage.free_rect(view)
	for turn in 4:
		var r: Rect2 = b.board.board_screen_rect(view)
		print("view %d: the board covers x %.0f..%.0f, y %.0f..%.0f; the free area is x %.0f..%.0f, y %.0f..%.0f; over by %.0f px (top) and %.0f px (bottom)" % [turn + 1, r.position.x, r.end.x, r.position.y, r.end.y, free.position.x, free.end.x, free.position.y, free.end.y, maxf(0.0, free.position.y - r.position.y), maxf(0.0, r.end.y - free.end.y)])
		ok(r.size.x <= view.x * 1.35, "view %d: the board is not much wider than the screen (%.0f px)" % [turn + 1, r.size.x])
		print("view %d: scrolling=%s range=%s across=%s" % [turn + 1, str(b.scrolling), str(b.scroll_range), str(b.board.scroll_across())])
		b.board.rotate_view(1)


func playing(b: BattleStage) -> void:
	var waited := 0.0
	while waited < 40.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	var bu := b.battle.current
	ok(bu != null and bu.team == 0, "the AI plays and a player's turn comes")
	var v: UnitView3D = b.views[bu]
	ok(v.position.distance_to(b.board.top_point(bu.cell.x, bu.cell.y)) < 0.02, "Alaric's sprite stands on his cell's ground")
	var r := b.battle.move_range(bu)
	var goal := bu.cell
	for c in r.cells():
		if r.cost_to(c) >= 3:
			goal = c
	b.walk(bu, goal)
	eq(bu.cell, goal, "Alaric walks to %s through the combat controller" % goal)
	await get_tree().create_timer(2.5).timeout
	ok(v.position.distance_to(b.board.top_point(goal.x, goal.y)) < 0.02, "the sprite walked onto the new cell's ground")
	# picking: the board's own ray picking finds the cell under a click on its top
	var all_picked := true
	for c in [Vector2i(2, 2), Vector2i(10, 10), Vector2i(11, 5), Vector2i(17, 17)]:
		var screen := b.board.cam.unproject_position(b.board.to_global(b.board.top_point(c.x, c.y)))
		if b.board.pick(screen) != c:
			all_picked = false
	ok(all_picked, "clicking a cell's centre on screen picks that cell")
