extends Node
## The hallway scene's slash: saves frames just after the blow lands (white flash, knock-back), with time
## slowed to a crawl so a slow software renderer can draw them. Each frame is named with the scene time since the hit.
## xvfb-run -a godot --path godot res://tests/hit_shot.tscn -- out=/some/dir
var out_dir := "user://"
var t := 0.0
var running := false
var shots: Array[int] = [0, 3, 7, 14, 28]
var frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	var s: HallwayCutscene = load("res://scenes/hallway.tscn").instantiate()
	s.start_battle = false
	add_child(s)
	s.beat.connect(func(n):
		if n == "slash":  # the blow has just landed
			Engine.time_scale = 0.04
			running = true)


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	await RenderingServer.frame_post_draw
	if frame in shots:
		var path := "%s/hit_%02d_%03dms.png" % [out_dir, frame, int(t * 1000.0)]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	frame += 1
	if frame > shots.max():
		get_tree().quit()
