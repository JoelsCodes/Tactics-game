extends Node
## The Sacred Canal Bridge battle (Proving Grounds 6) on a real display: the invisible-grid acceptance shots (unselected and selected, in all four views), a few frames of
## measurement (frame time, draw calls, triangles, video memory; vsync off) and a unit walking. Needs a window (not --headless):
## godot --path godot --resolution 1920x1080 res://tests/sacred_canal_shot.tscn -- out=C:/path/to/folder
var out := "user://sacred_canal"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	SaveSystem.dir = "user://test_saves_sacred_canal_shot"
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for("pg_6", 1, true)
	var t0 := Time.get_ticks_msec()
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	print("battle scene built in %d ms (the 70 MB GLB loads inside it)" % (Time.get_ticks_msec() - t0))
	var waited := 0.0
	while waited < 40.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(1.0).timeout
	print("renderer: %s | %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	await _measure(b, "default view, selected unit")
	for q in 4:
		await _shot(b, "selected_view%d" % (q + 1))
		b.turn_view(1)
		await get_tree().create_timer(0.6).timeout
	b.highlights.clear_all()
	for q in 4:
		await _shot(b, "unselected_view%d" % (q + 1))
		if q == 3:
			await _measure(b, "view 4 (gate side hidden)")
		b.turn_view(1)
		await get_tree().create_timer(0.6).timeout
	await _measure(b, "default view, nothing selected")
	get_tree().quit(0)


func _shot(b: BattleStage, name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _measure(b: BattleStage, what: String) -> void:
	for i in 30:
		await get_tree().process_frame
	var n := 240
	var t := Time.get_ticks_usec()
	var worst := 0
	var last := t
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	var avg := float(Time.get_ticks_usec() - t) / n / 1000.0
	print("PERF %s: avg %.2f ms (%.0f fps), worst frame %.1f ms, draw calls %d, triangles %d, objects %d, video mem %.0f MB, texture mem %.0f MB" % [
		what, avg, 1000.0 / avg, worst / 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
