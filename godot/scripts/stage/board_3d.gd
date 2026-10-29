class_name Board3D
extends Node3D
## The battlefield as a 3D diorama, built from a map (Terrain.parse format) with the tile art: every tile
## is a column of real geometry (top quad plus the exposed side walls down to the lower neighbour), lit
## by a warm directional sun with soft real-time shadows and two soft omni fills, with a sky gradient,
## light fog, SSAO, glow and grading from a WorldEnvironment, and a tilted perspective camera (long lens,
## about 50 degrees) with depth-of-field blur for the miniature look. Units (`UnitView3D`) and trees are
## upright billboards standing on the tops.
## Needs the Forward+ (or Mobile) renderer: SSAO, DoF and soft shadows do not exist in Compatibility.
## Grid x runs to the screen's lower right, grid y to its lower left (view rotation 0, as in 2D).
## See README "3D board".

signal view_changed  ## the camera moved, zoomed or turned

const PX_PER_UNIT := 45.25  ## 2D pixels per world unit (a tile is 64x32 px on screen = 1 unit square)
const LEVEL := 0.42  ## height of one level in world units
const BASE := 1.2  ## how far the board's outer walls reach below level 0 (units)
const SIDE_TEXELS := 3.0 * PX_PER_UNIT  ## side texture pixels per world unit (as in 2D: SIDE_PX 3)
const UNIT_SCALE := 1.45  ## sprite size against the blocks (1 = the 2D game's ratio)
const TEX := 96.0
const DEFAULT_GRADE := "natural"  ## true colors, dramatic contrast (maps may ask for "sepia" or "golden")
const DEFAULT_HAZE := "light"  ## maps may ask for "heavy"
const DEFAULT_BACKDROP := "sky"  ## "sky" (the procedural sky gradient) or "radial" (twilight glow behind the board)
const DEFAULT_GOD_RAYS := false  ## ground texture pixels per tile (as in 2D)

var map: Dictionary
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var dust: GPUParticles3D
var sky: Sky
var shafts: Array[MeshInstance3D] = []  ## god-ray quads (see set_god_rays)
var mist: MeshInstance3D
var yaw := 45.0
var pitch := -50.0
var fov := 28.0
var distance := 0.0
var target := Vector3.ZERO
var rot := 0  ## view rotation in quarter turns (0..3); the camera orbits, the board never changes
var zoom := 1.0  ## camera distance factor (smaller = closer)
var uprights: Array[Node3D] = []  ## billboards stretched against the camera pitch (`fit(k)`)
var units: Array[UnitView3D] = []  ## only for add_unit (screenshots and checks)
var _tex := {}  ## path -> Texture2D


func setup(m: Dictionary, p_pitch := -50.0, p_fov := 28.0, p_yaw := 45.0) -> void:
	map = m
	pitch = p_pitch
	fov = p_fov
	yaw = p_yaw
	_build_terrain()
	_build_trees()
	_build_light()
	_build_atmosphere()
	set_grade(String(map.get("grade", DEFAULT_GRADE)))
	set_haze(String(map.get("haze", DEFAULT_HAZE)))
	_build_shafts()
	set_backdrop(String(map.get("backdrop", DEFAULT_BACKDROP)))
	set_god_rays(bool(map.get("god_rays", DEFAULT_GOD_RAYS)))
	_build_camera()


## World position of the top of a cell (cell centers at x + .5, y + .5).
func top_point(x: int, y: int) -> Vector3:
	return Vector3(x + .5, _h(x, y) * LEVEL, y + .5)


func _h(x: int, y: int) -> float:
	var t: Dictionary = map.tiles[y][x]
	return t.h - (.35 if t.t == "W" else 0.0)


func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func _mat(path: String, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _load(path)
	m.albedo_color = tint
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	return m


func _build_terrain() -> void:
	var batches := {}  ## material key -> [SurfaceTool, StandardMaterial3D]
	for y in map.d:
		for x in map.w:
			var t: Dictionary = map.tiles[y][x]
			var L: Dictionary = Terrain.LOOK.get(t.t, Terrain.LOOK.g)
			if L.get("void"):
				continue
			var h := _h(x, y) * LEVEL
			var tint: Color = L.get("tint", Color.WHITE)
			# top
			var seamless: bool = L.top in Terrain.SEAMLESS and not L.has("water") and not L.get("lava") and L.n > 0
			var top_path: String
			var uv0 := Vector2(0, 0)
			var uv1 := Vector2(1, 1)
			if seamless:
				top_path = "res://assets/tiles/ground_%s.png" % L.top
				var sz := _load(top_path).get_size()
				uv0 = Vector2(x * TEX / sz.x, y * TEX / sz.y)
				uv1 = Vector2((x + 1) * TEX / sz.x, (y + 1) * TEX / sz.y)
			else:
				top_path = "res://assets/tiles/%s_%02d.png" % [L.top, int(Terrain.hash01(x, y) * maxi(L.n, 1)) % maxi(L.n, 1)]
			var st := _surface(batches, top_path, tint)
			_quad(st, Vector3(x, h, y), Vector3(x + 1, h, y), Vector3(x + 1, h, y + 1), Vector3(x, h, y + 1),
				Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y), Vector3.UP)
			# walls: the 2D art has a lit left strip and a pre-darkened right strip; here the sun does the
			# shading, so every face uses the lit (left) strip
			var side_l := "res://assets/tiles/side_%s_l.png" % L.side
			for f in [[Vector2i(0, 1), side_l], [Vector2i(1, 0), side_l], [Vector2i(0, -1), side_l], [Vector2i(-1, 0), side_l]]:
				var d: Vector2i = f[0]
				var nx: int = x + d.x
				var ny: int = y + d.y
				var bottom := -BASE
				if nx >= 0 and ny >= 0 and nx < map.w and ny < map.d and map.tiles[ny][nx].t != "v":
					bottom = _h(nx, ny) * LEVEL
				if bottom >= h - 0.001:
					continue
				var sst := _surface(batches, f[1], tint)
				_wall(sst, x, y, d, h, bottom, L.v0, _load(f[1]).get_size())
	var mesh := ArrayMesh.new()
	for k in batches:
		var b: Array = batches[k]
		if "shallow_" in k or "deep_" in k:  # water: glossy, so the sun glints on it
			b[1].roughness = 0.12
			b[1].metallic_specular = 0.9
		b[0].generate_tangents()
		b[0].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, b[1])
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	target = Vector3(map.w / 2.0, 0.6, map.d / 2.0)


func _surface(batches: Dictionary, path: String, tint: Color) -> SurfaceTool:
	var key := "%s|%s" % [path, tint.to_html()]
	if not batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key] = [st, _mat(path, tint)]
	return batches[key][0]


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3) -> void:
	var tris := [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]
	if (b - a).cross(c - a).dot(n) > 0.0:  # Godot's front face is clockwise; wind it so the normal faces out
		tris = [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]
	for v in tris:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## One wall quad on the face of tile (x, y) toward `d`, from height `top` down to `bottom`.
func _wall(st: SurfaceTool, x: int, y: int, d: Vector2i, top: float, bottom: float, v0: float, tex_size: Vector2) -> void:
	var a: Vector3
	var b: Vector3
	var n := Vector3(d.x, 0, d.y)
	var seg: float  # which quarter of the 4-tile strip
	if d.y != 0:  # a face along x
		seg = posmod(x, 4)
		var z := y + (1 if d.y > 0 else 0)
		a = Vector3(x, 0, z)
		b = Vector3(x + 1, 0, z)
	else:
		seg = posmod(y, 4)
		var xx := x + (1 if d.x > 0 else 0)
		a = Vector3(xx, 0, y)
		b = Vector3(xx, 0, y + 1)
	var u0 := seg * TEX / tex_size.x
	var u1 := (seg + 1) * TEX / tex_size.x
	var vt := v0 / tex_size.y
	var vb := (v0 + (top - bottom) * SIDE_TEXELS) / tex_size.y
	_quad(st, Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), Vector3(b.x, bottom, b.z), Vector3(a.x, bottom, a.z),
		Vector2(u0, vt), Vector2(u1, vt), Vector2(u1, vb), Vector2(u0, vb), n)


func _build_light() -> void:
	# overhead sun from the front-left: shadows fall up-right on screen
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, -40, 0)  # travels toward +x/-z: from the screen's front-left, shadows fall up-right
	sun.light_color = Color(1.0, .88, .68)  # warm late-afternoon sun
	sun.light_energy = 1.6
	sun.light_angular_distance = 1.2  # a sun disc, not a point: shadows soften with distance from the caster (PCSS)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)
	# soft warm and cool omni fills so shadows keep color and depth
	for spec in [[Vector3(map.w * .2, 5.5, map.d * .85), Color(1.0, .72, .45), 9.0, 18.0], [Vector3(map.w * .85, 4.5, map.d * .2), Color(.45, .6, 1.0), 6.0, 20.0]]:
		var o := OmniLight3D.new()
		o.position = spec[0]
		o.light_color = spec[1]
		o.light_energy = spec[2] * .12
		o.omni_range = spec[3]
		o.omni_attenuation = 1.4
		o.shadow_enabled = true
		o.shadow_blur = 2.5
		add_child(o)
	var we := WorldEnvironment.new()
	env = Environment.new()
	# sky: deep blue overhead fading to a warm dusky horizon; it also lights the shadows (ambient from sky)
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(.05, .09, .22)
	sky_mat.sky_horizon_color = Color(.55, .42, .38)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(.52, .38, .34)  # the camera looks down, so the backdrop is the "ground" half
	sky_mat.ground_bottom_color = Color(.03, .05, .13)
	sky_mat.ground_curve = 0.35
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.2
	sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(.36, .42, .62)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# atmosphere: light depth fog in a hazy warm-blue, thicker low down, so the far side of the board
	# and the void below it fade into the air
	env.fog_enabled = true
	env.fog_light_color = Color(.42, .44, .58)
	env.fog_light_energy = 0.6
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.fog_height = -0.5
	env.fog_height_density = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.ssao_enabled = true
	# heavy SSAO: deep contact shadows in the crevices between blocks and at the foot of every wall
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.8
	env.ssao_power = 1.5
	env.ssao_detail = 0.8
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.15  # a little occlusion even in direct sun
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.05
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(5, 0.5)
	# golden-hour grade: a color-correction gradient (1D LUT) lifting the shadows to warm violet, the
	# mid tones to amber and the highlights to soft gold; then contrast and saturation on top
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.25  # the warm LUT mutes blues and greens a little; win them back
	env.adjustment_color_correction = golden_hour_lut()
	# volumetric light: a thin warm haze the sun shines through (light shafts past the trees and units)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(1.0, .84, .62)
	env.volumetric_fog_emission = Color(.05, .03, .02)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_sky_affect = 0.0
	we.environment = env
	add_child(we)


## The backdrop: "sky" is the procedural sky (its lower half, as the camera looks down); "radial" is a
## screen-space radial gradient, warm twilight amber behind the board to midnight at the corners
## (shaders/backdrop_radial.gdshader).
func set_backdrop(name: String) -> void:
	if name == "radial":
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/backdrop_radial.gdshader")
		sky.sky_material = m
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(.3, .32, .44)
		env.ambient_light_energy = 0.7
	else:
		sky.sky_material = sky_mat
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY


## Volumetric light shafts (god-rays) slanting down from the sun across the board: soft additive quads
## along the sun's direction, turned to the camera, catching the dust motes.
func set_god_rays(on: bool) -> void:
	for q in shafts:
		q.visible = on


func _build_shafts() -> void:
	var mat_shader := load("res://shaders/light_shaft.gdshader")
	var spots := [[0.22, 0.3, 1.6], [0.48, 0.18, 2.4], [0.7, 0.42, 1.2], [0.35, 0.68, 2.0], [0.82, 0.75, 1.4]]
	for i in spots.size():
		var sp: Array = spots[i]
		var q := MeshInstance3D.new()
		q.name = "Shaft%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(sp[2], 16.0)
		q.mesh = quad
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = mat_shader
		m.set_shader_parameter("seed", float(i) * 1.37)
		m.set_shader_parameter("intensity", 0.12 + 0.06 * (i % 3))
		q.material_override = m
		q.set_meta("foot", Vector3(map.w * sp[0], 0.0, map.d * sp[1]))
		add_child(q)
		shafts.append(q)


## Lays each shaft along the sun's direction from its foot point and turns it to face the camera.
func _place_shafts() -> void:
	if shafts.is_empty() or sun == null or cam == null:
		return
	var up := (sun.transform.basis.z).normalized()  # toward the sun (the light travels along -z)
	var view := (cam.transform.origin - target).normalized()
	var z := (view - up * view.dot(up)).normalized()
	var x := up.cross(z).normalized()
	for q in shafts:
		var foot: Vector3 = q.get_meta("foot")
		var half := (q.mesh as QuadMesh).size.y / 2.0
		q.transform = Transform3D(Basis(x, up, z), foot + up * (half - 0.5))


## Atmosphere presets (maps set `"haze"`): "light" (the default) is a faint mist, a thin haze and a few
## motes; "heavy" is the thick smoky look (low mist, dense volumetric haze, lots of dust) for maps that
## want it.
func set_haze(name: String) -> void:
	var heavy := name == "heavy"
	(mist.material_override as ShaderMaterial).set_shader_parameter("density", 0.4 if heavy else 0.12)
	env.volumetric_fog_density = 0.012 if heavy else 0.003
	dust.amount = 220 if heavy else 90


## Color grade presets for the whole scene (maps set `"grade"`; "natural" is the default) (sun color, haze, sky, color curve, contrast, saturation):
##   "sepia": the strong golden-hour curve (amber everywhere)
##   "natural": true colors with dramatic contrast; warmth only from the sun and the haze
##   "golden": natural colors, a warm lift in the highlights only
func set_grade(name: String) -> void:
	match name:
		"sepia":
			sun.light_color = Color(1.0, .88, .68)
			env.volumetric_fog_albedo = Color(1.0, .84, .62)
			env.adjustment_contrast = 1.14
			env.adjustment_saturation = 1.25
			env.adjustment_color_correction = golden_hour_lut()
			sky_mat.ground_horizon_color = Color(.52, .38, .34)
			sky_mat.ground_bottom_color = Color(.03, .05, .13)
		"natural":
			sun.light_color = Color(1.0, .93, .82)
			env.volumetric_fog_albedo = Color(.95, .93, .9)
			env.adjustment_contrast = 1.2
			env.adjustment_saturation = 1.12
			env.adjustment_color_correction = null
			sky_mat.ground_horizon_color = Color(.36, .36, .5)
			sky_mat.ground_bottom_color = Color(.03, .04, .12)
		"golden":
			sun.light_color = Color(1.0, .91, .76)
			env.volumetric_fog_albedo = Color(1.0, .92, .8)
			env.adjustment_contrast = 1.18
			env.adjustment_saturation = 1.12
			env.adjustment_color_correction = highlight_warm_lut()
			sky_mat.ground_horizon_color = Color(.46, .38, .44)
			sky_mat.ground_bottom_color = Color(.03, .04, .12)


## A gentle curve: shadows and mid tones untouched, only the brightest third warmed toward gold.
static func highlight_warm_lut() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0), Color(.5, .5, .5), Color(.77, .75, .71), Color(1.0, .98, .9)])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


## The golden-hour grade as a 1D color-correction texture: input brightness -> output color.
static func golden_hour_lut() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	# per channel (Godot reads r, g and b through their own curves), so hues survive: red lifted a little,
	# blue lowered in the mids and highs, blue kept in the deepest shadows
	g.colors = PackedColorArray([Color(.02, .015, .035), Color(.24, .205, .215), Color(.55, .49, .42), Color(.83, .77, .66), Color(1.0, .97, .88)])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t


## Floating dust motes catching the sun over the whole board, and a low mist lying on the floor.
func _build_atmosphere() -> void:
	var size := Vector3(map.w, 3.0, map.d)
	dust = GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 220
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.position = Vector3(map.w / 2.0, 1.6, map.d / 2.0)
	dust.visibility_aabb = AABB(-size, size * 2.0)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = size / 2.0
	pm.direction = Vector3(0.4, 0.3, -0.2)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.04
	pm.initial_velocity_max = 0.14
	pm.gravity = Vector3(0, 0.01, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = Color(1.4, 1.15, .7, .9)
	dm.albedo_texture = load("res://assets/fx/soft_dot.png")
	dm.disable_receive_shadows = true
	quad.material = dm
	dust.draw_pass_1 = quad
	add_child(dust)
	mist = MeshInstance3D.new()
	mist.name = "Mist"
	var plane := PlaneMesh.new()
	plane.size = Vector2(map.w, map.d)
	mist.mesh = plane
	mist.position = Vector3(map.w / 2.0, 0.3, map.d / 2.0)
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := ShaderMaterial.new()
	mm.shader = load("res://shaders/floor_mist.gdshader")
	mm.set_shader_parameter("sheet_size", plane.size)
	mist.material_override = mm
	add_child(mist)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	cam.near = 0.5
	cam.far = 200.0
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 0.0  # set in frame_board
	attrs.dof_blur_far_transition = 10.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_amount = 0.05
	cam.attributes = attrs
	add_child(cam)
	frame_board()


## Orbit camera around the board center: distance so the whole map fits, DoF focus on the board.
func frame_board() -> void:
	var radius := Vector2(map.w, map.d).length() / 2.0
	distance = radius / tan(deg_to_rad(fov / 2.0)) * 0.92
	_place_camera()


## Fits the whole board into `free` (a rect of the viewport, e.g. between the HUD bands): sets the
## distance so the board's outline fills it, then shifts the view so the board is centered in it.
func frame_rect(free: Rect2, view: Vector2) -> void:
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	frame_board()
	for i in 4:
		var r := board_screen_rect(view)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return
		var k := maxf(r.size.x / free.size.x, r.size.y / free.size.y)
		distance *= k
		_place_camera()
	# shift the image: offsets are in world units at the target's distance
	var r2 := board_screen_rect(view)
	var px_per_unit := view.y / (2.0 * distance * tan(deg_to_rad(fov / 2.0)))
	var d := free.get_center() - r2.get_center()
	cam.h_offset = -d.x / px_per_unit
	cam.v_offset = d.y / px_per_unit
	zoom = 1.0
	view_changed.emit()


## The board's outline on a `view`-sized screen (all top corners and the base of the outer walls),
## without camera offsets. Computed from the camera transform, so it works before the first frame.
func board_screen_rect(view: Vector2) -> Rect2:
	var r := Rect2()
	var first := true
	for x in [0.0, float(map.w)]:
		for z in [0.0, float(map.d)]:
			for y in [-BASE, 4.0 * LEVEL]:
				var p := project(Vector3(x, y, z), view)
				r = Rect2(p, Vector2.ZERO) if first else r.expand(p)
				first = false
	return r


## Where a world point lands on a `view`-sized screen (perspective, fov is vertical; offsets ignored).
func project(p: Vector3, view: Vector2) -> Vector2:
	var q := cam.transform.affine_inverse() * p  # board space (the camera is the board's child)
	var f := view.y / 2.0 / tan(deg_to_rad(fov / 2.0))
	return view / 2.0 + Vector2(q.x, -q.y) / maxf(-q.z, 0.01) * f


func _place_camera() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	var dist := distance * zoom
	cam.transform = Transform3D(basis, target + basis * Vector3(0, 0, dist))
	var attrs := cam.attributes as CameraAttributesPractical
	attrs.dof_blur_near_distance = dist * 0.55
	attrs.dof_blur_near_transition = dist * 0.3
	attrs.dof_blur_far_distance = dist * 1.25
	attrs.dof_blur_far_transition = dist * 0.9
	_place_shafts()
	var k := unit_stretch()
	for u in uprights:
		if is_instance_valid(u):
			u.fit(k)
	view_changed.emit()


## Upright sprites seen from above are squashed by cos(pitch) (0.64 at 50 degrees), which makes them
## look short and wide like a card lying back. Stretching them by 1 / cos(pitch) on Y gives back the
## drawn proportions on screen while the sprite stays vertical (and keeps its feet on the block).
func unit_stretch() -> float:
	return 1.0 / maxf(cos(deg_to_rad(absf(pitch))), 0.3)


## Quarter-turns the view (the camera orbits the board; nothing is rebuilt).
func rotate_view(steps: int) -> void:
	rot = posmod(rot + steps, 4)
	yaw = 45.0 - 90.0 * rot
	_place_camera()


## Moves the camera closer (f < 1) or farther (f > 1), within limits.
func zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.35, 1.6)
	_place_camera()


## Pans the camera so `p` (world) is at the view's center target.
func look_at_point(p: Vector3) -> void:
	target = Vector3(p.x, target.y, p.z)
	_place_camera()


## Pans by a screen drag of `d` pixels (the board follows the finger).
func pan_screen(d: Vector2, view: Vector2) -> void:
	var px_per_unit := view.y / (2.0 * distance * zoom * tan(deg_to_rad(fov / 2.0)))
	var right := cam.global_transform.basis.x
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	right.y = 0.0
	right = right.normalized()
	var up_scale := 1.0 / maxf(sin(deg_to_rad(absf(pitch))), 0.3)  # screen-up drags cover more ground
	target -= right * d.x / px_per_unit
	target += fwd * d.y / px_per_unit * up_scale
	_place_camera()


## Registers a billboard (anything with `fit(k)`) to be stretched against the camera pitch.
func add_upright(n: Node3D) -> void:
	uprights.append(n)
	n.fit(unit_stretch())


## Screen direction of a board direction at a cell under the current camera (for sprite facing:
## y < 0 = away from the viewer, x > 0 = to the right).
func screen_dir(dir: Vector2i, at := Vector2i.ZERO) -> Vector2:
	var p := top_point(at.x, at.y) if in_bounds(at) else Vector3(at.x + .5, 0, at.y + .5)
	var a := cam.unproject_position(p)
	var b := cam.unproject_position(p + Vector3(dir.x, 0, dir.y))
	return (b - a).normalized()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map.w and c.y < map.d


## The cell under a screen point, or Vector2i(-1, -1): the nearest tile top or wall face the camera ray
## hits, so you always get the tile you see (a wall counts for the tile it belongs to).
func pick(screen_pos: Vector2) -> Vector2i:
	var o := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var best := Vector2i(-1, -1)
	var best_t := INF
	for y in map.d:
		for x in map.w:
			if map.tiles[y][x].t == "v":
				continue
			var h := _h(x, y) * LEVEL
			# top
			if absf(dir.y) > 1e-5:
				var t := (h - o.y) / dir.y
				if t > 0.0 and t < best_t:
					var q := o + dir * t
					if q.x >= x and q.x <= x + 1 and q.z >= y and q.z <= y + 1:
						best_t = t
						best = Vector2i(x, y)
			# the two walls facing the default camera side and their opposites
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var bottom := -BASE
				var n: Vector2i = Vector2i(x, y) + d
				if in_bounds(n) and map.tiles[n.y][n.x].t != "v":
					bottom = _h(n.x, n.y) * LEVEL
				if bottom >= h:
					continue
				var t := INF
				if d.x != 0 and absf(dir.x) > 1e-5:
					t = ((x + (1 if d.x > 0 else 0)) - o.x) / dir.x
				elif d.y != 0 and absf(dir.z) > 1e-5:
					t = ((y + (1 if d.y > 0 else 0)) - o.z) / dir.z
				if t > 0.0 and t < best_t:
					var q := o + dir * t
					var along: float = q.z - y if d.x != 0 else q.x - x
					if along >= 0.0 and along <= 1.0 and q.y <= h and q.y >= bottom:
						best_t = t
						best = Vector2i(x, y)
	return best


## Trees on "t" tiles: upright billboards like the units, with a shadow-only trunk and crown.
func _build_trees() -> void:
	for y in map.d:
		for x in map.w:
			var L: Dictionary = Terrain.LOOK.get(map.tiles[y][x].t, {})
			if not L.get("tree"):
				continue
			var tree := TreeView3D.new()
			tree.position = top_point(x, y) + Vector3((Terrain.hash01(x, y, 5) - .5) * .12, 0, 0)
			tree.setup(.62 + Terrain.hash01(x, y, 6) * .12, Terrain.hash01(x, y, 7) > .5)
			add_child(tree)
			add_upright(tree)


## An upright billboard unit standing on the top of cell (x, y) (screenshots and checks; the battle
## screen makes its own views).
func add_unit(ch: String, x: int, y: int, face_right := true, anim := "idle") -> UnitView3D:
	var u := UnitView3D.new()
	u.position = top_point(x, y)
	add_child(u)
	u.setup(ch)
	u.face(Vector2(1 if face_right else -1, 1))
	u.play(anim)
	add_upright(u)
	units.append(u)
	return u
