extends Node
## Screenshot tour of the UI. Needs a real renderer (not --headless), e.g.:
##   xvfb-run -a godot --path godot res://tests/shots.tscn -- out=/tmp/shots
## Saves PNGs to `out` and plays one battle to the end on auto.

var out := "user://shots"
var Battle = preload("res://scripts/battle.gd")


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	await run()
	get_tree().quit()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func wait_for(cond: Callable, limit := 30.0) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > limit:
			return false
	return true


func run() -> void:
	var title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await wait(.5)
	await shot("01_title")
	title.queue_free()

	Battle.stage = 0
	Battle.auto = false
	var b = load("res://scenes/battle.tscn").instantiate()
	add_child(b)
	if not await wait_for(func(): return b.mode == "menu"):
		print("FAIL no player turn")
		return
	await wait(.8)
	await shot("02_turn_menu")
	b.bmove()
	await wait(.3)
	await shot("03_move_range")
	# walk toward the nearest foe
	var a: Dictionary = b.actor
	var foe = Rules.nearest_foe(b.B, a)
	var best = null
	for k in b.reach_r.out:
		var t: Dictionary = b.reach_r.out[k]
		if best == null or absi(t.x - foe.x) + absi(t.y - foe.y) < absi(best.x - foe.x) + absi(best.y - foe.y):
			best = t
	b.do_move(best.x, best.y)
	await wait_for(func(): return b.mode == "menu")
	b.bact()
	await wait(.3)
	await shot("04_act_list")
	b.close_sheet()
	b.bpick("fight")
	var targets: Array = Rules.range_tiles(b.B, a, Rules.FIGHT).filter(func(p):
		var u = Rules.unit_at(b.B, p[0], p[1])
		return u != null and u.team == 1 and not u.ko)
	if targets.is_empty():
		var magic := Rules.usable_ids(b.B, a).filter(func(id): return id != "fight" and Rules.blocked(b.B, a, Rules.ability_for(id)) == "")
		if not magic.is_empty():
			b.bpick(magic[0])
	b._on_tap(foe.x, foe.y)
	await wait(.3)
	await shot("05_target")
	# hand the rest to the AI
	Battle.auto = true
	if b.mode == "target" and b.center != null and not Rules.targets_of(b.B, a, Rules.ability_for(b.ab_id), b.center[0], b.center[1]).is_empty():
		b.do_act()
		await wait(2.5)
		await shot("06_after_attack")
	elif b.mode != "face":
		b.bwait()
	await wait_for(func(): return b.mode == "face", 10)
	if b.mode == "face":
		await shot("07_facing")
		b.bface(a.f)
	var ok := await wait_for(func(): return b.B.over != 0, 240)
	await wait(2.5)
	await shot("08_battle_end")
	print("battle over=%d turns=%d ok=%s" % [b.B.over, b.B.turnNo, ok])
	b.queue_free()

	for s in [1, 2]:
		Battle.stage = s
		Battle.auto = true
		var bb = load("res://scenes/battle.tscn").instantiate()
		add_child(bb)
		await wait(1.6)
		await shot("%02d_mission%d" % [8 + s * 2 - 1, s + 1])
		bb.world.rotate_view(1)
		await wait(.4)
		await shot("%02d_mission%d_rotated" % [8 + s * 2, s + 1])
		bb.queue_free()
		await wait(.2)
