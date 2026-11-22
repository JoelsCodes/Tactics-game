extends Node
## The real Formation pop-up on a sample company, saved as out=<file>.png.
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/formation_popup_shot.tscn -- out=/tmp/formation.png
func _ready() -> void:
	var out := "/tmp/formation.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	SaveSystem.dir = "user://test_saves_formation_shot"
	var g := Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())))
	var pop := FormationPopup.create(g, "The Riverbank  ·  Battle 2")
	add_child(pop)
	for i in 8:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit(0)
