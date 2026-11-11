extends Node
## Every look of the shared effect library with every piece, on a flat dark ground: xvfb-run -a godot --path godot res://tests/effects_sheet.tscn -- out=/tmp/e.png
## Writes <out>_a.png (a quarter of a second in: the flashes and the flights) and <out>_b.png (a little later: rings, auras and beams).
const PIECES := ["projectile", "burst", "ring", "aura", "beam"]


func _ready() -> void:
	var args := {"out": "user://effects.png"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var names: Array = EffectLibrary.looks().keys()
	var vp := SubViewport.new()
	vp.size = Vector2i(1500, 860)
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
	gmat.albedo_color = Color(0.2, 0.3, 0.2)
	ground.material_override = gmat
	vp.add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.5
	cam.position = Vector3(0, 14.0, 9.0)
	vp.add_child(cam)
	cam.current = true
	cam.look_at(Vector3(0, 0.4, 0.0), Vector3.UP)
	var root := Node3D.new()
	vp.add_child(root)
	await get_tree().process_frame
	var col_w := 3.2
	var row_h := 2.9
	for r in names.size():
		for c in PIECES.size():
			var at := Vector3((float(c) - 2.0) * col_w, 0.35, (float(r) - 1.5) * row_h)
			var look: String = names[r]
			match PIECES[c]:
				"projectile":
					EffectLibrary.projectile(root, look, at + Vector3(-1.2, 0.5, 0), at + Vector3(1.2, 0.5, 0))
				"burst":
					EffectLibrary.burst(root, look, at + Vector3(0, 0.5, 0))
				"ring":
					EffectLibrary.ring(root, look, at, 1.0)
				"aura":
					EffectLibrary.aura(root, look, at, 2.0)
				"beam":
					EffectLibrary.beam(root, look, at + Vector3(-1.2, 0.5, 0), at + Vector3(1.2, 0.5, 0), 0.8)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(String(args.out).replace(".png", "_a.png"))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(String(args.out).replace(".png", "_b.png"))
	get_tree().quit()
