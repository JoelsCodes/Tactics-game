extends Node
## Identical-camera comparison of the character rendering modes (UnitView3D.RenderMode) on one map, at the real gameplay resolution.
## look=ref [scale=0.6]: the reference-look prototype (smaller sprites, soft filter, LookPost grade/blur/vignette). Needs a window: godot --path godot --resolution 1920x1080 res://tests/sprite_render_shot.tscn -- mode=original|lit|hybrid map=pg_13 out=C:/path [hood=<char name>]
## Saves <out>/<mode>_full.png, and 4x nearest-neighbour crops of Alaric and of a hooded enemy (<mode>_alaric.png, <mode>_hood.png), and prints how
## many screen pixels one drawn sprite pixel covers (the projection scale).
var out := "user://sprite_render"
var mode := "original"
var map_id := "pg_13"
var hood := ""
var look := ""
var walkshot := false
var look_scale := 0.6


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("mode="):
			mode = a.substr(5)
		elif a.begins_with("map="):
			map_id = a.substr(4)
		elif a.begins_with("sheet="):
			Character.sheet_alias["king"] = a.substr(6)
		elif a == "walkshot":
			walkshot = true
		elif a.begins_with("look="):
			look = a.substr(5)
		elif a.begins_with("scale="):
			look_scale = float(a.substr(6))
		elif a.begins_with("hood="):
			hood = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.dir = "user://test_saves_sprite_render"
	if look == "ref":
		UnitView3D.look_scale = look_scale
		UnitView3D.look_soft = true
		var lp = load("res://scripts/stage/look_post.gd").new()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("lp_"):
				lp.material.set_shader_parameter(a.substr(3, a.find("=") - 3), float(a.substr(a.find("=") + 1)))
		add_child(lp)
	UnitView3D.set_render_mode({"original": UnitView3D.RenderMode.ORIGINAL, "lit": UnitView3D.RenderMode.BASIC_LIT, "hybrid": UnitView3D.RenderMode.HYBRID}[mode], true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("p_"):
			UnitView3D.hybrid_params[a.substr(2, a.find("=") - 2)] = float(a.substr(a.find("=") + 1))
	seed(7)  # the idle frames and the breathing phase start the same in every run
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for(map_id, 1, true)
	var b: BattleStage = load("res://scenes/battle.tscn").instantiate()
	b.enemy_delay = 0.05
	add_child(b)
	var waited := 0.0
	while waited < 40.0 and (b.battle.current == null or b.battle.current.team != 0):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(1.0).timeout
	b.highlights.clear_all()
	var views: Array = []
	_collect(b, views)
	var alaric: UnitView3D
	var hooded: UnitView3D
	for v in views:
		var u := v as UnitView3D
		u.sprite.pause()
		u.sprite.set_frame_and_progress(0, 0.0)
		print("unit ", u.char_name, " sheet ", Character.sheet(u.char_name), " at ", u.global_position)
		if alaric == null and Character.sheet(u.char_name).begins_with("alaric_v"):
			alaric = u
		if hooded == null and ((hood != "" and u.char_name == hood) or (hood == "" and u.char_name != alaric_name() and not Character.sheet(u.char_name).begins_with("alaric_v") and u.char_name.to_lower().find("watch") >= 0)):
			hooded = u
	if hooded == null:
		for v in views:
			if not Character.sheet((v as UnitView3D).char_name).begins_with("alaric_v"):
				hooded = v
				break
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_full.png" % [out, mode])
	_crop(img, alaric, "%s/%s_alaric.png" % [out, mode])
	_crop(img, hooded, "%s/%s_hood.png" % [out, mode])
	if alaric != null:
		_print_scale(alaric)
		if alaric != null and alaric._hybrid_mat != null:
			print("alaric normal map in use: ", alaric._hybrid_mat.get_shader_parameter("use_normal"))
	if walkshot and alaric != null:
		var dirs := ["s", "e", "n", "w"]
		var sheet := Image.create(6 * 360, dirs.size() * 510, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.1, 0.1, 0.12, 1))
		for r in dirs.size():
			for i in 6:
				alaric.sprite.animation = "walk_" + dirs[r]
				alaric.sprite.set_frame_and_progress(i, 0.0)
				for k in 4:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var full := get_viewport().get_texture().get_image()
				var cam := get_viewport().get_camera_3d()
				var feet := cam.unproject_position(alaric.global_position)
				var c := full.get_region(Rect2i(int(feet.x) - 60, int(feet.y) - 150, 120, 170))
				c.convert(Image.FORMAT_RGBA8)
				c.resize(360, 510, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(c, Rect2i(0, 0, 360, 510), Vector2i(i * 360, r * 510))
		sheet.save_png("%s/%s_walk.png" % [out, mode])
	print("hooded unit: ", hooded.char_name if hooded else "none", " | mode ", mode)
	get_tree().quit(0)


func alaric_name() -> String:
	return "king"


func _collect(n: Node, into: Array) -> void:
	if n is UnitView3D:
		into.append(n)
	for c in n.get_children():
		_collect(c, into)


func _crop(img: Image, v: UnitView3D, path: String) -> void:
	if v == null:
		return
	var cam := get_viewport().get_camera_3d()
	var feet := cam.unproject_position(v.global_position)
	var r := Rect2i(int(feet.x) - 60, int(feet.y) - 150, 120, 170).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(c.get_width() * 4, c.get_height() * 4, Image.INTERPOLATE_NEAREST)
	c.save_png(path)


## Screen pixels per drawn sprite pixel, across and up. 1.0 everywhere would be a perfectly even pixel grid.
func _print_scale(v: UnitView3D) -> void:
	var cam := get_viewport().get_camera_3d()
	var s := v.sprite
	var gx := s.global_transform.basis.x * s.pixel_size * 100.0
	var gy := s.global_transform.basis.y * s.pixel_size * 100.0
	var o := cam.unproject_position(s.global_position)
	print("projection: 100 sprite px across = %.1f screen px, 100 sprite px up = %.1f screen px (viewport %s)" % [(cam.unproject_position(s.global_position + gx) - o).length(), (cam.unproject_position(s.global_position + gy) - o).length(), get_viewport().get_visible_rect().size])
