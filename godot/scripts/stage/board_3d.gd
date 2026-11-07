class_name Board3D
extends Node3D
## The battlefield as a 3D diorama, built from a map (Terrain.parse format) with the tile art: every tile
## is a column of real geometry (top quad plus the exposed side walls down to the lower neighbour), lit
## by a warm directional sun with soft real-time shadows and two soft omni fills, with a sky gradient,
## light fog, SSAO, glow and grading from a WorldEnvironment, and a tilted perspective camera (long lens,
## about 50 degrees) with depth-of-field blur for the miniature look. Units (`UnitView3D`) and trees are
## upright billboards standing on the tops.
## Needs the Forward+ (or Mobile) renderer: SSAO, DoF and soft shadows do not exist in Compatibility.
## The view is always square-on, never diagonal: at rotation 0 grid x runs to the screen's right and grid y toward
## the viewer; the camera starts one quarter-turn to the right of that (rotation 1).
## See README "3D board".

signal view_changed  ## the camera moved or turned

const PX_PER_UNIT := 45.25  ## 2D pixels per world unit (a tile is 64x32 px on screen = 1 unit square)
const LEVEL := 0.42  ## height of one level in world units
const BASE := 2.6  ## how far the board's outer walls reach below level 0 (units): the cutaway shows about 2.5 tiles of depth
## The cutaway cross-section along the board's outer rim, from the ground line down: [from, to, brightness]. The rock gets
## darker with depth.
const CUT_BANDS := [[0.0, -1.0, 0.86], [-1.0, -1.9, 0.64], [-1.9, -BASE, 0.46]]
## What each band shows, by the tile's side texture: soil (outdoor ground), masonry (the castle's floors and walls) or bedrock.
const CUT_SOIL := ["dirtblk", "dirtblk", "crag"]
const CUT_MASONRY := ["castlewall", "castlewall", "crag"]
const CUT_ROCK := ["stoneblk", "crag", "crag"]
const CUTAWAY := {"castlewall": CUT_MASONRY, "castlesoil": CUT_MASONRY, "stoneblk": CUT_ROCK, "crag": CUT_ROCK, "cinder": CUT_ROCK,
	"island": CUT_ROCK, "marble": CUT_ROCK, "lava": CUT_ROCK, "ash": CUT_ROCK, "ash2": CUT_ROCK, "skyrock": CUT_ROCK, "skymarble": CUT_ROCK}
const SIDE_TEXELS := 3.0 * PX_PER_UNIT  ## side texture pixels per world unit (as in 2D: SIDE_PX 3)
const UNIT_SCALE := 1.45  ## sprite size against the blocks (1 = the 2D game's ratio)
const TEX := 96.0
const DEFAULT_GRADE := "natural"  ## true colors, dramatic contrast (maps may ask for "sepia" or "golden")
const DEFAULT_HAZE := "light"  ## maps may ask for "heavy"
const DEFAULT_BACKDROP := "radial"  ## "radial" (twilight glow behind the board), "radial_black" (lighter black to darker black) or "sky" (the procedural sky gradient)
const DEFAULT_GOD_RAYS := false  ## light shafts off unless a map asks for them
const OUTSIDE_MARGIN := 3  ## tiles the outside castle runs past the farthest ground the view reaches
const OUTSIDE_ASPECT := 2.4  ## the widest screen the outside castle is built for (21:9); narrower ones see less
## The owner's rules: the camera is static. It keeps one lens (28 degrees: the 3D look), one angle (pitch -50) and
## one distance on every map and screen, intro and battle alike, and never pans or zooms (closer or farther and the
## upright sprites look paper thin). The distance is the one that fits the whole battlefield between the HUD bands,
## since the view never moves to show the rest; a map must fit in it. The Rotate view button still turns the camera
## in quarter steps around the board's centre, at the same angle and distance.
const CAMERA_FOV := 28.0
const CAMERA_DISTANCE := 36.0

var map: Dictionary
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var dust: GPUParticles3D
var sky: Sky
var shafts: Array[MeshInstance3D] = []  ## god-ray quads (see set_god_rays)
var mist: MeshInstance3D
var yaw := -90.0  ## the camera starts a quarter-turn to the right of facing the board square-on (rot 1)
var pitch := -50.0
var fov := CAMERA_FOV
var distance := 0.0
var target := Vector3.ZERO
var rot := 1  ## view rotation in quarter turns (0..3); the camera orbits, the board never changes
var uprights: Array[Node3D] = []  ## billboards stretched against the camera pitch (`fit(k)`)
var units: Array[UnitView3D] = []  ## only for add_unit (screenshots and checks)
var life: BoardLife  ## the map's decoration and weather (map.life, map.ambient)
var props: Array[PropView3D] = []  ## the map's props (map.props)
var outside_castle := false  ## build a castle around the map out to the edges of the view (see _build_outside_castle)
var _tex := {}  ## path -> Texture2D
var _fitted := {}  ## upright node -> the (stretch, size) it was last given (re-fitted only when it changes)
## Whether unit sprites are turned back upright on screen (see upright_orient); tests switch it off to compare.
var lean_correction := true
var _fit_inputs := {}  ## upright node -> (world position, pixel size); skip unchanged projection work
var _fit_camera_transform := Transform3D.IDENTITY
var _fit_viewport_size := Vector2.ZERO


func setup(m: Dictionary, p_pitch := -50.0, p_fov := CAMERA_FOV, p_yaw := -90.0) -> void:
	map = m
	pitch = p_pitch
	fov = p_fov
	yaw = p_yaw
	_build_terrain()
	_build_overhangs()
	_build_trees()
	_build_props()
	_build_life()
	_build_light()
	_build_atmosphere()
	set_grade(String(map.get("grade", DEFAULT_GRADE)))
	set_haze(String(map.get("haze", DEFAULT_HAZE)))
	_build_shafts()
	set_backdrop(String(map.get("backdrop", DEFAULT_BACKDROP)))
	set_god_rays(bool(map.get("god_rays", DEFAULT_GOD_RAYS)))
	_build_camera()


const COLUMN_SHADER := preload("res://shaders/light_column.gdshader")
const COLUMN_HEIGHT := 3.4
const COLUMN_DAMAGE := Color(0.55, 0.8, 1.0)
const COLUMN_HEAL := Color(0.55, 1.0, 0.65)


var _columns := {}  ## Vector2i -> MeshInstance3D: the light columns shown now


## Columns of light over the tiles an aimed attack or skill would hit (owner's reference, Nov 2026), on top of the area highlight
## (TileHighlights shows them with Kind.AREA, before the player confirms). New tiles rise and brighten; tiles no longer in the area
## fade out; an empty list clears them.
func show_columns(cells: Array, tint := COLUMN_DAMAGE) -> void:
	var want := {}
	for c in cells:
		if in_bounds(c):
			want[c] = true
	for c in _columns.keys():
		if not want.has(c):
			var old: MeshInstance3D = _columns[c]
			_columns.erase(c)
			var m0: ShaderMaterial = old.material_override
			var tw0 := old.create_tween()
			tw0.tween_method(func(a): m0.set_shader_parameter("alpha", a), float(m0.get_shader_parameter("alpha")), 0.0, 0.15)
			tw0.tween_callback(old.queue_free)
	for c in want:
		if _columns.has(c):
			(_columns[c].material_override as ShaderMaterial).set_shader_parameter("tint", tint)
			continue
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.92, COLUMN_HEIGHT, 0.92)
		var m := ShaderMaterial.new()
		m.shader = COLUMN_SHADER
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("height", COLUMN_HEIGHT)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = top_point(c.x, c.y) + Vector3(0, COLUMN_HEIGHT * 0.5, 0)
		mi.scale = Vector3(1, 0.05, 1)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(a): m.set_shader_parameter("alpha", a), 0.0, 1.0, 0.18)
		_columns[c] = mi


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
	m.vertex_color_use_as_albedo = true  # weathered walls colour their vertices (moss, soot, streaks); everything else stays white
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
			var rough := _is_rough(x, y)
			if rough:  # a weathered wall or cliff top: the corners wander a little, the same way for every tile that shares them
				var c00 := _rough_pt(Vector3(x, h, y))
				var c10 := _rough_pt(Vector3(x + 1, h, y))
				var c11 := _rough_pt(Vector3(x + 1, h, y + 1))
				var c01 := _rough_pt(Vector3(x, h, y + 1))
				_quad(st, c00, c10, c11, c01, Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y), Vector3.UP,
					[_rock_col(c00), _rock_col(c10), _rock_col(c11), _rock_col(c01)])
			else:
				_quad(st, Vector3(x, h, y), Vector3(x + 1, h, y), Vector3(x + 1, h, y + 1), Vector3(x, h, y + 1),
					Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y), Vector3.UP)
			# walls: the 2D art has a lit left strip and a pre-darkened right strip; here the sun does the
			# shading, so every face uses the lit (left) strip
			var side_l := "res://assets/tiles/side_%s_l.png" % L.side
			var side_size := Vector2.ZERO
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				var bottom := -BASE
				var rim := true  ## the board's outer edge (or an opening): a cutaway cross-section
				if nx >= 0 and ny >= 0 and nx < map.w and ny < map.d and map.tiles[ny][nx].t != "v":
					bottom = _h(nx, ny) * LEVEL
					rim = false
				if bottom >= h - 0.001:
					continue
				if rim:
					_cutaway(batches, x, y, d, h, L, tint)
					continue
				if side_size == Vector2.ZERO:
					side_size = _load(side_l).get_size()
				var sst := _surface(batches, side_l, tint)
				if rough:
					_rough_wall(sst, x, y, d, h, bottom, L.v0, side_size)
				else:
					_wall(sst, x, y, d, h, bottom, L.v0, side_size)
	if outside_castle:
		_build_outside_castle(batches)
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


## The castle around the map (OutsideCastle), built out to the farthest ground the view reaches, so the map reads as
## one part of something bigger (OutsideBlur blurs everything outside it). These tiles are scenery only: they are
## not in map.tiles, so the grid, the cells and the scenes' steps are the same as without them.
func _build_outside_castle(batches: Dictionary) -> void:
	var reach := int(ceil(_outside_reach())) + OUTSIDE_MARGIN
	var c := Vector2i(int(map.w / 2.0), int(map.d / 2.0))
	var dark_rows: Array[int] = []  # the rows where the map's far wall has a door onto the dark
	for y in map.d:
		if map.tiles[y][map.w - 1].t == "v":
			dark_rows.append(y)
	var oc := OutsideCastle.new(map.w, map.d, c - Vector2i(reach + 14, reach + 14), c + Vector2i(reach + 14, reach + 14), dark_rows)
	for y in range(c.y - reach, c.y + reach + 1):
		for x in range(c.x - reach, c.x + reach + 1):
			if x >= 0 and y >= 0 and x < map.w and y < map.d:
				continue
			var t := oc.cell(x, y)
			if t.t != "v":
				_add_outside_tile(batches, oc, x, y, t)


## One outside tile: its top and the walls down to each lower neighbour (the map's tiles count as neighbours).
func _add_outside_tile(batches: Dictionary, oc: OutsideCastle, x: int, y: int, t: Dictionary) -> void:
	var L: Dictionary = Terrain.LOOK[t.t]
	var h: float = float(t.h) * LEVEL
	var tint: Color = L.get("tint", Color.WHITE)
	var n: int = maxi(int(L.n), 1)
	var top_path := "res://assets/tiles/%s_%02d.png" % [L.top, int(Terrain.hash01(x, y) * n) % n]
	_quad(_surface(batches, top_path, tint), Vector3(x, h, y), Vector3(x + 1, h, y), Vector3(x + 1, h, y + 1), Vector3(x, h, y + 1),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector3.UP)
	var side := "res://assets/tiles/side_%s_l.png" % L.side
	for dir in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var bottom := -BASE
		var nh: Variant = _outside_height(oc, x + dir.x, y + dir.y)
		if nh != null:
			bottom = float(nh) * LEVEL
		if bottom >= h - 0.001:
			continue
		_wall(_surface(batches, side, tint), x, y, dir, h, bottom, L.v0, _load(side).get_size())


## The height (in levels) of the tile at (x, y), the map's or the castle's; null where there is none (void).
func _outside_height(oc: OutsideCastle, x: int, y: int) -> Variant:
	if x >= 0 and y >= 0 and x < map.w and y < map.d:
		return null if map.tiles[y][x].t == "v" else _h(x, y)
	var t := oc.cell(x, y)
	return null if t.t == "v" else float(t.h)


## How far from the board's centre the view reaches on the ground, in tiles, for every quarter-turn and the widest
## screen (OUTSIDE_ASPECT): the rays through the view's corners, cut with the ground.
func _outside_reach() -> float:
	var reach := 0.0
	var centre := Vector3(map.w / 2.0, 0.6, map.d / 2.0)
	var half := tan(deg_to_rad(fov / 2.0))
	for q in 4:
		var b := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(-90.0 * q), 0))
		var eye := centre + b * Vector3(0, 0, CAMERA_DISTANCE)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var dir := b * Vector3(sx * half * OUTSIDE_ASPECT, sy * half, -1.0)
				if dir.y >= 0.0:
					continue
				var hit := eye + dir * (-eye.y / dir.y)
				reach = maxf(reach, maxf(absf(hit.x - centre.x), absf(hit.z - centre.z)))
	return reach


## The top of the tallest tile, in world units.
func max_height() -> float:
	var m := 0.0
	for y in map.d:
		for x in map.w:
			m = maxf(m, _h(x, y) * LEVEL)
	return m


func _surface(batches: Dictionary, path: String, tint: Color) -> SurfaceTool:
	var key := "%s|%s" % [path, tint.to_html()]
	if not batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key] = [st, _mat(path, tint)]
	return batches[key][0]


## Like _surface, for the cutaway rim: the diorama-edge shader sinks the texture into the dark void with depth and breaks the
## bottom edge into a ragged line (shaders/diorama_edge.gdshader).
func _rim_surface(batches: Dictionary, path: String, tint: Color) -> SurfaceTool:
	var key := "rim|%s|%s" % [path, tint.to_html()]
	if not batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/diorama_edge.gdshader")
		m.set_shader_parameter("albedo_tex", _load(path))
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("fade_bottom", -BASE)
		batches[key] = [st, m]
	return batches[key][0]


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, n: Vector3, cols: Array = []) -> void:
	var tris := [[a, ua, 0], [b, ub, 1], [c, uc, 2], [a, ua, 0], [c, uc, 2], [d, ud, 3]]
	if (b - a).cross(c - a).dot(n) > 0.0:  # Godot's front face is clockwise; wind it so the normal faces out
		tris = [[a, ua, 0], [c, uc, 2], [b, ub, 1], [a, ua, 0], [d, ud, 3], [c, uc, 2]]
	for v in tris:
		st.set_normal(n)
		st.set_color(cols[v[2]] if not cols.is_empty() else Color.WHITE)  # every vertex of a surface carries a colour (SurfaceTool refuses a mix)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## The outer rim of the board as a cutaway cross-section: the tile's own side down to the ground line, then bands of soil,
## masonry or bedrock (CUT_BANDS) down to -BASE, darker the deeper they go.
func _cutaway(batches: Dictionary, x: int, y: int, d: Vector2i, h: float, L: Dictionary, tint: Color) -> void:
	if h > 0.001:
		var side := "res://assets/tiles/side_%s_l.png" % L.side
		_wall(_surface(batches, side, tint), x, y, d, h, 0.0, L.v0, _load(side).get_size())
	var layers: Array = CUTAWAY.get(L.side, CUT_SOIL)
	for i in CUT_BANDS.size():
		var band: Array = CUT_BANDS[i]
		var path := "res://assets/tiles/side_%s_l.png" % layers[i]
		var shade: float = band[2]
		var c := Color(tint.r * shade, tint.g * shade, tint.b * shade, tint.a)
		_rim_wall(_rim_surface(batches, path, c), x, y, d, minf(band[0], h), band[1], _load(path).get_size())


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


## Weathered walls (owner, Nov 2026: "terrain that happened, not that was just placed there"). A map with "rough_walls": true has its wall and cliff tiles
## ("q" brick, "r" crag) three or more levels high built with wandering corners, a broken, lumpy face split into facets, stained and mossy vertex colours and a
## texture that no longer repeats in a lattice. Every offset is a function of the world position alone, so tiles that share a corner or an edge still meet.
const ROUGH_TILES := ["q", "r"]
const ROUGH_FROM := 3  ## levels: lower slabs and pavements stay crisp
const ROUGH_AMP := 0.12  ## how far a corner wanders (world units)
const ROUGH_BULGE := 0.1  ## how far the middle of a face bulges or caves in
var _rough_noise: FastNoiseLite


func _is_rough(x: int, y: int) -> bool:
	if not map.get("rough_walls", false):
		return false
	var t: Dictionary = map.tiles[y][x]
	return t.t in ROUGH_TILES and t.h >= ROUGH_FROM


func _rn(x: float, y: float, z: float, seed_off := 0.0) -> float:
	if _rough_noise == null:
		_rough_noise = FastNoiseLite.new()
		_rough_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_rough_noise.frequency = 1.0
		_rough_noise.seed = 311 + map.w * 17 + map.d
	return _rough_noise.get_noise_3d(x * 1.9 + seed_off, y * 1.5, z * 1.9 - seed_off)


## A point of a rough wall moved sideways by noise (more the higher it is, none at the ground), identically wherever it is asked for.
func _rough_pt(p: Vector3) -> Vector3:
	var amp := ROUGH_AMP * smoothstep(0.05, 0.9, p.y)
	return p + Vector3(_rn(p.x, p.y, p.z) * amp * 2.0, _rn(p.x * 0.8, p.y, p.z * 0.8, 113.0) * 0.1 * smoothstep(1.0, 1.8, p.y), _rn(p.x, p.y, p.z, 57.0) * amp * 2.0)  # the tops are uneven too


## Stone colour at a point: lighter and drier up high, darker and greener near the foot, streaked by noise.
func _rock_col(p: Vector3) -> Color:
	var streak := 0.9 + 0.14 * _rn(p.x * 2.2, p.y * 0.8, p.z * 2.2, 13.0)
	var low := 1.0 - smoothstep(0.0, 1.1, p.y)
	var c := Color(streak, streak, streak)
	c = c.lerp(Color(0.72, 0.84, 0.62), low * 0.45 * (0.5 + 0.5 * _rn(p.x * 3.0, 0.0, p.z * 3.0, 29.0)))  # moss at the foot
	return c * (1.0 - 0.18 * low)


func _rough_wall(st: SurfaceTool, x: int, y: int, d: Vector2i, top: float, bottom: float, v0: float, tex_size: Vector2) -> void:
	var a: Vector3
	var b: Vector3
	var n := Vector3(d.x, 0, d.y)
	if d.y != 0:
		var z := y + (1 if d.y > 0 else 0)
		a = Vector3(x, 0, z)
		b = Vector3(x + 1, 0, z)
	else:
		var xx := x + (1 if d.x > 0 else 0)
		a = Vector3(xx, 0, y)
		b = Vector3(xx, 0, y + 1)
	var seg := float(int(Terrain.hash01(x, y, 5) * 4.0))  # which quarter of the strip: by tile, not by position, so the pattern does not repeat
	var u0 := seg * TEX / tex_size.x
	var u1 := (seg + 1) * TEX / tex_size.x
	var vshift := Terrain.hash01(x, y, 8) * 40.0
	var cols := 4
	var rows := maxi(2, int(ceil((top - bottom) / 0.28)))
	var pts := []
	var uvs := []
	var colors := []
	for j in rows + 1:
		var fv := float(j) / rows
		var yy := lerpf(top, bottom, fv)
		var prow := []
		var urow := []
		var crow := []
		for i in cols + 1:
			var fu := float(i) / cols
			var p := a.lerp(b, fu)
			p.y = yy
			var q := _rough_pt(p)
			# the face bulges and caves in between the tile's corners and rows (never at the corners, the top edge or the foot, where it meets its neighbours)
			var pin := sin(fu * PI) * smoothstep(0.0, 0.3, fv) * smoothstep(0.0, 0.3, 1.0 - fv)
			q += n * (_rn(p.x * 2.3, yy * 1.6, p.z * 2.3, 91.0) * ROUGH_BULGE * 2.0 * pin)
			prow.append(q)
			urow.append(Vector2(lerpf(u0, u1, fu), (v0 + vshift + (top - yy) * SIDE_TEXELS) / tex_size.y))
			crow.append(_rock_col(Vector3(p.x, yy, p.z)))
		pts.append(prow)
		uvs.append(urow)
		colors.append(crow)
	for j in rows:
		for i in cols:
			var p0: Vector3 = pts[j][i]
			var p1: Vector3 = pts[j][i + 1]
			var p2: Vector3 = pts[j + 1][i + 1]
			var p3: Vector3 = pts[j + 1][i]
			var fn := (p1 - p0).cross(p3 - p0).normalized()
			if fn.dot(n) < 0.0:
				fn = -fn
			_quad(st, p0, p1, p2, p3, uvs[j][i], uvs[j][i + 1], uvs[j + 1][i + 1], uvs[j + 1][i], fn, [colors[j][i], colors[j][i + 1], colors[j + 1][i + 1], colors[j + 1][i]])


## The rim's shape (the cliff profile). One warp of a world point, the same wherever it is used (so the walls of neighbouring
## tiles, the corners and everything hung on them meet): from the ground line (y = 0, pinned) down, the board tapers in toward its
## middle (RIM_TAPER at the bottom) and the points are pushed about by two scales of noise, more the deeper they are.
const RIM_TAPER := 0.075
var _rim_noise: FastNoiseLite


func _rim_warp(p: Vector3) -> Vector3:
	if p.y >= -0.001:
		return p
	if _rim_noise == null:
		_rim_noise = FastNoiseLite.new()
		_rim_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_rim_noise.frequency = 1.0
		_rim_noise.seed = 7 + map.w * 31 + map.d
	var dep := clampf(-p.y / BASE, 0.0, 1.0)
	var amp := smoothstep(0.0, 0.3, dep)
	var c := Vector2(map.w / 2.0, map.d / 2.0)
	var q := c + (Vector2(p.x, p.z) - c) * (1.0 - RIM_TAPER * dep * dep)
	var a := Vector3(p.x, p.y * 1.3, p.z)
	var nz := func(o: float, f: float) -> float: return _rim_noise.get_noise_3d(a.x * f + o, a.y * f * 1.4, a.z * f + o * 0.5)
	var dx: float = nz.call(0.0, 0.55) * 0.26 + nz.call(31.0, 1.9) * 0.09
	var dz: float = nz.call(57.0, 0.55) * 0.26 + nz.call(83.0, 1.9) * 0.09
	var dy: float = nz.call(111.0, 0.8) * 0.14
	return Vector3(q.x + dx * amp, p.y + dy * amp, q.y + dz * amp)


## One rim wall quad on the face of tile (x, y) toward `d`, from height `top` down to `bottom`, cut into a grid of small cells whose
## corners go through _rim_warp, with normals worked out from the warped surface, so the cliff is lumpy and tapering rather than flat.
func _rim_wall(st: SurfaceTool, x: int, y: int, d: Vector2i, top: float, bottom: float, tex_size: Vector2) -> void:
	var a: Vector3
	var b: Vector3
	var n := Vector3(d.x, 0, d.y)
	var seg: float
	if d.y != 0:
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
	var vb := (top - bottom) * SIDE_TEXELS / tex_size.y
	var cols := 4
	var rows := maxi(2, int(ceil((top - bottom) / 0.3)))
	var P := []
	for j in rows + 1:
		var row := []
		for i in cols + 1:
			var pos := a.lerp(b, float(i) / cols)
			pos.y = lerpf(top, bottom, float(j) / rows)
			row.append(_rim_warp(pos))
		P.append(row)
	var N := []
	for j in rows + 1:
		var row := []
		for i in cols + 1:
			var du: Vector3 = P[j][mini(i + 1, cols)] - P[j][maxi(i - 1, 0)]
			var dv: Vector3 = P[mini(j + 1, rows)][i] - P[maxi(j - 1, 0)][i]
			var nn := du.cross(dv).normalized()
			if nn.dot(n) < 0.0:
				nn = -nn
			row.append(nn)
		N.append(row)
	for j in rows:
		for i in cols:
			for c in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var ii: int = i + c[0]
				var jj: int = j + c[1]
				st.set_normal(N[jj][ii])
				st.set_uv(Vector2(lerpf(u0, u1, float(ii) / cols), vb * float(jj) / rows))
				st.add_vertex(P[jj][ii])


## Moves a point hung on the rim by the same amount _rim_warp moves the rim at its anchor, so it stays on the cliff.
func _rim_follow(anchor: Vector3, p: Vector3) -> Vector3:
	return p + (_rim_warp(anchor) - anchor)


## Hanging roots, ivy, boulders and jagged rock spikes along the board's outer rim, and a ragged lip of grass or rubble over its top
## edge, to break the straight lines of the cutaway. Scenery only (no collision, no shadows), placed from a hash of the tile, so a
## map always looks the same.
func _build_overhangs() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	var count := 0
	for y in map.d:
		for x in map.w:
			if map.tiles[y][x].t == "v":
				continue
			var L: Dictionary = Terrain.LOOK.get(map.tiles[y][x].t, Terrain.LOOK.g)
			for di in 4:
				var d: Vector2i = dirs[di]
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < map.w and ny < map.d and map.tiles[ny][nx].t != "v":
					continue
				_overhang_face(st, x, y, d, x * 4 + di, _h(x, y) * LEVEL, "gras" in String(L.top))
				count += 1
	if count == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Overhangs"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)


func _overhang_face(st: SurfaceTool, x: int, y: int, d: Vector2i, key: int, top_h: float, grassy: bool) -> void:
	var n := Vector3(d.x, 0, d.y)
	var o: Vector3
	var t: Vector3
	if d.y != 0:
		o = Vector3(x, 0, y + (1 if d.y > 0 else 0))
		t = Vector3(1, 0, 0)
	else:
		o = Vector3(x + (1 if d.x > 0 else 0), 0, y)
		t = Vector3(0, 0, 1)
	var h := func(k: int) -> float: return Terrain.hash01(key, y, k)
	# a ragged lip over the top edge: grass blades (or rubble) that spill over the sharp boundary
	for i in 7:
		var s: float = (i + 0.2 + 0.6 * h.call(130 + i)) / 7.0
		var w: float = 0.05 + 0.05 * h.call(140 + i)
		var reach: float = 0.1 + 0.16 * h.call(150 + i)
		var drop: float = 0.14 + 0.2 * h.call(160 + i)
		var base := o + t * s + Vector3(0, top_h, 0)
		var c1 := Color(0.22, 0.42, 0.09) if grassy else Color(0.3, 0.27, 0.24)
		var c2 := Color(0.12, 0.27, 0.05) if grassy else Color(0.17, 0.15, 0.14)
		var lean: float = (h.call(170 + i) - 0.5) * 0.12
		_tri(st, base - t * w + n * 0.03, base + t * w + n * 0.03, base + n * reach + t * lean + Vector3(0, -drop, 0), n + Vector3(0, 0.6, 0), c1, c1, c2)
	# roots and ivy hang from the ground line
	for i in 2 + int(h.call(1) * 3.0):
		var s: float = 0.1 + 0.8 * h.call(10 + i)
		var root: bool = h.call(20 + i) < 0.5
		_ribbon(st, o + t * s - Vector3(0, 0.02, 0), n, t, 0.5 + 1.1 * h.call(30 + i), 0.085 if root else 0.06, h.call(40 + i) * 6.0,
			Color(0.3, 0.2, 0.11) if root else Color(0.16, 0.3, 0.1), Color(0.07, 0.05, 0.05), not root)
	# jagged rock spikes and protruding boulders in the lower bands
	for i in 2:
		var s: float = 0.08 + 0.84 * h.call(50 + i)
		var top: float = -0.9 - 0.6 * h.call(60 + i)
		_spike(st, o + t * s + Vector3(0, top, 0), n, t, 0.16 + 0.16 * h.call(70 + i), 0.18 + 0.28 * h.call(80 + i), 0.08 + 0.1 * h.call(90 + i), 0.07)
	for i in 1 + int(h.call(2) * 2.0):
		var s: float = 0.15 + 0.7 * h.call(100 + i)
		var yy: float = -0.35 - 1.5 * h.call(110 + i)
		_boulder(st, o + t * s + Vector3(0, yy, 0), n, t, 0.12 + 0.14 * h.call(120 + i), 0.2 + 0.1 * h.call(125 + i), key * 7 + i)


## A protruding rock chunk: a lumpy eight-sided shape half buried in the cliff, darker the deeper it sits.
func _boulder(st: SurfaceTool, p: Vector3, n: Vector3, t: Vector3, r: float, shade: float, seed: int) -> void:
	var dep := clampf(-p.y / BASE, 0.0, 1.0)
	shade *= 1.0 - 0.55 * dep
	var up := Vector3.UP
	var j := func(k: int) -> float: return 0.75 + 0.5 * Terrain.hash01(seed, k, 5)
	var pts := [t * r * j.call(0), -t * r * j.call(1), up * r * 0.8 * j.call(2), -up * r * 0.8 * j.call(3), n * r * 1.1 * j.call(4), -n * r * 0.2]
	pts = pts.map(func(v: Vector3) -> Vector3: return _rim_follow(p, p + v))
	var c := _rim_follow(p, p)
	var top := Color(shade * 1.25, shade * 1.15, shade * 1.25)
	var dark := Color(shade * 0.6, shade * 0.55, shade * 0.65)
	for e in [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [0, 2, 5], [2, 1, 5], [1, 3, 5], [3, 0, 5]]:
		var a: Vector3 = pts[e[0]]
		var b: Vector3 = pts[e[1]]
		var cc: Vector3 = pts[e[2]]
		var nn := (b - a).cross(cc - a).normalized()
		if nn.dot(a - c) < 0.0:
			nn = -nn
		var col := top if nn.y > 0.2 else dark
		_tri(st, a, b, cc, nn, col, col, col)


## A hanging strand (a thin ribbon swaying a little, wider at the top) from `p` downward; `leaves` adds ivy leaves along it.
func _ribbon(st: SurfaceTool, p: Vector3, n: Vector3, t: Vector3, length: float, width: float, seed: float, top: Color, tip: Color, leaves: bool) -> void:
	var segs := 6
	var prev_c := Vector3.ZERO
	var prev_w := 0.0
	var prev_col := top
	for i in segs + 1:
		var f := float(i) / segs
		var c := p + Vector3(0, -length * f, 0) + t * (sin(f * 3.0 + seed) * 0.07 * f) + n * (0.02 + 0.16 * f * f)
		c = _rim_follow(p + Vector3(0, -length * f, 0), c)
		var w := width * (1.0 - 0.65 * f) * 0.5
		var col := top.lerp(tip, f)
		if i > 0:
			_tri(st, prev_c - t * prev_w, prev_c + t * prev_w, c + t * w, n, prev_col, prev_col, col)
			_tri(st, prev_c - t * prev_w, c + t * w, c - t * w, n, prev_col, col, col)
			if leaves and i % 2 == 0:
				var lc := Color(0.14 + 0.1 * fposmod(seed * 3.7 + i, 1.0), 0.32 + 0.16 * fposmod(seed * 1.3 + i, 1.0), 0.1).lerp(tip, f * f)
				var sz := 0.1
				var side := 1.0 if i % 4 == 0 else -1.0
				var m := c + t * (w + sz * 0.8) * side + n * 0.03
				_tri(st, m - t * sz, m + t * sz, m + Vector3(0, sz * 1.5, 0), n, lc, lc, lc.darkened(0.25))
				_tri(st, m - t * sz, m + t * sz, m - Vector3(0, sz * 1.5, 0), n, lc, lc, lc.darkened(0.35))
		prev_c = c
		prev_w = w
		prev_col = col


## A rock spike (a three-sided wedge) hanging from `p`, leaning out from the wall by `out`.
func _spike(st: SurfaceTool, p: Vector3, n: Vector3, t: Vector3, width: float, length: float, out: float, shade: float) -> void:
	var col := Color(shade, shade * 0.92, shade * 1.05)
	var tipc := Color(shade * 0.35, shade * 0.32, shade * 0.42)
	var l := _rim_follow(p, p - t * width * 0.5 + n * 0.02)
	var r := _rim_follow(p, p + t * width * 0.5 + n * 0.02)
	var apex := _rim_follow(p, p + t * width * 0.1 + Vector3(0, -length, 0) + n * out)
	var back := _rim_follow(p, p + Vector3(0, length * 0.1, 0) - n * 0.02)
	_tri(st, l, r, apex, n, col, col, tipc)
	_tri(st, l, apex, back, -t, col, tipc, col.darkened(0.3))
	_tri(st, r, apex, back, t, col, tipc, col.darkened(0.3))


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for v in [[a, ca], [b, cb], [c, cc]]:
		st.set_normal(nrm)
		st.set_color(v[1])
		st.add_vertex(v[0])


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
	env.fog_height = -BASE  # below the cutaway rim, so the cross-section is not washed out
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
## (shaders/backdrop_radial.gdshader). "radial_black" is the same gradient in blacks: a lighter black behind the
## board to a darker black at the corners (the ruins).
func set_backdrop(name: String) -> void:
	if name == "radial" or name == "radial_black":
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/backdrop_radial.gdshader")
		if name == "radial_black":
			# the grade's contrast crushes dark greys to black, so these stops are lighter than they look on screen
			m.set_shader_parameter("center_color", Color(0.7, 0.7, 0.72))
			m.set_shader_parameter("mid_color", Color(0.51, 0.51, 0.53))
			m.set_shader_parameter("slate_color", Color(0.34, 0.34, 0.36))
			m.set_shader_parameter("corner_color", Color(0.12, 0.12, 0.13))
			m.set_shader_parameter("center", Vector2(0.5, 0.5))
			m.set_shader_parameter("glow_size", 1.15)
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
		quad.size = Vector2(sp[2] * 1.6, 16.0)  # wide and soft
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
		"slate":  # chapter three's slate-grey sky: cold, flat light, the colour drained
			sun.light_color = Color(.82, .87, .95)
			env.volumetric_fog_albedo = Color(.7, .74, .8)
			env.adjustment_contrast = 1.15
			env.adjustment_saturation = 0.78
			env.adjustment_color_correction = null
			sky_mat.ground_horizon_color = Color(.34, .36, .42)
			sky_mat.ground_bottom_color = Color(.04, .05, .09)
		"dusk":  # Riverford's evening: a cold blue light, long shadows, the colour drained a little
			sun.light_color = Color(.62, .72, 1.0)
			env.volumetric_fog_albedo = Color(.55, .62, .85)
			env.adjustment_contrast = 1.22
			env.adjustment_saturation = 0.92
			env.adjustment_color_correction = null
			sky_mat.ground_horizon_color = Color(.2, .22, .4)
			sky_mat.ground_bottom_color = Color(.02, .02, .08)
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
	dust.amount = int(220.0 * maxf(1.0, map.w * map.d / 170.0))  # the same density on a big map
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
	# mist wrapped around the foot of the board: two sheets below the ground line, wider than the board, densest at the rim
	for k in 2:
		var rm := MeshInstance3D.new()
		rm.name = "RimMist%d" % k
		var rp := PlaneMesh.new()
		rp.size = Vector2(map.w + 12.0, map.d + 12.0)
		rm.mesh = rp
		rm.position = Vector3(map.w / 2.0, -1.5 - 1.3 * k, map.d / 2.0)
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rmat := ShaderMaterial.new()
		rmat.shader = load("res://shaders/rim_mist.gdshader")
		rmat.set_shader_parameter("board_rect", Vector4(0, 0, map.w, map.d))
		rmat.set_shader_parameter("density", 0.7 - 0.2 * k)
		rmat.set_shader_parameter("drift", 1.0 + 0.6 * k)
		rm.material_override = rmat
		add_child(rm)


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


## Orbit camera around the board center at the fixed CAMERA_DISTANCE, DoF focus on the board.
func frame_board() -> void:
	distance = CAMERA_DISTANCE
	_place_camera()


## Centres the view in `free` (a rect of the viewport, e.g. between the HUD bands) at the fixed distance: the
## board's centre goes to the middle of `free`. The distance never changes.
func frame_rect(free: Rect2, view: Vector2) -> void:
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	frame_board()
	# shift the image: offsets are in world units at the target's distance
	var r2 := board_screen_rect(view)
	var px_per_unit := view.y / (2.0 * distance * tan(deg_to_rad(fov / 2.0)))
	var d := free.get_center() - r2.get_center()
	cam.h_offset = -d.x / px_per_unit
	cam.v_offset = d.y / px_per_unit
	view_changed.emit()


## Points the camera at `point` (a base too big for the screen follows the player): the same lens, angle and distance, the
## point centred in `free`. Nothing else about the view changes.
func follow(point: Vector3, free: Rect2, view: Vector2) -> void:
	target = point
	distance = CAMERA_DISTANCE
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	_place_camera()
	var px_per_unit := view.y / (2.0 * distance * tan(deg_to_rad(fov / 2.0)))
	var d := free.get_center() - view / 2.0
	cam.h_offset = -d.x / px_per_unit
	cam.v_offset = d.y / px_per_unit


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


## The camera transform for a target point (the same lens, angle and distance everywhere: only the target moves).
func _transform_for(t: Vector3) -> Transform3D:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	return Transform3D(basis, t + basis * Vector3(0, 0, CAMERA_DISTANCE))


## The board's outline on a `view`-sized screen for a camera aimed at `t` (the camera is not moved; offsets ignored).
func _rect_for(t: Vector3, view: Vector2) -> Rect2:
	var inv := _transform_for(t).affine_inverse()
	var f := view.y / 2.0 / tan(deg_to_rad(fov / 2.0))
	var r := Rect2()
	var first := true
	for x in [0.0, float(map.w)]:
		for z in [0.0, float(map.d)]:
			for y in [-BASE, 4.0 * LEVEL]:
				var q: Vector3 = inv * Vector3(x, y, z)
				var p := view / 2.0 + Vector2(q.x, -q.y) / maxf(-q.z, 0.01) * f
				r = Rect2(p, Vector2.ZERO) if first else r.expand(p)
				first = false
	return r


## A map wider than the screen scrolls along its long side (the camera aims at (middle of the depth, z)): the range of z for which the
## board still covers the whole width of `free`, so its edge never comes onto the screen. Returns (zmin, zmax), or (INF, -INF) when
## the whole board already fits the screen (it needs no scrolling). Cheap: a few dozen projections, done once per map and screen size.
func scroll_range(free: Rect2, view: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	var z := 0.0
	while z <= float(map.d):
		var r := _rect_for(Vector3(map.w / 2.0, 0.6, z), view)
		if r.position.x <= free.position.x and r.end.x >= free.end.x:
			lo = minf(lo, z)
			hi = maxf(hi, z)
		z += 0.25
	return Vector2(lo, hi)


## Aims the camera at z along the long side of the board and frames it in `free` the way the static camera does (the same height on
## screen), with the same lens, angle and distance. `z` is clamped to `range` (from scroll_range).
func scroll_to(z: float, range: Vector2, free: Rect2, view: Vector2) -> void:
	target = Vector3(map.w / 2.0, 0.6, clampf(z, range.x, range.y))
	distance = CAMERA_DISTANCE
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	_place_camera()
	var r := board_screen_rect(view)
	var px_per_unit := view.y / (2.0 * distance * tan(deg_to_rad(fov / 2.0)))
	var d := Vector2(free.get_center().x - view.x / 2.0, free.get_center().y - r.get_center().y)
	cam.h_offset = -d.x / px_per_unit
	cam.v_offset = d.y / px_per_unit
	view_changed.emit()


## Where a world point lands on a `view`-sized screen (perspective, fov is vertical; offsets ignored).
func project(p: Vector3, view: Vector2) -> Vector2:
	var q := cam.transform.affine_inverse() * p  # board space (the camera is the board's child)
	var f := view.y / 2.0 / tan(deg_to_rad(fov / 2.0))
	return view / 2.0 + Vector2(q.x, -q.y) / maxf(-q.z, 0.01) * f


func _place_camera() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	var dist := distance
	cam.transform = Transform3D(basis, target + basis * Vector3(0, 0, dist))
	var attrs := cam.attributes as CameraAttributesPractical
	attrs.dof_blur_near_distance = dist * 0.55
	attrs.dof_blur_near_transition = dist * 0.3
	attrs.dof_blur_far_distance = dist * 1.25
	attrs.dof_blur_far_transition = dist * 0.9
	_place_shafts()
	_fit_inputs.clear()  # Camera rotation/zoom changes the projected size of every upright.
	_refit_uprights()
	view_changed.emit()


## Upright sprites seen from above are squashed by cos(pitch) (0.64 at 50 degrees), which makes them
## look short and wide like a card lying back. Stretching them by 1 / cos(pitch) on Y gives back the
## drawn proportions on screen while the sprite stays vertical (and keeps its feet on the block).
func unit_stretch() -> float:
	return 1.0 / maxf(cos(deg_to_rad(absf(pitch))), 0.3)


## The stretch that gives an upright sprite at world point `p` its drawn proportions: 1 / cos(e), e being how
## far above the horizon the camera is as seen from `p`. The camera looks down more steeply at what is near it and
## more shallowly at what is far, so a single stretch (unit_stretch, exact only on the centre line) would make
## sprites far up the board look taller than the same sprite near the camera.
func stretch_at(p: Vector3) -> float:
	var to := cam.global_position - p
	var elevation := asin(clampf(to.y / maxf(to.length(), 0.001), 0.0, 1.0))
	return 1.0 / maxf(cos(elevation), 0.3)


## Re-fits every upright to the stretch of where it stands now (units move, the camera orbits).
func _refit_uprights() -> void:
	for u in uprights:
		if is_instance_valid(u) and u.is_inside_tree():
			_fit_one(u)


## Fits one upright: the stretch of where it stands, and for units a size factor that keeps them the same size on screen
## wherever they stand (distance to the camera over the distance to the board's centre; the centre keeps the old size).
func _fit_one(n: Node3D) -> void:
	var pos := n.global_position
	var px: float = n.sprite.pixel_size if n is UnitView3D else 0.0
	var previous: Array = _fit_inputs.get(n, [])
	if previous.size() == 2 and previous[0] == pos and previous[1] == px:
		return
	_fit_inputs[n] = [pos, px]
	var k := stretch_at(pos)
	var m := unit_size_at(n.global_position, n.sprite.pixel_size, k) if n is UnitView3D else 1.0
	var lean := on_screen_lean(pos) if (n is UnitView3D and lean_correction) else 0.0
	var key := Vector3(k, m, lean)
	if _fitted.get(n, Vector3.INF).is_equal_approx(key):
		return
	_fitted[n] = key
	if n is UnitView3D:
		if lean_correction:
			n.set_orient(upright_orient(lean))
		n.fit(k, m)
	else:
		n.fit(k)


## The largest correction (degrees): a unit far out at the screen's edge is turned back by at most this much.
const LEAN_CAP := 15.0
## A sprite turned about the view axis shows slightly less than the turn on screen (it is a flat quad tilted back from the screen's plane), so turn it
## a little more. Measured: about 90% shows (scroll_check).
const LEAN_GAIN := 1.11


## How far a vertical line standing at `foot` leans on screen, in radians (positive: its top is to the right of its foot), capped at
## LEAN_CAP. A perspective camera tilted down makes vertical lines converge below the screen, so the further a unit is from the middle of
## the screen the more its top leans outward (about 11 degrees at 350 px, 22 at 700 px on a 1080p screen).
func on_screen_lean(foot: Vector3) -> float:
	var a := cam.unproject_position(foot)
	var b := cam.unproject_position(foot + Vector3.UP)
	return clampf(atan2(b.x - a.x, a.y - b.y), -deg_to_rad(LEAN_CAP), deg_to_rad(LEAN_CAP))


## The orientation of an upright sprite standing at a point whose vertical leans `lean` radians on screen: what the fixed-Y billboard
## draws (the camera's right axis kept level, up along the world's Y), turned about the view axis by the opposite angle so it
## looks vertical on screen.
func upright_orient(lean: float) -> Basis:
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var base := Basis(right, Vector3.UP, right.cross(Vector3.UP))
	var forward := -cam.global_transform.basis.z
	return Basis(forward, -lean * LEAN_GAIN) * base


## Size factor for a unit at world point `p` (sprite pixel size `px`, stretch `k`): the number that makes a figure
## the same height on screen as at the board's centre, near the camera or far from it. The distance ratio is the
## first guess; one correction from the real projected height takes care of the figure's top being nearer the
## camera than its feet.
func unit_size_at(p: Vector3, px: float, k: float) -> float:
	var world_h := 100.0 * px  # a nominal 100 px figure
	var ref := _projected_height(target, world_h * stretch_at(target))
	var m := cam.global_position.distance_to(p) / maxf(cam.global_position.distance_to(target), 0.001)
	return m * ref / maxf(_projected_height(p, world_h * k * m), 0.001)


## On-screen height in px of a vertical segment of `world_h` standing at `p`.
func _projected_height(p: Vector3, world_h: float) -> float:
	return absf(cam.unproject_position(p).y - cam.unproject_position(p + Vector3(0, world_h, 0)).y)


func _process(_delta: float) -> void:
	if cam != null and cam.is_inside_tree():
		var viewport_size := get_viewport().get_visible_rect().size
		if cam.global_transform != _fit_camera_transform or viewport_size != _fit_viewport_size:
			_fit_camera_transform = cam.global_transform
			_fit_viewport_size = viewport_size
			_fit_inputs.clear()
		_refit_uprights()


## Quarter-turns the view (the camera orbits the board; nothing is rebuilt).
func rotate_view(steps: int) -> void:
	rot = posmod(rot + steps, 4)
	yaw = -90.0 * rot
	_place_camera()


## Registers a billboard (anything with `fit(k)`) to be stretched against the camera pitch.
func add_upright(n: Node3D) -> void:
	uprights.append(n)
	if cam != null and cam.is_inside_tree() and n.is_inside_tree():
		_fit_one(n)
	else:
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


## The map's props (PropView3D): {"id", "x", "y", "h" (height in world units), "flip"} in map.props.
## Braziers, banners, crates, crystals and the ambient weather named in the map data (BoardLife); nothing in it blocks a tile.
func _build_life() -> void:
	if not map.has("life") and not map.has("ambient"):
		return
	life = BoardLife.new()
	add_child(life)
	life.build(self, map)


func _build_props() -> void:
	for p in map.get("props", []):
		var v := PropView3D.new()
		v.position = top_point(int(p.x), int(p.y))
		add_child(v)
		v.setup(String(p.id), float(p.get("h", PropView3D.DEFAULT_HEIGHT)), bool(p.get("flip", false)))
		add_upright(v)
		props.append(v)


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
