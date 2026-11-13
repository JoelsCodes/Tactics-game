## Loads the Last Benediction GLB with Godot's glTF importer and reports what came out: nodes, meshes, materials, textures,
## the NONPLAY / playable split and the tile floors. Run:
##   godot --headless --path godot --script res://tools/environment/inspect_glb.gd -- path=res://art_src/environment/last_benediction/last_benediction.glb
extends SceneTree

func _init() -> void:
	var path := "res://art_src/environment/last_benediction/last_benediction.glb"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("path="):
			path = a.substr(5)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		print("LOAD FAILED err=%d" % err)
		quit(1)
		return
	var root := doc.generate_scene(state)
	if root == null:
		print("GENERATE FAILED")
		quit(1)
		return
	var meshes := 0
	var nonplay := 0
	var playable := 0
	var mats := {}
	var tex := {}
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		if n is MeshInstance3D:
			meshes += 1
			var mi: MeshInstance3D = n
			var nm := String(n.name)
			if nm.begins_with("NONPLAY"):
				nonplay += 1
			if nm.begins_with("playable"):
				playable += 1
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var m := mi.get_active_material(s)
					if m is BaseMaterial3D:
						var bm: BaseMaterial3D = m
						mats[bm.resource_name if bm.resource_name != "" else "unnamed"] = true
						for slot in [bm.albedo_texture, bm.normal_texture, bm.roughness_texture]:
							if slot != null:
								tex[slot.resource_path if slot.resource_path != "" else str(slot.get_instance_id())] = true
	print("root: %s, children %d" % [root.name, root.get_child_count()])
	print("MeshInstance3D: %d (playable floor %d, NONPLAY %d)" % [meshes, playable, nonplay])
	print("materials: %d, distinct textures: %d" % [mats.size(), tex.size()])
	root.free()
	quit(0)
