extends Node
## Headless: the altar scene plays to its end (Alaric slumps by the altar, the flash, Bram and Lyra, the owner's lines word
## for word, the squires walk in); the chamber battle starts as it says (Rook style, Bram and Lyra beside Alaric, no summoning,
## no stones, no tutorial); a win leads to the base conversation, which plays to its end.
## godot --headless --path godot res://tests/chamber_check.tscn
var fails := 0
var count := 0
var done := false
var beats: Array[String] = []
var said := {}  ## beat -> [speaker, line] shown a moment after it


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	Engine.time_scale = 4.0
	var s: ChamberCutscene = load("res://scenes/chamber.tscn").instantiate()
	s.start_battle = false
	add_child(s)
	s.finished.connect(func(): done = true)
	s.beat.connect(func(b):
		beats.append(b)
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(s):
			said[b] = [s.speaker.text, s.line.text])
	ok(s.board.map.w == 12 and s.board.map.d == 9, "the chamber is a 12x9 room")
	var waited := 0.0
	while not done and waited < 120.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	Engine.time_scale = 1.0
	ok(done, "the altar scene reaches its end (%.1fs)" % waited)
	ok(beats == ["start", "sit", "altar", "companions", "lyra", "bram", "alaric", "ranks", "squires"], "its steps in order (%s)" % [beats])
	ok(s.king_cell == ChamberCutscene.WALL_SPOT and s.king.position.is_equal_approx(s.board.top_point(10, 5)), "Alaric is by the far wall, next to the altar")
	ok(said.get("lyra", []) == ["LYRA", "You're calling us with a dying pulse. And you look terrified of what you just did."], "Lyra's first line, word for word (%s)" % [said.get("lyra")])
	ok(said.get("bram", []) == ["BRAM", "Kid's running on empty. But there's steel at the door. Do we bleed with him, or go back to the dark?"], "Bram's line, word for word (%s)" % [said.get("bram")])
	ok(said.get("alaric", []) == ["ALARIC", "We don't bleed. The King took my home. Now we take everything else."], "Alaric's line, word for word (%s)" % [said.get("alaric")])
	ok(said.get("ranks", []) == ["BRAM", ChamberCutscene.LINE_BRAM_WARNING], "the last line said in the altar scene is Bram's warning (%s)" % [said.get("ranks")])
	ok(s.bram.char_name == "warden" and s.lyra.char_name == "mira", "Bram (the warden sheet) and Lyra (the mira sheet) stepped out of the altar")
	ok(s.bram.get_alpha() < 0.01 and s.lyra.get_alpha() < 0.01, "then they dissolved into its light")
	ok(not s.king._held, "Alaric stood for his line")
	ok(s.squires.size() == 2 and s.squire_cells == [Vector2i(1, 3), Vector2i(1, 5)], "two squires walked in at the entrance (%s)" % [s.squire_cells])
	var scene_cam := s.board.cam.global_transform
	# the chamber battle
	var g := FirstBattle.chamber_game(FirstBattle.game())
	ok(FirstBattle.chamber_game(g) == g and g.roster.co_captains.size() == 2, "Bram and Lyra are added once")
	BattleStage.pending_game = g
	BattleStage.pending_setup = FirstBattle.chamber_setup(s.king_cell, s.squire_cells)
	s.queue_free()
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.0
	add_child(b)
	await get_tree().process_frame
	var dm := b.battle.deployment
	var king := dm.king
	ok(b.map_path == FirstBattle.CHAMBER, "the battle is in the chamber")
	ok(b.board.cam.global_transform.is_equal_approx(scene_cam), "the battle's camera is exactly the scene's (no shift)")
	ok(king.data.display_name == "Alaric" and king.data.level == 1 and king.cell == Vector2i(10, 5), "Alaric, level 1, where he stood")
	ok(king.data.loadout.weapon_style.geometry == TacticalMath.Geometry.ROOK, "with the Rook weapon style")
	ok(b.battle.enemies.size() == 2 and b.battle.enemies.map(func(e): return e.cell) == [Vector2i(1, 3), Vector2i(1, 5)], "two squires, where they walked in")
	ok(b.battle.enemies.all(func(e): return b.battle.actions(e).size() == 1), "the squires only attack")
	var bram: CoCaptainData = g.roster.co_captains.filter(func(v): return v.display_name == "Bram")[0]
	var lyra: CoCaptainData = g.roster.co_captains.filter(func(v): return v.display_name == "Lyra")[0]
	ok(UnitLook.sheet_for(bram) == "warden" and UnitLook.sheet_for(lyra) == "mira", "Bram and Lyra use their own sheets")
	ok(dm.unit_of(bram) != null and dm.unit_of(lyra) != null and dm.field_units().size() == 3, "Bram and Lyra stand beside Alaric from the start (no summoning)")
	ok(dm.unit_of(bram).cell == FirstBattle.BRAM_CELL, "Bram stands where he stood in the altar scene")
	ok(b.hud.objective_label.text.contains("Defeat both Ashen Squires"), "the objective is there")
	ok(not "tutorial" in b and not b.hud.has_method("show_tip"), "there is no tutorial: nobody learns summoning")
	var guard := 0
	while (b.battle.current == null or b.battle.current != king) and guard < 20:
		await get_tree().process_frame
		guard += 1
	ok(b.battle.current == king or b.battle.current != null, "the battle runs")
	# a win leads to the base conversation
	for e in b.battle.enemies:
		e.hp = 0
	b.battle._check_outcome()
	b._check_end()
	ok(b.mode == BattleStage.Mode.OVER or b.battle.outcome == BattleController.Outcome.WON, "the battle ends in a win")
	ok(b.setup.on_win == FirstBattle.AFTER_CHAMBER and FirstBattle.AFTER_CHAMBER == "res://scenes/base.tscn", "a win leads to the base conversation")
	b.queue_free()
	await get_tree().process_frame
	# the base conversation
	Engine.time_scale = 4.0
	var base: BaseCutscene = load("res://scenes/base.tscn").instantiate()
	base.go_on = false
	add_child(base)
	var speakers: Array[String] = []
	var texts: Array[String] = []
	base.beat.connect(func(n):
		beats.append("base_" + n)
		if n != "start" and n != "end":
			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(base):
				speakers.append(base.speaker.text)
				texts.append(base.line.text))
	done = false
	base.finished.connect(func(): done = true)
	waited = 0.0
	while not done and waited < 120.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	Engine.time_scale = 1.0
	ok(done, "the base conversation plays to its end (%.1fs)" % waited)
	ok(speakers.size() == BaseCutscene.LINES.size() and speakers == BaseCutscene.LINES.map(func(l): return l[0]), "everyone speaks in turn (%s)" % [speakers])
	ok(texts == BaseCutscene.LINES.map(func(l): return l[2]), "each line is shown in full")
	ok(base.fade.modulate.a > 0.99, "it fades out toward the barracks")
	ok(BaseCutscene.NEXT_SCENE == "res://scenes/world_map.tscn", "the world map follows")
	ok(GameSession.game != null and GameSession.game.campaign.is_area_unlocked(&"riverbank"), "the story opened the riverbank")
	print("chamber checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
