extends SceneTree
## Exercise the engine GLB loader inside the Hollowmark project without touching a battle.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _blender_vec(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[2]), -float(values[1]))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected a single build directory")
		quit(2)
		return
	var folder: String = args[0]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("build.json")))
	if not parsed is Dictionary:
		push_error("Missing or invalid build.json")
		quit(2)
		return
	var config: Dictionary = parsed
	if config.mode == "battle_map":
		var timeline: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("navigation.json")))
		if not timeline is Dictionary or not timeline.get("rows") is Array or timeline.rows.is_empty():
			failures.append("Battle map requires Hollowmark rows data")
		else:
			var board: Dictionary = Terrain.parse(timeline)
			for row in board.tiles:
				if row.size() != board.w:
					failures.append("Hollowmark map rows differ in length")
					break
		if config.godot_probes.is_empty():
			failures.append("Battle map requires map-authored surface probes")
	var start := Time.get_ticks_usec()
	var loader := GLTFDocument.new()
	var state := GLTFState.new()
	if loader.append_from_file(folder.path_join("map.glb"), state) != OK:
		push_error("Could not decode GLB")
		quit(2)
		return
	var definitions: Array = state.json.get("materials", [])
	var imported := state.get_materials()
	for index in range(definitions.size()):
		var source_mat: Dictionary = definitions[index]
		var actual := imported[index] as StandardMaterial3D if index < imported.size() else null
		if actual == null:
			failures.append("Unsupported GLB material at index %d" % index)
			continue
		var pbr: Dictionary = source_mat.get("pbrMetallicRoughness", {})
		if pbr.has("baseColorTexture") and actual.albedo_texture == null:
			failures.append("Albedo texture lost on " + actual.resource_name)
		if pbr.has("metallicRoughnessTexture") and actual.roughness_texture == null:
			failures.append("Metallic/roughness texture lost on " + actual.resource_name)
		if source_mat.has("normalTexture") and (actual.normal_texture == null or not actual.normal_enabled):
			failures.append("Normal texture lost on " + actual.resource_name)
		var alpha: String = source_mat.get("alphaMode", "OPAQUE")
		if (alpha != "OPAQUE") != (actual.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			failures.append("Alpha mode mismatch on " + actual.resource_name)
		if source_mat.has("emissiveTexture") and actual.emission_texture == null:
			failures.append("Emission texture lost on " + actual.resource_name)
	var model := loader.generate_scene(state) as Node3D
	root.add_child(model)
	var import_ms := (Time.get_ticks_usec() - start) / 1000.0
	var instances := model.find_children("*", "MeshInstance3D", true, false)
	var mesh_bounds := AABB()
	var triangles: int = 0
	var surfaces: int = 0
	var first := true
	var appearances: Dictionary = {}
	var checked_probes := 0
	var source_textures := 0
	for object in instances:
		var mi := object as MeshInstance3D
		var bb: AABB = mi.global_transform * mi.get_aabb()
		mesh_bounds = bb if first else mesh_bounds.merge(bb)
		first = false
		mi.create_trimesh_collision()
		for index in range(mi.mesh.get_surface_count()):
			surfaces += 1
			var mat := mi.get_active_material(index) as StandardMaterial3D
			if mat == null:
				failures.append("Missing/default material on " + mi.name)
				continue
			var arrays := mi.mesh.surface_get_arrays(index)
			var channels := int(mi.mesh.surface_get_format(index))
			if (channels & Mesh.ARRAY_FORMAT_NORMAL) == 0 or (channels & Mesh.ARRAY_FORMAT_TANGENT) == 0 or (channels & Mesh.ARRAY_FORMAT_TEX_UV) == 0:
				failures.append("Missing vertex normals, tangents or UVs on " + mi.name)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var key := mat.resource_name
			if not appearances.has(key):
				appearances[key] = {
					"albedo": mat.albedo_texture != null,
					"normal": mat.normal_enabled and mat.normal_texture != null,
					"roughness": mat.roughness_texture != null,
					"transparency": mat.transparency,
					"emission": mat.emission_enabled,
				}
				for texture in [mat.albedo_texture, mat.normal_texture, mat.roughness_texture]:
					if texture != null and texture.get_width() > 0:
						source_textures += 1
				if config.mode == "asset_review" and not (appearances[key].albedo and appearances[key].normal and appearances[key].roughness):
					failures.append("Incomplete showcase PBR material " + key)
	var source: Array = config.bounds_xyz_m
	var low := Vector3(source[0][0], source[0][2], -source[1][1])
	var high := Vector3(source[1][0], source[1][2], -source[0][1])
	if first or not mesh_bounds.position.is_equal_approx(low) and mesh_bounds.position.distance_to(low) > 0.05:
		failures.append("World bounds minimum differs from Blender")
	if mesh_bounds.end.distance_to(high) > 0.05:
		failures.append("World bounds maximum differs from Blender")
	await physics_frame
	await physics_frame
	for probe: Dictionary in config.godot_probes:
		var at := Vector3(float(probe.surface[0]), float(probe.surface[1]), float(probe.surface[2]))
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.22, at - Vector3.UP * 0.22)
		var hit := root.world_3d.direct_space_state.intersect_ray(ray)
		if hit.is_empty() or absf(hit.position.y - at.y) > float(probe.height_tolerance):
			failures.append("Surface probe mismatch: " + str(probe.name))
		else:
			checked_probes += 1

	var frame_ms: float = 0.0
	var captured := false
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		var q: Array = config.camera.quaternion
		root.add_child(camera)
		camera.global_position = _blender_vec(config.camera.location)
		camera.basis = Basis(Vector3.RIGHT, -PI / 2) * Basis(Quaternion(q[1], q[2], q[3], q[0]))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = config.camera.ortho_scale
		camera.current = true
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.17, 0.22, 0.27)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.65, 0.74, 0.94)
		world.environment.ambient_light_energy = 0.48
		root.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48, -32, 0)
		sun.light_energy = 1.15
		sun.light_color = Color(1.0, 0.87, 0.67)
		sun.shadow_enabled = true
		root.add_child(sun)
		for i in range(8):
			await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		captured = capture.save_png(folder.path_join("godot-preview.png")) == OK
		var mark := Time.get_ticks_usec()
		for i in range(30):
			await RenderingServer.frame_post_draw
		frame_ms = (Time.get_ticks_usec() - mark) / 30000.0

	var report := {
		"status": "pass" if failures.is_empty() else "fail",
		"project": "Hollowmark" if ProjectSettings.get_setting("application/config/name", "").to_lower().contains("hollowmark") else "Standalone",
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"mesh_objects": instances.size(),
		"surfaces": surfaces,
		"triangles": triangles,
		"materials": appearances,
		"resolved_texture_slots": source_textures,
		"walk_surface_probes": checked_probes,
		"world_dimensions_m": Array([mesh_bounds.size.x, mesh_bounds.size.y, mesh_bounds.size.z]),
		"import_ms": import_ms,
		"captured_frame": captured,
		"frame_sha256": FileAccess.get_sha256(folder.path_join("godot-preview.png")) if captured else null,
		"mean_capture_frame_ms": frame_ms if captured else null,
		"glb_sha256": FileAccess.get_sha256(folder.path_join("map.glb")),
		"failures": failures
	}
	var out := FileAccess.open(folder.path_join("godot-validation.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t") + "\n")
	out.close()
	print("HOLLOWMARK_GODOT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
