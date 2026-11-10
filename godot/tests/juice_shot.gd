extends Node
## Frames of the battle's new moments, for review:
##   xvfb-run -a godot --path godot res://tests/juice_shot.tscn -- out=/dir [step=surge|hit|victory|defeat|intro] [setup=riverford1|chamber]
## surge: a full Momentum gauge spent, the unit glowing, the forecast showing the sure critical.
## hit: frames of a surged killing blow (callouts, slow motion, the XP rising). victory / defeat: frames of the results show.
## intro: the BATTLE START banner.
var s: BattleStage
var out := "user://"


func _ready() -> void:
	var args := {"out": "user://juice", "step": "victory", "setup": "riverford1"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	out = args.out
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.dir = "user://test_saves_juice_shot"
	BattleStage.show_intro = args.step == "intro"
	var g := FirstBattle.chamber_game(FirstBattle.game())
	if args.setup == "chamber":
		BattleStage.pending_setup = FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, ChamberCutscene.SQUIRES_TO)
	else:
		BattleStage.pending_setup = Riverford.setup(int(String(args.setup).substr(9)))
	BattleStage.pending_game = g
	s = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	add_child(s)
	s.battle.miss_chance = 0.0
	if args.step == "intro":
		await wait(0.5)
		await shot("intro")
		get_tree().quit()
		return
	await wait(0.4)
	var king := s.battle.deployment.king
	while s.battle.current != king:
		s.end_turn()
		await wait(0.05)
	await wait(3.0)  # the opening line leaves
	match args.step:
		"surge":
			bring(s.battle.enemies[0], king)
			s.momentum.add(100.0)
			await wait(1.3)
			s.toggle_surge()
			await wait(0.5)
			s._on_action_chosen(BattleAction.attack())
			s.tap_cell(s.battle.enemies[0].cell)
			await wait(0.6)
			await shot("surge")
		"hit":
			var e: BattleUnit = s.battle.enemies[0]
			bring(e, king)
			e.hp = 3
			s.momentum.add(100.0)
			await wait(1.3)
			s.toggle_surge()
			await wait(1.0)
			s._on_action_chosen(BattleAction.attack())
			s.tap_cell(e.cell)
			await wait(0.2)
			s.tap_cell(e.cell)
			for i in 8:
				await wait(0.12)
				await shot("hit_%d" % i)
		"victory", "defeat":
			if args.step == "defeat":
				for e in s.battle.enemies:
					e.hp = e.max_hp()
				for u in s.battle.deployment.field_units():
					u.hp = 0
				s.battle._check_outcome()
				s._check_end()
			else:
				s.momentum.best_chain = 4
				for i in s.battle.enemies.size():
					var e: BattleUnit = s.battle.enemies[i]
					bring(e, king)
					e.hp = 1
					s.battle.acted = false
					s.mode = BattleStage.Mode.IDLE
					var rr: ActionResult = await s._resolve(king, BattleAction.attack(), e.cell)
					print("attack ", i, " ok=", rr.ok, " err=", rr.error, " hp=", e.hp, " outcome=", s.battle.outcome)
					await wait(0.5)
				king.data.stats.exp = 60
				s._check_end()
			for i in 9:
				await wait(0.9)
				await shot("%s_%d" % [args.step, i])
	get_tree().quit()


## Puts `e` on the tile the King faces.
func bring(e: BattleUnit, king: BattleUnit) -> void:
	var c := king.cell + king.facing
	var o = s.grid.occupant(c)
	if o != null and o != e:
		s.grid.remove(o)
	s.grid.move_occupant(e, c)
	e.cell = c
	s._place(e)


func wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved %s/%s.png" % [out, name])
