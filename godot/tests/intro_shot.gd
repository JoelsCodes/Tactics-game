extends Node
## Plays the intro cutscene and saves one frame at each beat:
## xvfb-run -a godot --path godot res://tests/intro_shot.tscn -- out=/some/dir
var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	var s: IntroCutscene = load("res://scenes/intro.tscn").instantiate()
	add_child(s)
	s.beat.connect(func(n): _grab(n))
	s.finished.connect(func(): get_tree().quit())


func _grab(name: String) -> void:
	await get_tree().create_timer(0.6).timeout  # let the step settle on screen
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/intro_%s.png" % [out_dir, name])
