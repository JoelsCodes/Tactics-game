class_name Diorama3D
extends Node3D
## PROTOTYPE (side by side with the 2D game, nothing else uses it): a true 3D diorama board built from a
## sample map with the existing tile art. Every tile is a column of real geometry (top quad plus the
## exposed side walls down to the lower neighbour), lit by a directional sun with real shadows and warm
## omni fills, with SSAO, glow and color grading from a WorldEnvironment, a tilted perspective camera
## (long lens, ~50 degrees) with depth-of-field blur for the miniature look, and units as upright
## billboard sprites (`AnimatedSprite3D`, fixed to the Y axis) that stand on the tops and cast shadows.
## Needs the Forward+ (or Mobile) renderer: SSAO, DoF and soft shadows do not exist in Compatibility.
## See README "3D diorama prototype". Grid x runs to the screen's lower right, grid y to its lower left.

const PX_PER_UNIT := 45.25  ## 2D pixels per world unit (a tile is 64x32 px on screen = 1 unit square)
const LEVEL := 0.42  ## height of one level in world units
const BASE := 1.2  ## how far the board's outer walls reach below level 0 (units)
const SIDE_TEXELS := 3.0 * PX_PER_UNIT  ## side texture pixels per world unit (as in 2D: SIDE_PX 3)
const UNIT_SCALE := 1.45  ## sprite size against the blocks (1 = the 2D game's ratio)
const TEX := 96.0  ## ground texture pixels per tile (as in 2D)

var map: Dictionary
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var yaw := 45.0
var pitch := -50.0
var fov := 28.0
var distance := 0.0
var target := Vector3.ZERO
var units: Array[AnimatedSprite3D] = []
var _tex := {}  ## path -> Texture2D


func setup(m: Dictionary, p_pitch := -50.0, p_fov := 28.0, p_yaw := 45.0) -> void:
	map = m
	pitch = p_pitch
	fov = p_fov
	yaw = p_yaw
	_build_terrain()
	_build_light()
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
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(.05, .09, .22)
	sky_mat.sky_horizon_color = Color(.55, .42, .38)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(.52, .38, .34)  # the camera looks down, so the backdrop is the "ground" half
	sky_mat.ground_bottom_color = Color(.03, .05, .13)
	sky_mat.ground_curve = 0.35
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.2
	var sky := Sky.new()
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
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.3
	env.ssao_power = 1.2
	env.ssao_detail = 0.6
	env.ssil_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.12
	we.environment = env
	add_child(we)


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


func _place_camera() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	cam.global_transform = Transform3D(basis, target + basis * Vector3(0, 0, distance))
	var attrs := cam.attributes as CameraAttributesPractical
	attrs.dof_blur_near_distance = distance * 0.55
	attrs.dof_blur_near_transition = distance * 0.3
	attrs.dof_blur_far_distance = distance * 1.25
	attrs.dof_blur_far_transition = distance * 0.9
	for u in units:
		_fit_unit(u)


## Upright sprites seen from above are squashed by cos(pitch) (0.64 at 50 degrees), which makes them
## look short and wide like a card lying back. Stretching them by 1 / cos(pitch) on Y gives back the
## drawn proportions on screen while the sprite stays vertical (and keeps its feet on the block).
func unit_stretch() -> float:
	return 1.0 / maxf(cos(deg_to_rad(absf(pitch))), 0.3)


func _fit_unit(u: AnimatedSprite3D) -> void:
	var k := unit_stretch()
	u.scale = Vector3(1, k, 1)
	var body := u.get_node_or_null("ShadowBody") as Node3D
	if body:
		body.scale = Vector3(1, 1.0 / k, 1)  # the shadow body keeps its real height
		body.position = Vector3(0, 0.65 / k, 0)


func rotate_view(deg: float) -> void:
	yaw += deg
	_place_camera()


## An upright billboard unit standing on the top of cell (x, y).
func add_unit(ch: String, x: int, y: int, face_right := true, anim := "idle_f") -> AnimatedSprite3D:
	var meta := Character.meta(ch)
	var s := AnimatedSprite3D.new()
	s.sprite_frames = load("res://assets/characters/%s.tres" % ch)
	s.pixel_size = Character.SPRITE_SCALE * UNIT_SCALE / PX_PER_UNIT
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # crisp pixels: no mipmaps, no blending
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.offset = Vector2(0, meta.anchor[1] - meta.size[1] / 2.0)  # feet on the origin
	s.flip_h = face_right
	s.shaded = false  # a camera-facing quad lit by the sun from the side reads as a dark cutout; light it evenly
	s.modulate = Color(1.0, .96, .9)  # and warm it to sit in the sunlight
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = top_point(x, y)
	add_child(s)
	# a flat billboard casts only a hairline shadow, so an invisible capsule (shadows only) stands in for the body
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 1.25
	body.name = "ShadowBody"
	body.mesh = cap
	body.position = Vector3(0, 0.65, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	s.add_child(body)
	s.play(anim)
	units.append(s)
	_fit_unit(s)
	return s
