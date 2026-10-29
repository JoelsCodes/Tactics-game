extends Node
## Screenshot of the 3D diorama prototype (needs Forward+ and a display):
## xvfb-run -a godot --path godot --rendering-method forward_plus --rendering-driver vulkan res://tests/diorama_shot.tscn -- out=/tmp/d.png [map=demo_battlefield] [pitch=-50] [fov=28] [yaw=45]
func _ready() -> void:
	var args := {"out": "user://diorama.png", "map": "demo_battlefield", "pitch": "-50", "fov": "28", "yaw": "45"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	print("start ", Time.get_ticks_msec())
	var d := Diorama3D.new()
	add_child(d)
	d.setup(Terrain.load_map("res://samples/%s.json" % args.map), args.pitch.to_float(), args.fov.to_float(), args.yaw.to_float())
	if args.get("ssao", "1") == "0":
		d.env.ssao_enabled = false
	if args.get("shadow", "1") == "0":
		d.sun.shadow_enabled = false
	d.add_unit("hero", 3, 4)
	d.add_unit("knight", 4, 5, true)
	d.add_unit("brute", 9, 6, false)
	d.add_unit("dino", 10, 3, false)
	var f := d.units[0].position
	var vp := get_viewport().get_visible_rect().size
	print("view ", vp, " feet ", d.cam.unproject_position(f), " +1.5 ", d.cam.unproject_position(f + Vector3(0, 1.5, 0)), " +1x ", d.cam.unproject_position(f + Vector3(1, 0, 0)))
	print("frame size ", d.units[0].sprite_frames.get_frame_texture("idle_f", 0).get_size(), " pixel_size ", d.units[0].pixel_size)
	await get_tree().create_timer(1.5).timeout
	print("waited ", Time.get_ticks_msec())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
