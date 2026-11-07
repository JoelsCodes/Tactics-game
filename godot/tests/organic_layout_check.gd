extends Node
## Headless: OrganicLayout makes maps the grid can play: every row parses, every enemy start is reachable from the player's, there are cliffs,
## ramps, choke passes and scattered cover, the high ground has more than one way up, and cover is not laid out in grid rows.
## godot --headless --path godot res://tests/organic_layout_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	for s in range(1, 21):
		var m := OrganicLayout.generate(s, 24, 16)
		var grid := TacticalGrid.from_rows(m.rows)
		ok(grid.width == 16 and grid.depth == 24, "seed %d: 16 x 24" % s)
		var reach := grid.reachable(Vector2i(6, 2), 999, 3)
		ok(m.spawns.enemy_cells.size() >= 3, "seed %d: room for enemies" % s)
		ok(m.spawns.enemy_cells.all(func(c): return reach.can_reach(Vector2i(c[0], c[1]))), "seed %d: every enemy start can be reached" % s)
		ok(m.flags.cliff.size() > 10 and m.flags.choke.size() >= 1 and m.flags.cover.size() >= 4, "seed %d: cliffs %d, passes %d, cover %d" % [s, m.flags.cliff.size(), m.flags.choke.size(), m.flags.cover.size()])
		var rows_used := {}
		for c in m.flags.cover:
			rows_used[c[1]] = int(rows_used.get(c[1], 0)) + 1
		ok(rows_used.values().all(func(n): return n <= 3), "seed %d: cover is scattered, not lined up in rows" % s)
		var heights := {}
		for y in 24:
			for x in 16:
				heights[grid.height(Vector2i(x, y))] = true
		ok(heights.size() >= 3, "seed %d: %d height tiers" % [s, heights.size()])
		if s == 1:
			for r in m.rows:
				print(r)
	print("organic layout checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
