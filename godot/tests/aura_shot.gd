extends Node
## The four auras on a real character, for judging them: xvfb-run -a godot --path godot res://tests/aura_shot.tscn -- out=/tmp/a.png style=front|behind|behind_add
func _ready() -> void:
	var args := {"out": "user://aura.png", "style": "behind_add"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	EffectLibrary.aura_style = String(args.style)
	var vp := SubViewport.new()
	vp.size = Vector2i(1200, 380)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.13, 0.12)
	vp.add_child(env)
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(40, 30)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.25, 0.4, 0.22)
	ground.material_override = gmat
	vp.add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.2
	cam.position = Vector3(0, 8.0, 6.2)
	vp.add_child(cam)
	cam.current = true
	cam.look_at(Vector3(0, 0.9, 0.0), Vector3.UP)
	var pitch := absf(rad_to_deg(asin(clampf(-(-cam.global_transform.basis.z).y, -1.0, 1.0))))
	var root := Node3D.new()
	vp.add_child(root)
	await get_tree().process_frame
	var looks := ["fire", "ice", "spark", "holy"]
	for i in looks.size():
		var at := Vector3((float(i) - 1.5) * 2.7, 0.0, 0.0)
		var v := UnitView3D.new()
		root.add_child(v)
		v.setup("king")
		v.position = at
		v.fit(1.0 / maxf(cos(deg_to_rad(pitch)), 0.3))
		EffectLibrary.aura(root, looks[i], at, 2.0)
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(String(args.out))
	get_tree().quit()
