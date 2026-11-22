extends Node
## Headless: Cancel (Esc) with no menu open takes back the turn's walk (position, facing, move points; not after acting).
## godot --headless --path godot res://tests/undo_move_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_game = g
	BattleStage.pending_setup = FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, [Vector2i(1, 3), Vector2i(1, 5)])
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.0
	b.animate = false
	add_child(b)
	await get_tree().process_frame
	var dm := b.battle.deployment
	var king := dm.king
	var guard := 0
	while b.battle.current != king and guard < 30:
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame
	ok(b.battle.current == king, "it is Alaric's turn")
	# undo a walk
	var start := king.cell
	var face0 := king.facing
	ok(not b.battle.undo_move(king), "nothing to take back before a walk")
	var spot: Vector2i = b.battle.move_range(king).cells().filter(func(c): return c != start and dm.prop_at(c) == null)[0]
	var budget0 := b.battle.move_budget(king)
	b.walk(king, spot)
	await get_tree().process_frame
	ok(b.battle.moved and king.cell == spot and b.mode == BattleStage.Mode.IDLE, "the King walked")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	b._unhandled_input(key)
	ok(king.cell == start and not b.battle.moved and king.facing == face0, "Esc (no menu open) put him back, facing as before")
	ok(b.battle.grid.occupant(start) == king and b.battle.grid.occupant(spot) == null, "the grid agrees")
	ok(b.battle.move_budget(king) == budget0, "and he has all his move points")
	ok(b.battle.move(king, spot), "he can walk again")
	b.battle.acted = true
	ok(not b.battle.undo_move(king), "no taking back after acting")
	b.battle.acted = false
	ok(b.battle.undo_move(king), "(before acting it works)")
	print("undo move checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails > 0 else 0)
