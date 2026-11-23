extends Node
## Checks by eye that units stand upright on screen while they move (Claude, Nov 2026): every unit is drawn upright by the shear in
## shaders/upright_shear.gdshaderinc, and this catches them mid-walk (with an afterimage trail), mid-dash, mid-attack and mid-flash, with the
## view scrolled so they sit near the screen's edges, where a perspective lean is largest. Needs a window:
##   godot --path godot --resolution 1920x1080 res://tests/upright_motion_shot.tscn -- map=pg_14 out=C:/path
## Saves <out>/<stage>_full.png and 4x crops of each unit (<stage>_<n>.png), and prints each unit's on-screen lean as measured by screen_top.
var out := "user://upright_motion"
var map_id := "pg_14"
var b: BattleStage
var focus_col := -1.0  ## focus=<column>: scroll the camera to that board column, save <out>/focus_full.png and stop (a long map's far end)
var with_rex := false  ## with=rex: Rex joins and leads the party


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("map="):
			map_id = a.substr(4)
		elif a.begins_with("focus="):
			focus_col = float(a.substr(6))
		elif a == "with=rex":
			with_rex = true
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.dir = "user://test_saves_upright_motion"
	seed(7)
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	if with_rex:  # with=rex: Rex leads the party (his sheet in play)
		var g := Rex.recruit(BattleStage.pending_game)
		var rex: Array = g.roster.co_captains.filter(func(c): return c.display_name == "Rex")
		g.roster.set_party(rex + g.roster.co_captains.filter(func(c): return c.display_name != "Rex"))
	BattleStage.pending_setup = WorldData.setup_for(map_id, 1, true)
	b = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	var waited := 0.0
	while waited < 40.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(1.0).timeout
	b.highlights.clear_all()
	if focus_col >= 0.0:
		b.focus(focus_col)
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/focus_full.png" % out)
		get_tree().quit(0)
		return
	var views: Array = []
	_collect(b, views)
	var cam := get_viewport().get_camera_3d()
	# put the units toward the screen's sides: sort by screen x and take the outermost few on each side
	views.sort_custom(func(p, q): return cam.unproject_position(p.global_position).x < cam.unproject_position(q.global_position).x)
	var picks: Array = []
	for i in mini(3, views.size()):
		picks.append(views[i])
		if views.size() - 1 - i > i:
			picks.append(views[views.size() - 1 - i])
	await _shoot("still", picks)
	for v in picks:  # walking in place with a haste trail
		v.trail_color = Color(0.6, 0.85, 1.0, 0.5)
		v.play("walk")
		v.face(Vector2(1, 0.3))
	var start := {}
	for v in picks:
		start[v] = v.position
	for i in 10:  # slide them sideways across a tile, as a move does
		for v in picks:
			v.position = start[v] + Vector3(0.08 * i, 0, 0.05 * i)
		await get_tree().process_frame
		await get_tree().process_frame
	await _shoot("walk_trail", picks)
	for v in picks:
		v.trail_color = Color(0, 0, 0, 0)
		v.position = start[v]
		v.play("idle")
	await get_tree().create_timer(0.5).timeout
	for v in picks:
		v.dash(Vector3(1, 0, 0.4).normalized(), 0.7, 0.25)
	for i in 8:
		await get_tree().process_frame
	await _shoot("dash", picks)
	await get_tree().create_timer(0.6).timeout
	for v in picks:
		v.act("attack")
	for i in 14:
		await get_tree().process_frame
	await _shoot("attack", picks)
	await get_tree().create_timer(1.0).timeout
	for v in picks:
		v.hit_react(Vector3(-1, 0, 0), UnitView3D.KNOCK_DISTANCE, 0.4)
	for i in 3:
		await get_tree().process_frame
	await _shoot("flash", picks)
	await get_tree().create_timer(0.8).timeout
	for turn in 3:  # the other three views, where the back walls come to the front: hidden units show their silhouette
		b.turn_view(1)
		await get_tree().create_timer(1.5).timeout
		var all: Array = []
		_collect(b, all)
		await _shoot("view%d" % (turn + 1), all)
	get_tree().quit(0)


func _shoot(stage: String, picks: Array) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_full.png" % [out, stage])
	var cam := get_viewport().get_camera_3d()
	var row := Image.create(picks.size() * 400, 640, false, Image.FORMAT_RGBA8)
	row.fill(Color(0.1, 0.1, 0.12, 1))
	for i in picks.size():
		var v: UnitView3D = picks[i]
		var feet := cam.unproject_position(v.sprite.global_position)
		var r := Rect2i(int(feet.x) - 50, int(feet.y) - 150, 100, 160).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		var c := img.get_region(r)
		c.convert(Image.FORMAT_RGBA8)
		c.resize(r.size.x * 4, r.size.y * 4, Image.INTERPOLATE_NEAREST)
		row.blend_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i(i * 400, 0))
		var top := v.screen_top(cam, v.figure_height())
		var lean := rad_to_deg(atan2(top.x - feet.x, feet.y - top.y))
		print("%s: %s (%s) at screen x %d: lean %.2f deg, shears %s" % [stage, v.char_name, Character.sheet(v.char_name), int(feet.x), lean, v.shears_upright()])
	row.save_png("%s/%s_units.png" % [out, stage])


func _collect(n: Node, into: Array) -> void:
	if n is UnitView3D:
		into.append(n)
	for c in n.get_children():
		_collect(c, into)
