extends Node
## Headless check that every sample map builds from the tile art in all four rotations and every
## character's animations load: godot --headless --path godot res://tests/check.tscn

var fails := 0


## On-screen height in px of a 100 px tall figure standing at the unit's feet.
func _screen_height(board: Board3D, v: UnitView3D) -> float:
	var feet := board.cam.unproject_position(v.global_position)
	var head := board.cam.unproject_position(v.global_position + Vector3(0, 100.0 * v.sprite.pixel_size * v.sprite.scale.y, 0))
	return absf(feet.y - head.y)


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq_cell(a: Vector2i, b: Vector2i, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	var t := Terrain.new()
	add_child(t)
	for path in ["res://samples/all_terrains.json", "res://samples/grass_hills.json", "res://samples/intro_forest.json"]:
		var m := Terrain.load_map(path)
		ok(m.w > 0 and m.d > 0, path + " parses")
		for r in 4:
			t.rot = r
			t.show_map(m)
			await get_tree().process_frame
			ok(t.blocks.size() == m.w * m.d, "%s rot %d builds every tile" % [path, r])
		for row in m.tiles:
			for c in row:
				ok(Terrain.LOOK.has(c.t), "%s terrain %s has a look" % [path, c.t])
	# lighting: a tile next to a taller one on the lit side gets a shadow, the tall one stays bright
	var lm := {"w": 2, "d": 1, "smooth": false, "tiles": [[{"t": "g", "h": 0}, {"t": "g", "h": 2}]]}
	t.rot = 0
	t.show_map(lm)
	var flat := [0.0, 0.0, 0.0, 0.0]
	var low: Array = t.corner_shade(0, 0, 0.0, flat)
	ok(low.size() == 4 and low.all(func(v): return v <= 1.0), "corner shades are at most 1")
	var lone := {"w": 1, "d": 1, "smooth": false, "tiles": [[{"t": "g", "h": 0}]]}
	t.show_map(lone)
	ok(t.corner_shade(0, 0, 0.0, flat).all(func(v): return v == 1.0), "an isolated flat tile is unshaded")
	t.show_map(lm)
	# view rotation 0: the neighbour toward the light is grid (0, +1), so nothing here is shadowed...
	ok(t.corner_shade(0, 0, 0.0, flat).all(func(v): return v == 1.0), "a tall neighbour away from the light casts nothing")
	# ...and a corner whose surroundings stand higher than the tile is occluded
	ok(t.corner_shade(0, 0, 0.0, [0.0, 2.0, 0.0, 0.0])[1] < 1.0, "a raised corner darkens (ambient occlusion)")
	var col := {"w": 1, "d": 2, "smooth": false, "tiles": [[{"t": "g", "h": 0}], [{"t": "g", "h": 2}]]}
	t.show_map(col)
	var sh: Array = t.corner_shade(0, 0, 0.0, flat)
	ok(sh[2] < 1.0 and sh[3] < 1.0 and sh[2] < sh[0], "a taller tile on the lit side shadows the near corners most")
	for r in 4:
		t.rot = r
		t.show_map(col)
		ok(t.corner_shade(0, 0, 0.0, flat).size() == 4, "corner shading builds in rotation %d" % r)
	# 3D board: builds headless, lit, fogged, sky backdrop, units upright on the block tops
	var dio := Board3D.new()
	add_child(dio)
	dio.setup(Terrain.load_map("res://samples/demo_battlefield.json"))
	var u := dio.add_unit("hero", 0, 3)
	ok(dio.get_node("Terrain").mesh.get_surface_count() > 0, "diorama terrain mesh has surfaces")
	ok(dio.sun.shadow_enabled and dio.sun.light_angular_distance > 0.0, "diorama sun casts soft shadows")
	ok(dio.env.fog_enabled and dio.env.background_mode == Environment.BG_SKY, "diorama has fog and a sky backdrop")
	ok(u.sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y and u.rotation == Vector3.ZERO, "units are upright billboards")
	ok(u.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "unit pixels use nearest filtering")
	var to_cam: Vector3 = dio.cam.global_position - u.global_position
	ok(is_equal_approx(u.sprite.scale.y / u.sprite.scale.x * cos(asin(to_cam.y / to_cam.length())), 1.0), "units are stretched by 1/cos(the camera's elevation at them) to undo the foreshortening")
	# a unit is the same size on screen near the camera and far from it
	var far := dio.add_unit("hero", 11, 13)
	var near_h := _screen_height(dio, u)
	var far_h := _screen_height(dio, far)
	ok(absf(near_h - far_h) / near_h < 0.02, "a unit keeps its on-screen size near and far (%.1f vs %.1f px)" % [near_h, far_h])
	ok(is_equal_approx(u.body.scale.y, 1.0), "the shadow body keeps its real height")
	ok(dio.uprights.size() > 1, "trees on the map stand as billboards too")
	# picking: the ray through a tile's projected top center finds that tile, in every view rotation
	for r in 4:
		dio.rotate_view(1)
		for c in [Vector2i(0, 3), Vector2i(5, 5), Vector2i(11, 13)]:
			eq_cell(dio.pick(dio.cam.unproject_position(dio.top_point(c.x, c.y))), c, "pick rot %d" % dio.rot)
	var gx := dio.screen_dir(Vector2i(1, 0))
	var gz := dio.screen_dir(Vector2i(0, 1))
	ok((absf(gx.x) > 0.95 or absf(gx.y) > 0.95) and (absf(gz.x) > 0.95 or absf(gz.y) > 0.95), "the view is square-on: both grid axes run along the screen axes, never diagonal")
	ok(u.position.is_equal_approx(Vector3(0.5, 2 * Board3D.LEVEL, 3.5)), "a unit stands on its block's top (level 2)")
	ok(dio.env.adjustment_color_correction == null and is_equal_approx(dio.env.volumetric_fog_density, 0.003), "default map: natural grade, light haze")
	ok(dio.sky.sky_material is ShaderMaterial and not dio.shafts[0].visible, "default map: radial twilight backdrop, no god-rays")
	var moody := Terrain.load_map("res://samples/demo_battlefield.json")
	moody["grade"] = "sepia"
	moody["haze"] = "heavy"
	var dio2 := Board3D.new()
	add_child(dio2)
	dio2.setup(moody)
	ok(dio2.env.adjustment_color_correction != null and is_equal_approx(dio2.env.volumetric_fog_density, 0.012) and dio2.dust.amount == 220, "a map can ask for sepia and heavy haze")
	dio2.free()
	dio.free()
	# skill database: physical skills from data/skills
	var phys := SkillLibrary.physical()
	ok(phys.size() >= 1, "the physical skill list loads")
	var qj: SkillData = phys.filter(func(x): return x.display_name == "Quick Jab")[0]
	ok(qj.is_physical() and qj.rank == SkillData.Rank.E and qj.sp_cost == 3, "Quick Jab: physical, rank E, 3 SP")
	ok(qj.animation == "attack", "Quick Jab animates as the melee combo")
	ok(qj.effect == "slash", "Quick Jab's effect is a slash on its own sheet")
	ok(qj.allows_move_after, "Quick Jab lets the unit walk again after the action")
	ok(BattleStage.action_anim(BattleAction.use(qj)) == "attack", "the skill's animation is used")
	for f in ["panel_stone.png", "panel_wood.png", "button_normal.png", "button_hover.png", "button_pressed.png", "button_disabled.png", "bar_back.png", "bar_fill.png", "divider.png", "menu_bg.jpg"]:
		ok(ResourceLoader.exists(HudStyle.UI_DIR + f), "ui art " + f)
	for f in ["Cinzel-Medium.ttf", "Cinzel-Bold.ttf", "Lato-Regular.ttf", "Lato-Bold.ttf"]:
		ok(ResourceLoader.exists(HudStyle.FONT_DIR + f), "font " + f)
	ok(HudStyle.theme().get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "panels use the textured style")
	for sh_path in ["terrain_face", "tile_highlight_3d"]:
		ok(load("res://shaders/%s.gdshader" % sh_path) is Shader, sh_path + " shader loads")
	for k in Terrain.LOOK:
		var L: Dictionary = Terrain.LOOK[k]
		if L.get("void"):
			continue
		ok(ResourceLoader.exists("res://assets/tiles/side_%s_l.png" % L.side), "side strip " + L.side)
		var top := "res://assets/tiles/ground_%s.png" % L.top if L.top in Terrain.SEAMLESS and not L.has("water") and not L.get("lava") else "res://assets/tiles/%s_00.png" % L.top
		ok(ResourceLoader.exists(top), "top " + top)
	var need := ["idle_f", "idle_b", "ready_f", "ready_b", "walk_f", "walk_b", "hit_f", "hit_b", "attack", "cast", "victory", "ko"]
	for ch in Character.names():
		var sf: SpriteFrames = load("res://assets/characters/%s.tres" % ch)
		ok(sf != null, ch + " frames")
		for a in need:
			ok(sf != null and sf.has_animation(a) and sf.get_frame_count(a) > 0, ch + " " + a)
			ok(Character.meta(ch).anims.has(a), ch + " meta " + a)
	print("checks done, %d failed" % fails)
	get_tree().quit(1 if fails else 0)
