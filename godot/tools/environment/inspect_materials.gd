## Prints the StandardMaterial3D settings of a scenery GLB's materials (colour, textures, transparency, emission, blend).
##   godot --headless --path godot --script res://tools/environment/inspect_materials.gd -- path=res://art_src/environment/emberwell/emberwell.glb match=Smoke
extends SceneTree

func _init() -> void:
	var path := "res://art_src/environment/emberwell/emberwell.glb"
	var want := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("path="):
			path = a.substr(5)
		if a.begins_with("match="):
			want = a.substr(6)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(path, state)
	var root := doc.generate_scene(state)
	var seen := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null or seen.has(m):
				continue
			seen[m] = true
			var bm := m as BaseMaterial3D
			if bm == null or (want != "" and not bm.resource_name.contains(want)):
				continue
			print("%-40s albedo=%s tex=%s norm=%s rough=%.2f metal=%.2f transp=%d blend=%d emis=%s e=%.2f uv1=%s shading=%d cull=%d" % [bm.resource_name, str(bm.albedo_color), "Y" if bm.albedo_texture else "-", "Y" if bm.normal_texture else "-", bm.roughness, bm.metallic, bm.transparency, bm.blend_mode, str(bm.emission) if bm.emission_enabled else "-", bm.emission_energy_multiplier, str(bm.uv1_scale), bm.shading_mode, bm.cull_mode])
	root.free()
	quit(0)
