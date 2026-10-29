extends Node
## Plays the intro cutscene and saves one frame at each beat:
## xvfb-run -a godot --path godot res://tests/intro_shot.tscn -- out=/some/dir [beats=dialogue,stop] [speed=4]
## beats: only these beats are saved, and the run quits after the last of them (default: every beat).
## speed: the scene runs this many times faster (Engine.time_scale); the frames look the same.
var out_dir := "user://"
var beats: PackedStringArray = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
		elif a.begins_with("beats="):
			beats = a.substr(6).split(",", false)
		elif a.begins_with("speed="):
			Engine.time_scale = maxf(a.substr(6).to_float(), 1.0)
	var s: IntroCutscene = load("res://scenes/intro.tscn").instantiate()
	add_child(s)
	s.beat.connect(func(n): _grab(n))
	s.finished.connect(func(): get_tree().quit())


func _grab(name: String) -> void:
	if not beats.is_empty() and not beats.has(name):
		return
	await get_tree().create_timer(0.6).timeout  # let the step settle on screen
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/intro_%s.png" % [out_dir, name])
	print("saved intro_", name)
	if not beats.is_empty():
		beats.remove_at(beats.find(name))
		if beats.is_empty():
			get_tree().quit()
