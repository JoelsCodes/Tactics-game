extends Node
## One screenshot of the barracks: xvfb-run -a godot --path godot res://tests/ui_shot.tscn -- out=/tmp/x.png
## section=Formation|Campaign|Records|System opens that Headquarters section; story=1 uses the story party instead of the sample one.
## loadout=N opens the equipment menu of the Nth vessel with Relic Slot 2 selected.
func _ready() -> void:
	var args := {"out": "user://ui.png", "loadout": "", "section": "", "story": "", "skills": ""}
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
	if args.section != "":  # section=Roster|Campaign|Records|System
		await get_tree().process_frame
		b.show_section(args.section)
	if args.loadout != "":
		await get_tree().process_frame
		b.open_loadout(b.roster.co_captains[args.loadout.to_int()])
		b.loadout_menu.slot_list.select(3)
		b.loadout_menu.slot_list.item_selected.emit(3)
	if args.skills != "":  # skills=N opens the Skills menu of the Nth member (Company order)
		await get_tree().process_frame
		b.open_skills(b._members()[args.skills.to_int()])
		await get_tree().process_frame
		if b.skills_menu.list.item_count > 1:
			b.skills_menu.list.select(1)
			b.skills_menu.list.item_selected.emit(1)
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
