extends Node
## Screenshot of the bare 3D board with a few units (needs a display):
## xvfb-run -a godot --path godot res://tests/diorama_shot.tscn -- out=/tmp/d.png [map=demo_battlefield] [pitch=-50] [fov=28] [yaw=45] [units=0]
func _ready() -> void:
	var args := {"out": "user://diorama.png", "map": "demo_battlefield", "pitch": "-50", "fov": "28", "yaw": "45"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var d := Board3D.new()
	add_child(d)
	d.setup(Terrain.load_map("res://samples/%s.json" % args.map), args.pitch.to_float(), args.fov.to_float(), args.yaw.to_float())
	if args.get("ssao", "1") == "0":
		d.env.ssao_enabled = false
	if args.get("shadow", "1") == "0":
		d.sun.shadow_enabled = false
	if args.get("units", "1") == "1":
		d.add_unit("king", 3, 4)
		d.add_unit("mira", 4, 5, true)
		d.add_unit("squire", 9, 6, false)
		d.add_unit("wraith", 10, 3, false)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
