extends Node
## Screenshots of the battle screen: xvfb-run -a godot --path godot res://tests/battle_shot.tscn -- out=/tmp/b.png [step=move|aim|confirm|abilities|summonmenu|summon|result] [grade=sepia|natural|golden] [backdrop=sky|radial] [rays=0|1] [wood=1]
func _ready() -> void:
	var args := {"out": "user://battle.png", "step": "", "grade": "", "backdrop": "", "rays": "", "wood": "", "items": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	SaveSystem.dir = "user://test_saves_battle_shot"
	HudStyle.wood_panels = args.wood == "1"
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1.2 if args.step == "enemy" else 0.0
	add_child(s)
	await get_tree().create_timer(0.3).timeout
	while s.battle.current != null and s.battle.current.team != 0:
		await get_tree().process_frame
	if args.grade != "":
		s.board.set_grade(args.grade)
	if args.backdrop != "":
		s.board.set_backdrop(args.backdrop)
	if args.rays != "":
		s.board.set_god_rays(args.rays == "1")
	if args.items == "1":  # preview only: show the ITEMS slot as if it were usable
		s.hud.palette.items_button.disabled = false
	var king := s.battle.deployment.king
	match args.step:
		"abilities":
			s.hud.palette.open_list("abilities")
		"summonmenu":
			while s.battle.current != king:
				s.end_turn()
				await get_tree().create_timer(0.05).timeout
			s.hud.palette.open_list("summon")
		"aim", "confirm":
			s.battle.current.data.stats  # whoever acts first
			s._on_action_chosen(BattleAction.attack())
			var reach := s.highlights.shown(TileHighlights.Kind.REACH)
			if args.step == "confirm" and not reach.is_empty():
				s.tap_cell(reach[0])
		"summon":
			while s.battle.current != king:
				s.end_turn()
				await get_tree().create_timer(0.05).timeout
			s._on_summon_chosen(s.game.roster.vessels()[0])
		"enemy":  # end the player's turns until an enemy is about to strike, and catch that moment
			for i in 6:
				if s.battle.current and s.battle.current.team == 0:
					s.end_turn()
				await get_tree().create_timer(0.2).timeout
				if s.highlights.shown(TileHighlights.Kind.AIM).size() > 0:
					break
			while s.highlights.shown(TileHighlights.Kind.AIM).is_empty():
				await get_tree().process_frame
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args.out)
			get_tree().quit()
			return
		"result":
			for e in s.battle.enemies:
				e.hp = 0
			s.battle._check_outcome()
			s._check_end()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
