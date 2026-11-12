extends Node
## A map on the battle board with the battle camera, no units: xvfb-run -a godot --path godot res://tests/map_shot.tscn -- map=res://samples/features_demo.json out=/tmp/m.png
func _ready() -> void:
	var args := {"map": "res://samples/features_demo.json", "out": "user://map.png"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var b := Board3D.new()
	add_child(b)
	b.setup(Terrain.load_map(String(args.map)))
	await get_tree().process_frame
	BattleStage.lock_camera(b, get_viewport().get_visible_rect().size)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(args.out))
	get_tree().quit()
