extends Node
## The Last Benediction battle with no unit selected (the invisible-grid standard's unselected screenshot): the tile overlays are cleared, so the floor
## is all that shows. xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/last_benediction_unselected_shot.tscn -- out=/tmp/x.png
func _ready() -> void:
	var out := "/tmp/last_benediction_unselected.png"
	var turn := 0
	var nohud := false
	var keep := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("turn="):
			turn = int(a.substr(5))
		elif a == "nohud":
			nohud = true  # the board alone: a backdrop for a HUD mockup
		elif a == "keep":
			keep = true  # keep the selected unit's move overlay
	SaveSystem.dir = "user://test_saves_last_benediction_shot"
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for("pg_4", 1, true)
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	var waited := 0.0
	while waited < 30.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(1.0).timeout
	if turn != 0:
		b.turn_view(turn)   # quarter-turns of the view (Z / C in battle)
		await get_tree().create_timer(1.0).timeout
	if not keep:
		b.highlights.clear_all()   # nothing selected: no move range, no targets
	if nohud:
		b.hud.root.visible = false
		var pos := {}
		for bu in b.views:
			var v: UnitView3D = b.views[bu]
			var head := b.board.cam.unproject_position(b.board.to_global(v.position + Vector3(0, 1.9, 0)))
			var feet := b.board.cam.unproject_position(b.board.to_global(v.position))
			pos[str(bu.data.display_name) + "_" + str(bu.cell)] = {"team": bu.team, "head": [head.x, head.y], "feet": [feet.x, feet.y], "hp": bu.hp, "max": bu.max_hp()}
		var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(pos, " "))
		f.close()
	for i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	get_tree().quit(0)
