extends Node
func _ready() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var s := BattleSetup.new()
	s.map_path = path
	s.king_cell = Vector2i(1, 8)
	var e := FirstBattle.squire(1)
	s.enemies = [[e, Vector2i(10, 8)]]
	BattleStage.pending_game = FirstBattle.game()
	BattleStage.pending_setup = s
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 1000.0
	add_child(b)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	get_tree().quit()
