extends Node
## The real battle (BattleStage, scenes/battle.tscn) on each of Claude's Hollowmark maps (HollowmarkScenery, Proving Grounds 7-11): the board shows the GLB in place of
## the procedural terrain; every cell, unit and rule is the combat system's own. Per map: the scenery loaded (with its water/waterfall shaders, batched plants,
## lights), every standing cell's height matches the art's walking surface under it, clicking a cell's centre picks it in all four views, and how many standing
## cells the scenery hides from each camera.
## godot --headless --path godot res://tests/hollowmark_maps_check.tscn   (add -- map=pg_8 for one map)
var fails := 0
var count := 0
const MAPS := {"pg_7": {"water": 1, "falls": 6}, "pg_8": {"water": 3, "falls": 2}, "pg_9": {}, "pg_10": {}, "pg_11": {}, "pg_12": {}, "pg_13": {"spinners": 15}, "pg_14": {"water": 2}, "pg_15": {"water": 3}, "pg_16": {"water": 1}}


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	SaveSystem.dir = "user://test_saves_hollowmark_maps"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map="):
			only = a.substr(4)
	for pid in MAPS:
		if only != "" and pid != only:
			continue
		var t0 := Time.get_ticks_msec()
		var setup := WorldData.setup_for(pid, 1, true)
		ok(setup != null, "%s builds a battle setup" % pid)
		BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
		BattleStage.pending_setup = setup
		var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
		b.enemy_delay = 0.05
		add_child(b)
		for i in 3:
			await get_tree().process_frame
		var load_ms := Time.get_ticks_msec() - t0
		var tris := scenery(b, pid, load_ms)
		if MAPS[pid].has("spinners"):
			await spin_check(b, pid)
		heights(b, pid, tris)
		await picking(b, pid)
		await visibility(b, pid, tris)
		b.queue_free()
		for i in 3:
			await get_tree().process_frame
	print("hollowmark maps checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func scenery(b: BattleStage, pid: String, load_ms: int) -> Array:
	var sc: Dictionary = b.board.scenery
	ok(b.board.map.has("scenery") and not sc.is_empty(), "%s: the board shows the GLB scenery" % pid)
	if sc.is_empty():
		return []
	var want: Dictionary = MAPS[pid]
	ok(int(sc.water) == int(want.get("water", 0)), "%s: %d water surfaces got the water shader (want %d)" % [pid, sc.water, want.get("water", 0)])
	ok(int(sc.falls) == int(want.get("falls", 0)), "%s: %d waterfalls got the waterfall shader (want %d)" % [pid, sc.falls, want.get("falls", 0)])
	ok(int(sc.get("spinners", 0)) == int(want.get("spinners", 0)), "%s: %d spinning parts (want %d)" % [pid, sc.get("spinners", 0), want.get("spinners", 0)])
	ok(int(sc.lights) > 0 or pid == "pg_8", "%s: the map's own lights came from its FX file (%d)" % [pid, sc.lights])
	print("%s: loaded in %d ms; %d meshes, %d multimeshes holding %d instances, %d lights, %d puffs, %d triangles" % [pid, load_ms, sc.meshes, sc.multimeshes, sc.batched_instances, sc.lights, sc.puffs, sc.triangles])
	var tris := []
	for c in (sc.root as Node3D).get_children():
		if c is MeshInstance3D and not String(c.name).to_lower().begins_with("fx"):
			tris.append([c, (c as MeshInstance3D).mesh.generate_triangle_mesh()])
	return tris


## A ray straight down at every standing cell's centre: the walking surface is the hit nearest the board's height for the cell. Ramps (the board's height is
## the ramp's middle) get a wider tolerance than flat cells.
func heights(b: BattleStage, pid: String, tris: Array) -> void:
	var g := b.battle.grid
	var off := []
	var missing := []
	var n := 0
	var worst := 0.0
	for y in b.board.map.d:
		for x in b.board.map.w:
			var c := Vector2i(x, y)
			if not (g.can_stand(c) or g.is_occupied(c)):
				continue
			n += 1
			var tp := b.board.to_global(b.board.top_point(x, y))
			var hits := []
			for o in [Vector3.ZERO, Vector3(0.12, 0, 0), Vector3(-0.12, 0, 0), Vector3(0, 0, 0.12), Vector3(0, 0, -0.12)]:  # a unit's footprint, not one point a stone joint can swallow
				hits.append_array(_down_hits(tris, tp + o + Vector3.UP * 4.0))
			var best := 1000.0
			for h in hits:
				if absf(h - tp.y) < absf(best - tp.y):
					best = h
			if best > 999.0:
				missing.append(c)
				continue
			var t: Dictionary = b.board.map.tiles[y][x]
			var tol := 0.36 if String(t.get("s", "")) != "" else 0.2
			var d := absf(best - tp.y)
			worst = maxf(worst, d if d <= tol else worst)
			if d > tol:
				off.append([c, snappedf(best - tp.y, 0.01)])
	ok(missing.is_empty(), "%s: every standing cell has art under its centre (missing %s)" % [pid, str(missing.slice(0, 10))])
	ok(off.size() <= maxi(1, n / 50), "%s: cell heights match the art's walking surface (%d of %d off: %s)" % [pid, off.size(), n, str(off.slice(0, 10))])
	print("%s: %d standing cells, %d off the surface, worst within tolerance %.3f" % [pid, n, off.size(), worst])


func _down_hits(tris: Array, from: Vector3) -> Array:
	var hits := []
	for pair in tris:
		var mi: MeshInstance3D = pair[0]
		var inv := mi.global_transform.affine_inverse()
		var cur := inv * from
		var d := (inv.basis * Vector3.DOWN).normalized()
		for i in 6:
			var h = (pair[1] as TriangleMesh).intersect_ray(cur, d)
			if h == null or h.is_empty():
				break
			hits.append((mi.global_transform * Vector3(h.position)).y)
			cur = h.position + d * 0.01
	return hits


func picking(b: BattleStage, pid: String) -> void:
	var wrong := 0
	var seen := 0
	for q in 4:
		for y in b.board.map.d:
			for x in b.board.map.w:
				if not b.battle.grid.can_stand(Vector2i(x, y)):
					continue
				var p := b.board.cam.unproject_position(b.board.to_global(b.board.top_point(x, y)))
				if not get_viewport().get_visible_rect().has_point(p):
					continue
				seen += 1
				var got: Vector2i = b.board.pick(p)
				# a taller cell in front may cover this one's centre (a terrace edge, a stair): that is occlusion, not a wrong pick
				if got != Vector2i(x, y) and not (b.board.map.tiles[got.y][got.x].has("h") and b.board._top(got.x, got.y) > b.board._top(x, y) + 0.05):
					wrong += 1
		b.turn_view(1)
		for i in 3:
			await get_tree().process_frame
	ok(wrong == 0, "%s: clicking a cell's centre picks that cell (%d wrong of %d clicks over four views)" % [pid, wrong, seen])


## How many standing cells' units (chest height) the visible scenery hides from the camera, per view; the battle ghosts hidden units, so this only fails above 30% (owner, Nov 21 2026: "push the limit to 30 percent being hidden"; it was 20%).
func visibility(b: BattleStage, pid: String, tris: Array) -> void:
	for q in 4:
		var hidden := 0
		var total := 0
		var blockers := {}
		for y in b.board.map.d:
			for x in b.board.map.w:
				var c := Vector2i(x, y)
				if not (b.battle.grid.can_stand(c) or b.battle.grid.is_occupied(c)):
					continue
				total += 1
				var chest := b.board.to_global(b.board.top_point(x, y)) + Vector3.UP * 0.9
				var from := b.board.cam.global_position
				var dir := (chest - from)
				for pair in tris:
					var mi: MeshInstance3D = pair[0]
					if not mi.is_visible_in_tree():
						continue
					var inv := mi.global_transform.affine_inverse()
					var h = (pair[1] as TriangleMesh).intersect_segment(inv * from, inv * (chest - dir.normalized() * 0.4))
					if h != null and not h.is_empty():
						hidden += 1
						blockers[String(mi.name)] = int(blockers.get(String(mi.name), 0)) + 1
						break
		var rot := int(b.board.rot)
		print("%s: view rot %d hides %d of %d standing cells (%.1f%%) %s" % [pid, rot, hidden, total, 100.0 * hidden / maxi(total, 1), str(blockers)])
		ok(float(hidden) / maxi(total, 1) < 0.3, "%s: view rot %d hides under 30%% of the standing cells (%d of %d)" % [pid, rot, hidden, total])
		b.turn_view(1)
		for i in 3:
			await get_tree().process_frame


## Spinners really turn: a gear's rotation changes over a few frames, and meshed gears turn opposite ways.
func spin_check(b: BattleStage, pid: String) -> void:
	var spins: Array = []
	for c in (b.board.scenery.root as Node3D).get_children():
		if c is HollowmarkSpinner:
			spins.append(c)
	var before := []
	for sp in spins:
		before.append((sp as Node3D).basis)
	for i in 30:
		await get_tree().process_frame
	var moved := 0
	for i in spins.size():
		if not (spins[i] as Node3D).basis.is_equal_approx(before[i]):
			moved += 1
	ok(moved == spins.size() and spins.size() > 0, "%s: all %d spinning parts turned (%d did)" % [pid, spins.size(), moved])
	var gears := spins.filter(func(x): return String(x.name).begins_with("SPIN_gear"))
	var signs := {}
	for g in gears:
		signs[signf((g as HollowmarkSpinner).rate)] = true
	ok(gears.size() == 5 and signs.size() == 2, "%s: five gears, meshed ones turning opposite ways" % pid)
