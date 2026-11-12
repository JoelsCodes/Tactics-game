extends Node
## Headless: the Proving Grounds (Skirmish): compact maps, five levels each, open with the base. godot --headless --path godot res://tests/skirmish_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var c := CampaignState.new()
	ok(WorldData.map_state(c, "pg_1") == "locked", "closed before the base opens")
	c.unlock_area(&"base")
	ok(c.is_area_unlocked(&"proving"), "the Proving Grounds open with the base")
	for id in Skirmish.MAPS:
		ok(WorldData.map_state(c, id) == "cleared", "%s can be played at once (no story)" % id)
		var m := Terrain.load_map(Skirmish.MAPS[id])
		var g := TacticalGrid.from_map(m)
		var tiles := 0
		for y in g.depth:
			for x in g.width:
				if not g.is_void(Vector2i(x, y)):
					tiles += 1
		ok(tiles >= 100 and tiles <= 220, "%s is FFT-sized (%d tiles)" % [id, tiles])
		ok(g.width <= 16, "%s: depth within the screen" % id)
		for lv in range(1, 6):
			var s := WorldData.setup_for(id, lv, true)
			ok(s != null and s.enemies.size() == 4, "%s level %d builds with four foes" % [id, lv])
			if s == null:
				continue
			ok(s.enemies.all(func(e): return e[0].stats.level == Skirmish.LEVELS[lv - 1]), "%s level %d: foes at level %d" % [id, lv, Skirmish.LEVELS[lv - 1]])
			ok(g.can_stand(s.king_cell) and s.enemies.all(func(e): return g.can_stand(e[1])), "%s: everyone starts on ground they can stand on" % id)
			var r := g.reachable(s.king_cell, 999, 1)
			ok(s.enemies.all(func(e): return TacticalMath.ORTHOGONAL.any(func(d): return r.costs.has(e[1] + d))), "%s: Alaric can walk to every foe" % id)
	print("skirmish checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
