extends Node
## One screenshot of the barracks: xvfb-run -a godot --path godot res://tests/ui_shot.tscn -- out=/tmp/x.png [mentor=0]
## mentor=N opens the Mentorship sub-menu for the Nth human and starts a study on the first skill.
func _ready() -> void:
	var args := {"out": "user://ui.png", "mentor": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	add_child(b)
	if args.mentor != "":
		await get_tree().process_frame
		b.mentor_buttons[args.mentor.to_int()].pressed.emit()
		b.mentorship.study_button.pressed.emit()
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
