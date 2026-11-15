extends Node
## The real battle (BattleStage, scenes/battle.tscn) on the Sacred Canal Bridge (Proving Grounds 6, samples/sacred_canal.json): the board shows the owner's GLB in place of the
## procedural terrain; every cell, unit and rule is the combat system's own. Checks the grid against the owner's navigation JSON (160 cells), every cell's height against the
## GLB's real surface, picking (the overlay's cells) in all four views, and which cells' units the scenery would hide.
## godot --headless --path godot res://tests/sacred_canal_battle_check.tscn
var fails := 0
var count := 0
var tris: Array = []  ## [MeshInstance3D, TriangleMesh] of the merged scenery
const KNOWN_PROP_CELLS: Array[Vector2i] = [Vector2i(0, 21), Vector2i(9, 21), Vector2i(0, 23), Vector2i(8, 23), Vector2i(9, 23)]


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, str(a), str(b)])


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	SaveSystem.dir = "user://test_saves_sacred_canal_battle"
	var setup := WorldData.setup_for("pg_6", 1, true)
	ok(setup != null, "pg_6 builds a battle setup")
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = setup
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	for i in 3:
		await get_tree().process_frame
	scenery(b)
	grid(b, setup)
	heights(b)
	await picking(b)
	await visibility(b)
	await first_players_turn(b, setup)
	await moving(b)
	print("sacred canal battle checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func scenery(b: BattleStage) -> void:
	var bd := b.board
	ok(bd.map.has("scenery") and not bd.scenery.is_empty(), "the board shows the GLB scenery, not the procedural terrain")
	eq(bd.scenery.canal, 1, "the canal got the owner's water shader")
	ok(bd.scenery.merged.size() <= 100, "the scenery is merged by material (%d meshes from %d)" % [bd.scenery.merged.size(), bd.scenery.scenery_meshes])
	eq(bd.scenery.scenery_meshes, 143, "the GLB's 143 meshes arrived")
	var water := 0
	for m in bd.scenery.merged:
		var mi: MeshInstance3D = m
		tris.append([mi, mi.mesh.generate_triangle_mesh()])
		if mi.mesh.surface_get_material(0) is ShaderMaterial:
			water += 1
	eq(water, 1, "one merged mesh carries the water shader")
	ok(absf(float(bd.scenery.deck_top) - 3.461) < 0.01, "the deck top was read from the mesh (%.3f)" % float(bd.scenery.deck_top))
	print("scenery: %d merged meshes, %d triangles, deck top %.3f" % [bd.scenery.merged.size(), bd.scenery.triangles, bd.scenery.deck_top])


## The owner's navigation file against the board: x (depth) 7 - nav x, y (the long side) = nav y; the 160 cells stand, everything else is void.
func grid(b: BattleStage, setup: BattleSetup) -> void:
	var g := b.battle.grid
	eq(g.width, 10, "the combat grid is 10 deep (x, up the screen)")
	eq(b.board.map.d, 24, "the combat grid is 24 long (y, left to right)")
	var nav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/sacred_canal_nav.json"))
	eq(nav.tiles.size(), 160, "the navigation file has 160 cells")
	var nav_cells := {}
	var bad := 0
	for t in nav.tiles:
		var c := Vector2i(7 - int(t.x), int(t.y))
		nav_cells[c] = true
		if not t.walkable or int(t.elevation) != 0:
			bad += 1
		if not g.can_stand(c) and not g.is_occupied(c):
			bad += 1
	eq(bad, 0, "every one of the navigation JSON's cells can be stood on, all at elevation 0")
	var extra := 0
	for y in 24:
		for x in 10:
			if not nav_cells.has(Vector2i(x, y)) and (g.can_stand(Vector2i(x, y)) or g.is_occupied(Vector2i(x, y))):
				extra += 1
	eq(extra, 0, "the board has no cell the navigation JSON does not have")
	eq(nav_cells.size(), 160, "160 unique cells")
	var bridge := 0
	var landing := 0
	for t in nav.tiles:
		if t.region == "bridge":
			bridge += 1
		else:
			landing += 1
	eq([bridge, landing], [120, 40], "6x20 bridge and 10x4 landing")
	var dm := b.battle.deployment
	eq(dm.king.cell, setup.king_cell, "Alaric stands on his spawn")
	eq(b.battle.enemies.size(), 4, "four enemies")
	var kv: UnitView3D = b.views[dm.king]
	ok(kv.position.distance_to(b.board.top_point(dm.king.cell.x, dm.king.cell.y)) < 0.01, "Alaric's sprite stands on his cell's deck")


## A ray straight down at every cell's centre: the highest surface at or below the unit's head that is within 0.35 of the board's height for the cell
## is the walking surface, and nothing of the scenery may stand within a unit's height above it (no parapet, bench or lantern on a walkable cell).
func heights(b: BattleStage) -> void:
	var worst := 0.0
	var worst_cell := Vector2i.ZERO
	var missing := 0
	var blocked := []
	for y in 24:
		for x in 10:
			if not (b.battle.grid.can_stand(Vector2i(x, y)) or b.battle.grid.is_occupied(Vector2i(x, y))):
				continue
			var tp := b.board.to_global(b.board.top_point(x, y))
			var hits := _down_hits(tp + Vector3.UP * 6.0)
			var surface := -1000.0
			for h in hits:
				if absf(h - tp.y) < 0.35 and absf(h - tp.y) < absf(surface - tp.y):
					surface = h
			if surface < -999.0:
				missing += 1
				continue
			if absf(surface - tp.y) > worst:
				worst = absf(surface - tp.y)
				worst_cell = Vector2i(x, y)
			for h in hits:
				if h > surface + 0.4 and h < surface + 1.6:
					blocked.append(Vector2i(x, y))
					break
	eq(missing, 0, "every walkable cell has deck under its centre")
	ok(worst < 0.1, "the board's cell heights are the GLB deck's (worst %.3f at %s)" % [worst, str(worst_cell)])
	# KNOWN (owner's art vs the owner's nav, reported in the HANDOFF): a planter with hedges on (0, 21) and (9, 21), stone piers on (0, 23), (8, 23) and (9, 23)
	eq(blocked, KNOWN_PROP_CELLS, "the only walkable cells with scenery standing on them are the five known landing-corner props")
	print("height test: worst deviation %.3f at %s, %d blocked cells %s" % [worst, str(worst_cell), blocked.size(), str(blocked)])


func _down_hits(from: Vector3) -> Array:
	var hits := []
	for pair in tris:
		var mi: MeshInstance3D = pair[0]
		var inv := mi.global_transform.affine_inverse()
		var o := inv * from
		var d := (inv.basis * Vector3.DOWN).normalized()
		# a triangle mesh gives one hit per ray, so cast down repeatedly past each hit
		var cur := o
		for i in 8:
			var h = (pair[1] as TriangleMesh).intersect_ray(cur, d)
			if h == null or h.is_empty():
				break
			hits.append((mi.global_transform * Vector3(h.position)).y)
			cur = h.position + d * 0.01
	return hits


## The overlay's cells are the board's: clicking a cell's centre on screen picks that cell, in all four views.
func picking(b: BattleStage) -> void:
	var wrong := 0
	var seen := 0
	for q in 4:
		for y in 24:
			for x in 10:
				if not b.battle.grid.can_stand(Vector2i(x, y)):
					continue
				var p := b.board.cam.unproject_position(b.board.to_global(b.board.top_point(x, y)))
				if not get_viewport().get_visible_rect().has_point(p):
					continue  # scrolled off screen in this view
				seen += 1
				if b.board.pick(p) != Vector2i(x, y):
					wrong += 1
		b.turn_view(1)
		for i in 3:
			await get_tree().process_frame
	eq(wrong, 0, "clicking a cell's centre on screen picks that cell (%d clicks over four views)" % seen)


## Which units the scenery would hide: a ray from the camera to a unit's chest (0.9 above the deck) hits scenery first. The battle shows a see-through silhouette
## for those (BattleStage.GHOST_*), so this reports how many there are rather than failing on a few.
func visibility(b: BattleStage) -> void:
	var rows := []
	for q in 4:
		var hidden := 0
		var total := 0
		var list := []
		for y in 24:
			for x in 10:
				if not (b.battle.grid.can_stand(Vector2i(x, y)) or b.battle.grid.is_occupied(Vector2i(x, y))):
					continue
				var chest := b.board.to_global(b.board.top_point(x, y)) + Vector3.UP * 0.9
				total += 1
				if _blocked_from_camera(b.board.cam, chest):
					hidden += 1
					list.append(Vector2i(x, y))
		rows.append("view %d: %d of %d standing cells hidden (%.1f%%) %s" % [q + 1, hidden, total, 100.0 * hidden / total, str(list.slice(0, 12))])
		ok(float(hidden) / total < 0.12, "view %d hides under 12%% of the standing cells (%d; the count shifts a little with where the camera has scrolled)" % [q + 1, hidden])
		b.turn_view(1)
		for i in 3:
			await get_tree().process_frame
	for r in rows:
		print(r)


func _blocked_from_camera(cam: Camera3D, target: Vector3) -> bool:
	var from := cam.global_position
	var span := from.distance_to(target)
	for pair in tris:
		var mi: MeshInstance3D = pair[0]
		if not mi.visible:
			continue  # a set the view hides (the gate side seen from behind the gate)
		var inv := mi.global_transform.affine_inverse()
		var o := inv * from
		var d := (inv * target) - o
		var h = (pair[1] as TriangleMesh).intersect_ray(o, d.normalized())
		if h != null and not h.is_empty():
			var hit_pos: Vector3 = mi.global_transform * Vector3(h.position)
			if from.distance_to(hit_pos) < span - 0.15:
				return true
	return false


func moving(b: BattleStage) -> void:
	var bu := b.battle.current
	ok(bu != null and bu.team == 0, "the battle starts on a player's turn")
	if bu == null or bu.team != 0:
		return
	var r := b.battle.move_range(bu)
	var goal := bu.cell
	for c in r.cells():
		if c != bu.cell and r.cost_to(c) >= 3 and c.y > goal.y:
			goal = c
	ok(goal != bu.cell, "there is a cell to walk to")
	b.walk(bu, goal)
	eq(bu.cell, goal, "%s walks to %s through the combat controller" % [bu.data.display_name, goal])
	await get_tree().create_timer(2.5).timeout
	var v: UnitView3D = b.views[bu]
	ok(v.position.distance_to(b.board.top_point(goal.x, goal.y)) < 0.02, "the sprite walked to the new cell's deck (at %s)" % str(v.position))


func first_players_turn(b: BattleStage, setup: BattleSetup) -> void:
	var waited := 0.0
	while waited < 40.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	ok(b.battle.current != null and b.battle.current.team == 0, "play reaches a player's turn")
	var moved := 0
	for pair in setup.enemies:
		for e in b.battle.enemies:
			if e.data == pair[0] and e.cell != pair[1]:
				moved += 1
	print("the enemies' opening turns took %.2f s; %d moved" % [waited, moved])
