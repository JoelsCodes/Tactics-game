extends Node
## Frames of the ITEMS command (Nov 2026) in a Proving Grounds battle: <out>_list.png (the bag open, a hurt ally beside the unit), <out>_aim.png (a Potion
## aimed at the ally, its heal previewed), <out>_used.png (after the Potion). Needs a window:
##   godot --path godot --resolution 1920x1080 res://tests/items_shot.tscn -- out=C:/path/items
func _ready() -> void:
	var out := "/tmp/items"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	SaveSystem.dir = "user://test_saves_items_shot"
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
	var me: BattleUnit = b.battle.current
	var ally: BattleUnit = null
	for u in b.battle.all_units():
		if u != me and u.team == me.team and absi(u.cell.x - me.cell.x) + absi(u.cell.y - me.cell.y) <= 1:
			ally = u
	if ally == null:  # nobody next to the unit: hurt the unit itself
		ally = me
	ally.hp = maxi(1, ally.max_hp() / 3)
	ally.add_status(BattleUnit.POISON, 3)
	var pal := b.hud.palette
	pal.show_commands(me, b.battle)
	pal.open_list("items")
	await get_tree().create_timer(0.5).timeout
	_grab(out + "_list.png")
	var potion := BattleAction.use_item(ItemCatalog.get_item(&"potion"))
	pal.action_chosen.emit(potion)
	await get_tree().create_timer(0.3).timeout
	b._aim_at(ally.cell)
	await get_tree().create_timer(0.5).timeout
	_grab(out + "_aim.png")
	b._perform()
	await get_tree().create_timer(2.0).timeout
	_grab(out + "_used.png")
	get_tree().quit(0)


func _grab(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
