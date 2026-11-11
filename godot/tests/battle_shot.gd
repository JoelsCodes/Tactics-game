extends Node
## Screenshots of the battle screen: xvfb-run -a godot --path godot res://tests/battle_shot.tscn -- out=/tmp/b.png [step=move|aim|confirm|forecast|forecast_heal|abilities|summonmenu|summon|result] [grade=sepia|natural|golden] [backdrop=sky|radial] [rays=0|1] [wood=1] [setup=first|chamber|riverford1..riverford5|crypt|wide]
func _ready() -> void:
	var args := {"out": "user://battle.png", "step": "", "grade": "", "backdrop": "", "rays": "", "wood": "", "items": "", "setup": "", "intro": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	SaveSystem.dir = "user://test_saves_battle_shot"
	HudStyle.wood_panels = args.wood == "1"
	if args.setup == "first":  # the first battle, as the hallway scene leaves it
		BattleStage.pending_game = FirstBattle.game()
		BattleStage.pending_setup = FirstBattle.setup(HallwayCutscene.HALFWAY, HallwayCutscene.ENTRANCE)
	if args.setup == "chamber":  # the chamber battle with the summon tutorial, as the altar scene leaves it
		BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
		BattleStage.pending_setup = FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, ChamberCutscene.SQUIRES_TO)
	if args.setup.begins_with("riverford"):  # a Riverford battle with the party as the story leaves it (Merc joins from map 5)
		var rg := FirstBattle.chamber_game(FirstBattle.game())
		if int(args.setup.substr(9)) >= 5:
			Riverford.add_merc(rg)
		BattleStage.pending_game = rg
		BattleStage.pending_setup = Riverford.setup(int(args.setup.substr(9)))
	if args.setup.begins_with("crucible"):  # a chapter three battle with the party as the story leaves it
		BattleStage.pending_game = Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())))
		BattleStage.pending_setup = Crucible.setup(int(args.setup.substr(8)))
	if args.setup == "crypt":  # the crypt hall (samples/crypt_hall.json, not in a chapter yet) with chapter eight's enemy kinds
		BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
		var cs := BattleSetup.new()
		var cpath := "res://samples/crypt_hall.json"
		var csp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cpath))["spawns"]
		cs.map_path = cpath
		cs.king_cell = Riverford.cell(csp["king"])
		cs.captain_cell = Riverford.cell(csp["captain"])
		for c in csp["stones"]:
			cs.relics.append([SummonStone.make(null, 0.3, 0.1, 0.0), Riverford.cell(c)])
		var ci := 0
		for e in csp["enemies"]:
			ci += 1
			cs.enemies.append([Crown.enemy(String(e["kind"]), 3, ci), Riverford.cell(e["at"])])
		cs.objective = "Defeat all enemies"
		BattleStage.pending_setup = cs
	if args.setup.begins_with("crown"):  # chapter eight with the whole company (Seraphine recruited)
		BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
		BattleStage.pending_setup = Crown.setup(int(args.setup.substr(5)))
	if args.setup.begins_with("arc"):  # the final arc with the whole company (Cassian recruited): setup=arc15_5
		BattleStage.pending_game = FinalArc.recruit_cassian(Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))))
		BattleStage.pending_setup = FinalArc.setup(int(args.setup.substr(3, 2)), int(args.setup.substr(6, 1)))
	if args.setup.begins_with("falcon"):  # chapter eleven with the whole company
		BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
		BattleStage.pending_setup = Falcon.setup(int(args.setup.substr(6)))
	if args.setup.begins_with("ashes"):  # chapter ten with the whole company
		BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
		BattleStage.pending_setup = Ashes.setup(int(args.setup.substr(5)))
	if args.setup.begins_with("palace"):  # chapter nine with the whole company
		BattleStage.pending_game = Vespera.recruit(Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)))
		BattleStage.pending_setup = Finale.setup(int(args.setup.substr(6)))
	if args.setup.begins_with("expanse") or args.setup.begins_with("vespera"):  # chapters six and seven with the party as the story leaves it
		var g67: SaveGame = Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))
		if args.setup.begins_with("vespera"):
			Vespera.recruit(g67)
			BattleStage.pending_setup = Vespera.setup(int(args.setup.substr(7)))
		else:
			BattleStage.pending_setup = Expanse.setup(int(args.setup.substr(7)))
		BattleStage.pending_game = g67
	if args.setup.begins_with("bellwether"):  # a chapter five battle with the party as the story leaves it (Gideon and Kaelen recruited)
		BattleStage.pending_game = Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))
		BattleStage.pending_setup = Bellwether.setup(int(args.setup.substr(10)))
	if args.setup.begins_with("mountain"):  # a chapter four battle with the party as the story leaves it
		BattleStage.pending_game = Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)
		BattleStage.pending_setup = Mountain.setup(int(args.setup.substr(8)))
	if args.setup == "wide":  # the Ford padded to 16 x 32 (grass and trees at both ends): the camera scrolls along it (step=scrollleft|scrollright)
		var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://samples/riverford_1.json"))
		var rim := []
		for i in 16:
			rim.append("g0" if i % 5 != 2 else "t0")
		var padded := []
		for i in 8:
			padded.append(" ".join(PackedStringArray(rim)))
		padded.append_array(src.rows)
		for i in 8:
			padded.append(" ".join(PackedStringArray(rim)))
		src.rows = padded
		src.erase("spawns")
		var wf := FileAccess.open("user://wide_ford.json", FileAccess.WRITE)
		wf.store_string(JSON.stringify(src))
		wf.close()
		var ws := Riverford.setup(1)
		ws.map_path = "user://wide_ford.json"
		ws.king_cell += Vector2i(0, 8)
		ws.captain_cell += Vector2i(0, 8)
		for r in ws.relics:
			r[1] += Vector2i(0, 8)
		for e in ws.enemies:
			e[1] += Vector2i(0, 8)
		BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
		BattleStage.pending_setup = ws
	BattleStage.show_intro = args.get("intro", "") == "1"  # the BATTLE START banner would cover the first frames
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
		"walkseq":  # the King walks to his farthest tile; a strip of frames is saved as out_<n>.png
			var reach := s.highlights.shown(TileHighlights.Kind.MOVE)
			var far: Vector2i = reach[0]
			for c in reach:
				if (c - king.cell).length() > (far - king.cell).length():
					far = c
			s.tap_cell(far)
			for i in 10:
				await get_tree().create_timer(0.11).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(args.out.replace(".png", "_%d.png" % i))
			get_tree().quit()
			return
		"face":  # the King has walked: the four tiles beside him are offered for facing (the faced one marked)
			while s.battle.current != king:
				s.end_turn()
				await get_tree().create_timer(0.05).timeout
			var walk_to := king.cell + Vector2i(0, 2)
			s.tap_cell(walk_to)
			await get_tree().create_timer(1.6).timeout
		"turnaim":  # Attack selected, then turned a quarter with E: the reach follows the new direction (compare with step=aim)
			s._on_action_chosen(BattleAction.attack())
			s.turn_current(1)
			await get_tree().create_timer(0.8).timeout
		"abilities":
			s.hud.palette.open_list("abilities")
		"scrollleft", "scrollright":  # the camera at one end of a wide map
			s.focus_cell(Vector2i(8, 0 if args.step == "scrollleft" else 99))
			await get_tree().create_timer(2.2).timeout
		"sword", "sword_rise":  # the first enemy goes down and drops its sword; sword_rise: the King takes it a moment ago
			var e: BattleUnit = s.battle.enemies[0]
			e.hp = 0
			s.views[e].visible = false
			s.battle._drop_sword(e)
			await get_tree().create_timer(0.8).timeout
			if args.step == "sword_rise":
				s.battle._collect_swords(king, [e.cell] as Array[Vector2i])
				await get_tree().create_timer(0.22).timeout
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
		"shard_seq":  # a confirmed summon, caught at several moments: the stone charges, bursts as the vessel appears, and is spent (out=..._<n>.png)
			while s.battle.current != king:
				s.end_turn()
				await get_tree().create_timer(0.05).timeout
			var vd: VesselData = s.game.roster.vessels()[0]
			var spot = s.battle.deployment.props.keys().filter(func(c): return s.battle.deployment.can_summon(vd, c))[0]
			s.focus_cell(spot)
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args.out.replace(".png", "_0.png"))
			s.summoning = vd
			s._summon_at(spot)
			var t0 := 0.0
			var n := 1
			for dt in [0.3, 0.3, 0.3, 0.3, 0.5]:
				await get_tree().create_timer(dt).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(args.out.replace(".png", "_%d.png" % n))
				n += 1
			get_tree().quit()
			return
		"stoneinfo":  # the summon stone's window, as it opens when a stone is pointed at in summon mode
			while s.battle.current != king:
				s.end_turn()
				await get_tree().create_timer(0.05).timeout
			var svd: VesselData = s.game.roster.vessels()[0]
			s._on_summon_chosen(svd)
			var spot2 = s.highlights.shown(TileHighlights.Kind.SUMMON)[0]
			s.hud.show_stone(s.battle.deployment.prop_at(spot2).relic, svd, s.game)
			await get_tree().create_timer(0.5).timeout
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
		"forecast", "forecast_heal":  # a tile aimed with the attack (or a skill): the damage prediction slides out off the HUD's left edge
			var skill := BattleAction.attack()
			if args.step == "forecast_heal":
				skill = BattleAction.use(SkillLibrary.healing()[1])
			s._on_action_chosen(skill)
			var reach2 := s.highlights.shown(TileHighlights.Kind.REACH)
			var tile: Vector2i = reach2[0]
			var foe: BattleUnit = s.battle.enemies[0]
			if args.step == "forecast_heal":  # the Co-Captain, hurt, stands on the aimed tile
				var mate: BattleUnit = s.battle.deployment.co_captain
				s.grid.move_occupant(mate, tile)
				mate.cell = tile
				mate.hp = mate.max_hp() / 2
			else:
				s.grid.move_occupant(foe, tile)
				foe.cell = tile
				foe.hp = foe.max_hp() * 3 / 4
			s.tap_cell(tile)
			await get_tree().create_timer(0.8).timeout
		"result":
			for e in s.battle.enemies:
				e.hp = 0
			s.battle._check_outcome()
			s._check_end()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()
