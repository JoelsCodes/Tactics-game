extends Node
## One Altar Shard frame at six sizes on a flat colour, for judging how the art scales: xvfb-run -a godot --path godot res://tests/shard_sizes_shot.tscn -- out=/tmp/s.png mips=1|0
func _ready() -> void:
	var args := {"out": "user://sizes.png", "mips": "1"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	AltarShardView.use_mipmaps = args.mips == "1"
	var vp := SubViewport.new()
	vp.size = Vector2i(1500, 420)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2  # 420 px = 4.2 units: 100 px per unit
	cam.position = Vector3(0, 2.0, 10)
	vp.add_child(cam)
	cam.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.4, 0.2)
	vp.add_child(env)
	var x := -6.4
	for h in [0.5, 0.9, 1.4, 1.87, 2.6, 3.6]:  # on-screen heights in world units
		var v := AltarShardView.new()
		v.position = Vector3(x, 0.1, 0)
		v.name = "S"
		vp.add_child(v)
		await get_tree().process_frame
		v.sprite.stop()
		v.sprite.frame = 0
		v.sprite.pixel_size = h / 375.0
		x += h * 0.9 + 0.7
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(args.out)
	get_tree().quit()
