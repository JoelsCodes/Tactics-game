extends Node
## Plays the intro cutscene and saves one frame at each beat:
## xvfb-run -a godot --path godot res://tests/intro_shot.tscn -- out=/some/dir [beats=dialogue,stop] [speed=4] [scene=intro|hallway] [delay=0.6]
## delay: seconds (scene time) after a beat before its frame is saved; short for quick action beats.
## beats: only these beats are saved, and the run quits after the last of them (default: every beat).
## speed: the scene runs this many times faster (Engine.time_scale); the frames look the same.
var out_dir := "user://"
var beats: PackedStringArray = []
var scene := "intro"
var delay := 0.6


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
		elif a.begins_with("beats="):
			beats = a.substr(6).split(",", false)
		elif a.begins_with("delay="):
			delay = a.substr(6).to_float()
		elif a.begins_with("scene="):
			scene = a.substr(6)
		elif a.begins_with("speed="):
			Engine.time_scale = maxf(a.substr(6).to_float(), 1.0)
	var s: Cutscene3D = load("res://scenes/%s.tscn" % scene).instantiate()
	if s is HallwayCutscene:
		s.start_battle = false  # the shots stop where the battle would start
	if s is HallwayReturnCutscene:
		s.start_battle = false
	if s is IntroCutscene:
		s.go_on = false
	add_child(s)
	s.beat.connect(func(n): _grab(n))
	s.finished.connect(func(): get_tree().quit())


func _grab(name: String) -> void:
	if not beats.is_empty() and not beats.has(name):
		return
	await get_tree().create_timer(delay).timeout  # let the step settle on screen
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, scene, name])
	print("saved %s_%s" % [scene, name])
	if not beats.is_empty():
		beats.remove_at(beats.find(name))
		if beats.is_empty():
			get_tree().quit()
