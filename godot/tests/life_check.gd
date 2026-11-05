extends Node
## Headless: the life on chapter three's and four's maps (BoardLife): every decoration is a known type inside the map and off every start tile, each map has a good
## amount of it and a weather, the board builds it, and the real lights stay within the cap.
## godot --headless --path godot res://tests/life_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	for set_name in ["crucible", "mountain"]:
		for n in range(1, 6):
			var path := "res://samples/%s_%d.json" % [set_name, n]
			var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var label := "%s %d" % [set_name, n]
			var life: Array = raw.get("life", [])
			ok(life.size() >= 20, "%s: plenty of life (%d items)" % [label, life.size()])
			ok(String(raw.get("ambient", "")) in BoardLife.AMBIENTS, "%s: a weather (%s)" % [label, raw.get("ambient", "")])
			var sp: Dictionary = raw.spawns
			var starts := {}
			for c in [sp.king, sp.captain] + sp.stones + sp.enemies.map(func(e): return e.at):
				starts[Vector2i(int(c[0]), int(c[1]))] = true
			var bad := 0
			var types := {}
			for it in life:
				types[it.type] = true
				if not (String(it.type) in BoardLife.TYPES) or starts.has(Vector2i(int(it.x), int(it.y))):
					bad += 1
			ok(bad == 0, "%s: every decoration is a known type and off the start tiles" % label)
			ok(types.size() >= 5, "%s: %d kinds of decoration" % [label, types.size()])
			var m: Dictionary = Terrain.load_map(path)
			var b := Board3D.new()
			add_child(b)
			b.setup(m)
			ok(b.life != null and b.life.count == life.size(), "%s: the board builds all of it (%d)" % [label, b.life.count if b.life != null else -1])
			ok(b.life.lights <= BoardLife.MAX_LIGHTS, "%s: %d real lights, at most %d" % [label, b.life.lights, BoardLife.MAX_LIGHTS])
			ok(b.life.get_node_or_null("Ambient_" + String(raw.ambient)) != null, "%s: the weather is running" % label)
			b.queue_free()
	print("life checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
