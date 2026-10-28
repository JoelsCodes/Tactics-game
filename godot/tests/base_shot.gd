extends Node
## One screenshot of the base: xvfb-run -a godot --path godot res://tests/base_shot.tscn -- out=/tmp/base.png
func _ready() -> void:
	var out := "user://base.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map="):
			load("res://scripts/base.gd").map_key = a.substr(4)
	var b = load("res://scenes/base.tscn").instantiate()
	add_child(b)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			b.world.cam.zoom = Vector2.ONE * a.substr(5).to_float()
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
