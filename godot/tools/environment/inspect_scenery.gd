## Loads a scenery GLB with Godot's glTF importer and reports the nodes, meshes, materials and animations (which nodes the animations drive).
##   godot --headless --path godot --script res://tools/environment/inspect_scenery.gd -- path=res://art_src/environment/emberwell/emberwell.glb
extends SceneTree

func _init() -> void:
	var path := "res://art_src/environment/emberwell/emberwell.glb"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("path="):
			path = a.substr(5)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		print("LOAD FAILED")
		quit(1)
		return
	var root := doc.generate_scene(state)
	var meshes := 0
	var tris := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	print("root %s: %d children, %d MeshInstance3D, %d triangles" % [root.name, root.get_child_count(), meshes, tris])
	var ap := root.find_children("*", "AnimationPlayer", true, false)
	print("AnimationPlayers: %d" % ap.size())
	if ap.size() > 0:
		var p: AnimationPlayer = ap[0]
		var driven := {}
		var props := {}
		for name in p.get_animation_list():
			var a := p.get_animation(name)
			for t in a.get_track_count():
				var np := a.track_get_path(t)
				driven[String(np.get_concatenated_names())] = true
				props[String(np.get_concatenated_subnames())] = true
		print("animations %d, driving %d nodes, properties %s, first length %.2f s loop %d" % [p.get_animation_list().size(), driven.size(), str(props.keys()), p.get_animation(p.get_animation_list()[0]).length, p.get_animation(p.get_animation_list()[0]).loop_mode])
		print("sample driven nodes: %s" % str(driven.keys().slice(0, 6)))
	root.free()
	quit(0)
