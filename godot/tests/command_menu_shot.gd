extends Node
## Frames of the command menu's selection gliding from Attack to Wait: out_a.png (rest), out_b.png (a third of the way), out_c.png (two thirds), out_d.png (arrived),
## out_e.png (the confirm flash). xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/command_menu_shot.tscn -- out=/tmp/cm
func _ready() -> void:
	var out := "/tmp/command_menu"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	SaveSystem.dir = "user://test_saves_command_menu_shot"
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for("pg_1", 1, true)
	BattleStage.show_intro = false
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	var waited := 0.0
	while waited < 30.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(1.0).timeout
	var pal := b.hud.palette
	var region := Rect2i(560, 770, 800, 310)
	_grab(out + "_a.png", region)
	pal.end_button.mouse_entered.emit()  # the selection moves from Attack down to Wait: a glide of 120 ms
	await get_tree().create_timer(0.04).timeout
	_grab(out + "_b.png", region)
	await get_tree().create_timer(0.04).timeout
	_grab(out + "_c.png", region)
	await get_tree().create_timer(0.3).timeout
	_grab(out + "_d.png", region)
	pal.end_button.pressed.emit()  # a confirm: the bar flashes for 80 ms (this also ends the turn, which is fine here)
	await get_tree().create_timer(0.02).timeout
	_grab(out + "_e.png", region)
	get_tree().quit(0)


func _grab(path: String, r: Rect2i) -> void:
	get_viewport().get_texture().get_image().get_region(r).save_png(path)
