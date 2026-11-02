extends Node
## A frame of the world map or the base: xvfb-run -a godot --path godot res://tests/screen_shot.tscn -- out=/some/dir scene=world|base [at=x,y]
## The game is the story's party with the places the story has opened so far (the keep, the base, the riverbank).
## at: where Alaric stands in the base (tile units).
func _ready() -> void:
	var out := "user://"
	var which := "world"
	var at := Vector2.ZERO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("scene="):
			which = a.substr(6)
		elif a.begins_with("at="):
			var xy := a.substr(3).split(",")
			at = Vector2(xy[0].to_float(), xy[1].to_float())
	SaveSystem.dir = "user://test_saves_screen_shot"
	var g := FirstBattle.chamber_game(FirstBattle.game())
	g.campaign.unlock_area(&"keep")
	g.campaign.record_first_play("hallway", g.roster)
	WorldData.clear_map(g.campaign, "hallway")
	g.campaign.record_first_play("chamber", g.roster)
	WorldData.clear_map(g.campaign, "chamber")
	g.campaign.unlock_area(&"riverbank")
	GameSession.game = g
	var s: Node = load("res://scenes/%s.tscn" % ("world_map" if which == "world" else "base_area")).instantiate()
	if s is BaseArea:
		s.go_on = false
	add_child(s)
	await get_tree().create_timer(1.8).timeout
	if s is BaseArea and at != Vector2.ZERO:
		s.pos = at
		await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, which])
	print("saved ", which)
	get_tree().quit()
