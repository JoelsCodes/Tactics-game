extends Node
## The real battle (BattleStage, scenes/battle.tscn) on the Last Benediction (Proving Grounds 4, samples/last_benediction.json): the board shows the owner's
## GLB cathedral in place of the procedural terrain, and every cell, unit and rule is the combat system's own.
## godot --headless --path godot res://tests/last_benediction_battle_check.tscn
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
	SaveSystem.dir = "user://test_saves_last_benediction_battle"
	var setup := WorldData.setup_for("pg_4", 1, true)
	ok(setup != null, "pg_4 builds a battle setup")
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = setup
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05  # the enemies play quickly (a fast scout acts first on this map)
	add_child(b)
	for i in 3:
		await get_tree().process_frame
	scenery(b)
	units_and_rules(b, setup)
	await first_players_turn(b, setup)
	await moving(b)
	print("last benediction battle checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func scenery(b: BattleStage) -> void:
	var bd := b.board
	ok(bd.map.has("scenery") and not bd.scenery.is_empty(), "the board shows the GLB scenery, not the procedural terrain")
	eq(bd.scenery.floors.size(), 121, "the scenery brought its 121 playable floors")
	eq(bd.scenery.merged.size() <= 40, true, "the scenery is merged by material (%d meshes)" % bd.scenery.merged.size())
	var worst_h := 0.0
	var worst_xz := 0.0
	var seen := 0
	for y in 11:
		for x in 11:
			var tp := bd.top_point(x, y)
			var key := Vector2i(x, 10 - y)  # the board's row y is the scenery's row 10 - y
			var fl: MeshInstance3D = bd.scenery.floors.get(key)
			if fl == null:
				continue
			seen += 1
			worst_h = maxf(worst_h, absf(tp.y - bd.scenery.tops[key]))
			worst_xz = maxf(worst_xz, Vector2(fl.global_position.x - tp.x, fl.global_position.z - tp.z).length())
	eq(seen, 121, "every board cell has a scenery floor")
	ok(worst_h < 0.002, "the board's cell heights are the GLB floors' (worst %.4f)" % worst_h)
	ok(worst_xz < 0.002, "the board's cell centres are the GLB floors' (worst %.4f)" % worst_xz)
	# the board's own picking agrees: a ray straight down onto a cell's top picks that cell
	var all_picked := true
	for c in [Vector2i(0, 0), Vector2i(5, 5), Vector2i(10, 10), Vector2i(4, 9), Vector2i(5, 2)]:
		var p := bd.top_point(c.x, c.y)
		var screen := bd.cam.unproject_position(bd.to_global(p))
		if bd.pick(screen) != c:
			all_picked = false
	ok(all_picked, "clicking a cell's centre on screen picks that cell")


func units_and_rules(b: BattleStage, setup: BattleSetup) -> void:
	var g := b.battle.grid
	var dm := b.battle.deployment
	eq(g.width, 11, "the combat grid is 11 wide")
	eq(dm.king.cell, setup.king_cell, "Alaric stands on his spawn")
	var kv: UnitView3D = b.views[dm.king]
	ok(kv.position.distance_to(b.board.top_point(dm.king.cell.x, dm.king.cell.y)) < 0.01, "Alaric's sprite stands on his cell's floor")
	eq(b.battle.enemies.size(), 4, "four enemies")
	# the 13 blocked tiles of the navigation JSON cannot be stood on; everything else that has no flag can
	var nav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/last_benediction_nav.json"))
	var blocked := 0
	var bad := 0
	for t in nav.tiles:
		var c := Vector2i(int(t.x), 10 - int(t.y))  # the board's rows run the other way
		if t.blocked:
			blocked += 1
			if g.can_stand(c):
				bad += 1
		elif not g.can_stand(c) and not g.is_occupied(c):
			bad += 1
	eq(blocked, 13, "13 blocked tiles")
	eq(bad, 0, "the board's blocked and open tiles are the navigation JSON's")
	ok(not g.can_stand(Vector2i(5, 1)), "the altar cannot be stood on")
	ok(g.can_stand(Vector2i(5, 2)) and g.height(Vector2i(5, 2)) == 1.0, "the objective in front of the altar can be stood on, one level up")
	# stepping up one level costs the tile entered; there is no taller step on this map
	ok(g.height(Vector2i(3, 2)) - g.height(Vector2i(3, 3)) == 1.0 and g.step_cost(Vector2i(3, 3), Vector2i(3, 2), 1) == 1, "a step up of one level is allowed")
	var tallest := 0.0
	for y in 11:
		for x in 11:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if g.in_bounds(n):
					tallest = maxf(tallest, absf(g.height(Vector2i(x, y)) - g.height(n)))
	eq(tallest, 1.0, "no step on the map is taller than one level")


func moving(b: BattleStage) -> void:
	var bu := b.battle.current
	ok(bu != null and bu.team == 0, "the battle starts on a player's turn")
	if bu == null or bu.team != 0:
		return
	var r := b.battle.move_range(bu)
	var goal := bu.cell
	for c in r.cells():
		if c != bu.cell and r.cost_to(c) >= 3 and c.y < goal.y:
			goal = c
	ok(goal != bu.cell, "there is a cell to walk to")
	b.walk(bu, goal)  # the stage walks the unit through the combat controller (BattleStage.walk) and animates its sprite
	eq(bu.cell, goal, "%s walks to %s through the combat controller" % [bu.data.display_name, goal])
	await get_tree().create_timer(2.5).timeout
	var v: UnitView3D = b.views[bu]
	ok(v.position.distance_to(b.board.top_point(goal.x, goal.y)) < 0.02, "the sprite walked to the new cell's floor (at %s)" % str(v.position))


func first_players_turn(b: BattleStage, setup: BattleSetup) -> void:
	var hp0 := {}
	for u in b.battle.all_units():
		hp0[u] = u.hp
	var waited := 0.0
	while waited < 40.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	var moved := 0
	for pair in setup.enemies:
		for e in b.battle.enemies:
			if e.data == pair[0] and e.cell != pair[1]:
				moved += 1
	var hurt := 0
	for u in hp0:
		if u.hp < hp0[u]:
			hurt += 1
	print("the enemies played their opening turns in %.2f s: %d moved, %d units were hurt" % [waited, moved, hurt])
	ok(b.battle.current != null and b.battle.current.team == 0, "play reaches a player's turn after the enemies' opening turns")
	ok(moved > 0 or hurt > 0, "the enemy AI acted on this board (it moved or hurt someone)")
