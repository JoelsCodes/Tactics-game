extends Node
## One screenshot of the viewer: xvfb-run -a godot --path godot res://tests/shot.tscn -- out=/tmp/x.png sample=0 zoom=.8 rot=0
func _ready() -> void:
	var args := {"out": "user://shot.png", "sample": "0", "zoom": "", "rot": "0"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	load("res://scripts/viewer.gd").start_sample = args.sample.to_int()
	var v = load("res://scenes/viewer.tscn").instantiate()
	add_child(v)
	if args.zoom != "":
		v.cam.zoom = Vector2.ONE * args.zoom.to_float()
	if args.rot != "0":
		v.rotate_view(args.rot.to_int())
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
