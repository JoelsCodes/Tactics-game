extends Node
## Frame-cost probe: godot --path godot res://tests/perf_probe.tscn -- scenario=idle|walk|scroll off=ssao,glow,fog,sun,omni,dof,pcss,lut frames=40
## Prints the average frame time and the script time per frame. Under software rendering (no GPU) the numbers are only relative.
var args := {"scenario": "idle", "off": "", "frames": "40"}
func _ready():
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = Riverford.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 100000.0
	add_child(s)
	await get_tree().create_timer(1.5).timeout
	var b := s.board
	if args.has("quality"):
		Board3D.quality = int(args.quality)
		b.apply_quality()
	var off: PackedStringArray = String(args.off).split(",")
	if "ssao" in off: b.env.ssao_enabled = false
	if "glow" in off: b.env.glow_enabled = false
	if "fog" in off: b.env.volumetric_fog_enabled = false; b.env.fog_enabled = false
	if "sun" in off: b.sun.shadow_enabled = false
	if "omni" in off:
		for c in b.get_children():
			if c is OmniLight3D: c.shadow_enabled = false
	if "pcss" in off:
		b.sun.light_angular_distance = 0.0; b.sun.shadow_blur = 1.0
		for c in b.get_children():
			if c is OmniLight3D: c.shadow_blur = 1.0
	if "dof" in off:
		var at := b.cam.attributes as CameraAttributesPractical
		at.dof_blur_far_enabled = false; at.dof_blur_near_enabled = false
	if "lut" in off: b.env.adjustment_enabled = false
	if "ui" in off: s.hud.visible = false
	if "mist" in off:
		for c in b.get_children():
			if c is CPUParticles3D or c is GPUParticles3D: c.emitting = false
	var king: BattleUnit = s.battle.deployment.king
	if args.scenario == "scroll" and s.scrolling:
		s.focus(s.scroll_range.x)
	for i in 10: await get_tree().process_frame
	var n := int(args.frames)
	var t0 := Time.get_ticks_usec()
	var script_t := 0.0
	var draws := 0
	for i in n:
		if args.scenario == "scroll" and s.scrolling and i % 20 == 0:
			s.focus(s.scroll_range.y if (i / 20) % 2 == 0 else s.scroll_range.x)
		await get_tree().process_frame
		script_t += Performance.get_monitor(Performance.TIME_PROCESS)
		draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var dt := float(Time.get_ticks_usec() - t0) / 1000.0 / n
	print("PERF scenario=%s off=%s frame=%.1f ms script=%.2f ms draws=%d prims=%d objs=%d nodes=%d" % [args.scenario, args.off, dt, script_t / n * 1000.0, draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	get_tree().quit()
