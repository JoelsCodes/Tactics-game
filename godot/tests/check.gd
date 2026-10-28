extends Node
## Headless check that every sample map builds from the tile art in all four rotations and every
## character's animations load: godot --headless --path godot res://tests/check.tscn

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var t := Terrain.new()
	add_child(t)
	for path in ["res://samples/all_terrains.json", "res://samples/grass_hills.json"]:
		var m := Terrain.load_map(path)
		ok(m.w > 0 and m.d > 0, path + " parses")
		for r in 4:
			t.rot = r
			t.show_map(m)
			await get_tree().process_frame
			ok(t.blocks.size() == m.w * m.d, "%s rot %d builds every tile" % [path, r])
		for row in m.tiles:
			for c in row:
				ok(Terrain.LOOK.has(c.t), "%s terrain %s has a look" % [path, c.t])
	for k in Terrain.LOOK:
		var L: Dictionary = Terrain.LOOK[k]
		if L.get("void"):
			continue
		ok(ResourceLoader.exists("res://assets/tiles/side_%s_l.png" % L.side), "side strip " + L.side)
		var top := "res://assets/tiles/ground_%s.png" % L.top if L.top in Terrain.SEAMLESS and not L.has("water") and not L.get("lava") else "res://assets/tiles/%s_00.png" % L.top
		ok(ResourceLoader.exists(top), "top " + top)
	var need := ["idle_f", "idle_b", "ready_f", "ready_b", "walk_f", "walk_b", "hit_f", "hit_b", "attack", "cast", "victory", "ko"]
	for ch in Character.names():
		var sf: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		ok(sf != null, ch + " frames")
		for a in need:
			ok(sf != null and sf.has_animation(a) and sf.get_frame_count(a) > 0, ch + " " + a)
			ok(Character.meta(ch).anims.has(a), ch + " meta " + a)
	print("checks done, %d failed" % fails)
	get_tree().quit(1 if fails else 0)
