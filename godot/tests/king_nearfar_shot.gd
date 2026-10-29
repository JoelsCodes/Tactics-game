extends Node
## The King in battle on his tile nearest to the camera and farthest from it:
## xvfb-run -a godot --path godot res://tests/king_nearfar_shot.tscn -- out=/some/dir [speed=4]
func _ready() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("speed="):
			Engine.time_scale = maxf(a.substr(6).to_float(), 1.0)
	SaveSystem.dir = "user://test_saves_nearfar"
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	add_child(s)
	await get_tree().create_timer(0.3).timeout
	while s.battle.current != null and s.battle.current.team != 0:
		await get_tree().process_frame
	var king := s.battle.deployment.king
	while s.battle.current != king:
		s.end_turn()
		await get_tree().create_timer(0.05).timeout
	var reach := s.highlights.shown(TileHighlights.Kind.MOVE)
	var depth := func(c: Vector2i) -> float: return s.board.cam.unproject_position(s.board.top_point(c.x, c.y)).y
	var near: Vector2i = reach[0]
	var far: Vector2i = reach[0]
	for c in reach:
		if depth.call(c) > depth.call(near): near = c
		if depth.call(c) < depth.call(far): far = c
	for pair in [["far", far], ["near", near]]:
		if pair[0] == "near":
			near = reach[0]
			for c in reach:
				if depth.call(c) > depth.call(near): near = c
			pair[1] = near
		s.tap_cell(pair[1])
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/battle_%s.png" % [out, pair[0]])
		print(pair[0], " ", pair[1])
		for i in 200:
			if s.battle.current == king and s.highlights.shown(TileHighlights.Kind.MOVE).size() > 0 and i > 5:
				break
			if s.battle.current != null and s.battle.current.team == 0:
				s.end_turn()
			await get_tree().create_timer(0.2).timeout
		reach = s.highlights.shown(TileHighlights.Kind.MOVE)
		print("king turn, reach ", reach.size(), " cell ", king.cell)
	get_tree().quit()
