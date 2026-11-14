extends Node
## The diorama boundary standard (owner, Nov 2026): every map's board is built with the cliff rim (edge shader), the rim mist
## and the hanging overhangs, with no per-map setup. godot --headless --path godot res://tests/diorama_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var dir := DirAccess.open("res://samples")
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	var maps := 0
	for f in names:
		var m: Dictionary = Terrain.load_map("res://samples/" + f)
		if m.is_empty() or not m.has("tiles"):
			continue
		if m.has("scenery"):  # a scenery map (the owner's Last Benediction GLB) shows its own diorama in place of the procedural terrain, rim and overhangs
			print("%s: a scenery map, not checked for the procedural rim" % f)
			continue
		maps += 1
		var b := Board3D.new()
		add_child(b)
		b.setup(m)
		var terrain: MeshInstance3D = b.get_node_or_null("Terrain")
		ok(terrain != null, "%s: has terrain" % f)
		var rim := 0
		if terrain != null:
			for i in terrain.mesh.get_surface_count():
				var mat := terrain.mesh.surface_get_material(i)
				if mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.ends_with("diorama_edge.gdshader"):
					rim += 1
		ok(rim > 0, "%s: the cliff rim uses the diorama edge shader" % f)
		ok(b.get_node_or_null("Overhangs") != null, "%s: has the hanging overhangs" % f)
		for k in 2:
			var mist: MeshInstance3D = b.get_node_or_null("RimMist%d" % k)
			ok(mist != null and mist.material_override is ShaderMaterial, "%s: has rim mist sheet %d" % [f, k])
		# the warp leaves the ground line alone, is the same wherever it is asked, and tapers the bottom in
		var p := Vector3(1.3, 0.0, 2.2)
		ok(b._rim_warp(p) == p, "%s: the warp is pinned at the ground line" % f)
		var q := Vector3(0.0, -Board3D.BASE, 0.0)
		ok(b._rim_warp(q) == b._rim_warp(q), "%s: the warp is the same each time" % f)
		var corner := b._rim_warp(q)
		ok(corner.x > -0.8 and corner.z > -0.8, "%s: the bottom corner stays near the board (%s)" % [f, corner])
		b.queue_free()
	ok(maps >= 8, "checked the sample maps (%d)" % maps)
	print("diorama checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
