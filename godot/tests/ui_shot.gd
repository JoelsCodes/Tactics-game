extends Node
## One screenshot of the barracks: xvfb-run -a godot --path godot res://tests/ui_shot.tscn -- out=/tmp/x.png [mentor=0]
## section=Formation|Campaign|Records|System opens that Headquarters section; story=1 uses the story party instead of the sample one.
## mentor=N opens the Mentorship sub-menu for the Nth human and starts a study on the first skill.
## loadout=N opens the equipment menu of the Nth vessel with Relic Slot 2 selected.
func _ready() -> void:
	var args := {"out": "user://ui.png", "mentor": "", "loadout": "", "section": "", "story": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	SaveSystem.dir = "user://test_saves_shot"  # an empty folder: a new game with the sample party
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	if args.story != "":  # the story's party, with the riverbank open (a real next mission and chapter)
		var g := GameSession.current()
		for id in [&"base", &"keep", &"riverbank"]:  # as the base conversation leaves it
			g.campaign.unlock_area(id)
		for id in ["hallway", "chamber"]:
			g.campaign.mark_cleared(id)
		b.game = g
	else:
		b.roster = SampleParty.make()
	add_child(b)
	if args.section != "":  # section=Formation|Campaign|Records|System
		await get_tree().process_frame
		b.show_section(args.section)
	if args.loadout != "":
		await get_tree().process_frame
		b.vessel_loadout_buttons[args.loadout.to_int()].pressed.emit()
		b.loadout_menu.slot_list.select(3)
		b.loadout_menu.slot_list.item_selected.emit(3)
	if args.mentor != "":
		await get_tree().process_frame
		b.mentor_buttons[args.mentor.to_int()].pressed.emit()
		b.mentorship.study_button.pressed.emit()
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
