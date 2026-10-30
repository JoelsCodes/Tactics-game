class_name Terrain
extends Node2D
## Draws an isometric height map from the tile art. Each tile is a block of textured Polygon2D faces
## (top plus the two visible sides) placed in a Y-sorted `field`, so anything added to the field
## (characters, props) overlaps the terrain correctly. Kept from the first build: this is how the
## tile sheets are placed and made to look right. See README "Terrain".
##
## A map is {w, d, tiles: [[{t, h}]], smooth, hub, shadows, tufts, props}; `parse` builds one from rows
## of "<terrain><height>" codes, e.g. "g0 g1 W0". `smooth` defaults to true.

const TW := IsoProjection.TW  ## tile half-width
const TH := IsoProjection.TH  ## tile half-height
const HS := IsoProjection.HS  ## height of one level
const BASE := 1.3  ## how far blocks reach below level 0
const TEX := 96.0  ## top texture size; side strips are 4 tiles (384 px) wide
const SIDE_PX := 3.0  ## side texture pixels per world pixel
## Terrains whose tops are baked into one seamless texture each (tools/art/build_art.py bake_terrain / bake_ground).
const SEAMLESS := ["grass", "dirt", "sand", "stone", "crag", "cinder", "marble", "mud", "snow", "isle"]
## These tiles are never sloped.
const FLAT_TILES := ["W", "w", "l", "b"]
const SLOPE_SHADE := .3  ## brightness change per level of slope on smooth maps
const AO_PER_LEVEL := .13  ## corner darkening per level a corner's surroundings stand above the tile
const SHADOW_PER_LEVEL := .13  ## cast shadow per level of the taller tile toward the light (front-left)
const SHADOW_MAX := .5
const LEFT_LIGHT := Color(1.0, .93, .8)  ## warm light on the left face
const RIGHT_LIGHT := Color(.62, .64, .78)  ## the right face is turned from the light: darker, cooler
const TOP_LIGHT := Color(1.0, .96, .86)  ## warm overhead light on tops

## Per terrain code: top texture set, side strip, how far down the strip starts (skips the grass lip), tint.
const LOOK := {
	"g": {"top": "grass", "n": 8, "side": "blockgrass", "v0": 34.0},
	"m": {"top": "mud", "n": 4, "side": "grass", "v0": 26.0, "tint": Color(.7, .75, .65)},
	"d": {"top": "dirt", "n": 3, "side": "dirtblk", "v0": 0.0},
	"a": {"top": "sand", "n": 8, "side": "grass", "v0": 26.0, "tint": Color(1.12, 1.0, .8)},
	"s": {"top": "stone", "n": 3, "side": "stoneblk", "v0": 0.0},
	"r": {"top": "crag", "n": 8, "side": "crag", "v0": 0.0},
	"n": {"top": "snow", "n": 16, "side": "snow", "v0": 0.0},
	"c": {"top": "cinder", "n": 9, "side": "cinder", "v0": 0.0},
	"b": {"top": "bridge", "n": 2, "side": "grass", "v0": 26.0, "tint": Color(.62, .5, .4)},
	"w": {"top": "shallow", "n": 2, "side": "grass", "v0": 26.0, "tint": Color(.65, .8, .95), "water": 0.0},
	"W": {"top": "deep", "n": 2, "side": "grass", "v0": 26.0, "tint": Color(.5, .62, .85), "water": 1.0},
	"t": {"top": "grass", "n": 8, "side": "blockgrass", "v0": 34.0, "tree": true},
	"l": {"top": "lava", "n": 4, "side": "cinder", "v0": 0.0, "lava": true},
	"M": {"top": "marble", "n": 6, "side": "island", "v0": 0.0},
	"k": {"top": "isle", "n": 10, "side": "island", "v0": 0.0},
	# the abandoned castle (tools/art/castle_tiles.py): one slab per tile, not blended
	# (tinted down: the light sandstone takes the warm sun too strongly)
	"f": {"top": "castle", "n": 1, "side": "castlesoil", "v0": 0.0, "tint": Color(.78, .76, .74)},  # flagstone floor
	"h": {"top": "castlemoss", "n": 9, "side": "castlesoil", "v0": 0.0, "tint": Color(.78, .76, .74)},  # overgrown flagstones (moss, dirt, grass tufts)
	"e": {"top": "castlecarved", "n": 1, "side": "castlewall", "v0": 0.0, "tint": Color(.78, .76, .74)},  # carved medallion slab on brick (a dais)
	"o": {"top": "castleframed", "n": 1, "side": "castlewall", "v0": 0.0, "tint": Color(.78, .76, .74)},  # slab with a carved border, on brick
	"q": {"top": "castle", "n": 1, "side": "castlewall", "v0": 0.0, "tint": Color(.72, .7, .68)},  # sandstone brick wall
	"v": {"void": true},
}

## Emitted after the tile blocks are rebuilt (new map or view rotation), so overlays can re-attach.
signal rebuilt

var map: Dictionary
var rot := 0  ## view rotation in quarter turns
var blocks := {}  ## "x,y" -> Node2D
var field := Node2D.new()

var _tex := {}
var _water_mats := {}
var _lava_mat: ShaderMaterial
var _face_mat: ShaderMaterial  ## stone detail + baked vertex lighting for tops and sides


func _ready() -> void:
	field.name = "Field"
	field.y_sort_enabled = true
	add_child(field)
	_face_mat = ShaderMaterial.new()
	_face_mat.shader = load("res://shaders/terrain_face.gdshader")
	_lava_mat = ShaderMaterial.new()
	_lava_mat.shader = load("res://shaders/lava.gdshader")
	for d in [0.0, 1.0]:
		var wm := ShaderMaterial.new()
		wm.shader = load("res://shaders/water.gdshader")
		wm.set_shader_parameter("depth", d)
		_water_mats[d] = wm


## Map from rows of "<terrain><height>" codes. Extra keys (smooth, hub, props...) are copied over.
static func parse(src: Dictionary) -> Dictionary:
	var m := src.duplicate()
	var tiles := []
	for row in src.rows:
		var r := []
		for c in String(row).split(" ", false):
			r.append({"t": c.substr(0, 1), "h": c.substr(1).to_int()})
		tiles.append(r)
	m.tiles = tiles
	m.d = tiles.size()
	m.w = tiles[0].size()
	m.erase("rows")
	return m


static func load_map(path: String) -> Dictionary:
	return parse(JSON.parse_string(FileAccess.get_file_as_string(path)))


func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func tile_at(x, y) -> Variant:
	var xi := roundi(x)
	var yi := roundi(y)
	if xi >= 0 and yi >= 0 and xi < map.w and yi < map.d:
		return map.tiles[yi][xi]
	return null


func smooth() -> bool:
	return map.get("smooth", true)


func show_map(m: Dictionary) -> void:
	map = m
	rebuild()


## Rebuilds every tile block (on a new map and after rotating the view). Other children of `field` stay.
func rebuild() -> void:
	for k in blocks:
		blocks[k].queue_free()
	blocks = {}
	for y in map.d:
		for x in map.w:
			var b := _make_block(x, y)
			field.add_child(b)
			field.move_child(b, 0)
			blocks["%d,%d" % [x, y]] = b
	rebuilt.emit()


## The tile block node of a cell (null for none).
func block(c: Vector2i) -> Node2D:
	return blocks.get("%d,%d" % [c.x, c.y])


func rotate_view(dir: int) -> void:
	rot = (rot + dir + 4) % 4
	rebuild()


func rot_xy(x: float, y: float) -> Vector2:
	return IsoProjection.rotate(Vector2(x, y), rot, map.w, map.d)


## Ground point (level 0) of a grid position.
func ground(x: float, y: float) -> Vector2:
	return IsoProjection.ground(Vector2(x, y), rot, map.w, map.d)


func iso(x: float, y: float, h: float) -> Vector2:
	return ground(x, y) - Vector2(0, h * HS)


## Where something standing at grid (x, y) is drawn, on top of the ground (slopes included).
func stand_point(x: float, y: float) -> Vector2:
	return iso(x, y, terrain_h(x, y))


static func hash01(x: int, y: int, k := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h & 0xffff) / 65535.0


## Height of the map corner at vertex (i, j), which sits at grid point (i - .5, j - .5): the mean of the tiles around it.
func _vh(i: int, j: int) -> float:
	var sum := 0.0
	var n := 0
	for o in [[i - 1, j - 1], [i, j - 1], [i - 1, j], [i, j]]:
		var t = tile_at(o[0], o[1])
		if t != null and t.t != "v":
			sum += t.h
			n += 1
	return sum / n if n else 0.0


## Heights of a tile's four corners in screen order (top, right, bottom, left). Flat tiles: all the same.
func _corner_heights(x: int, y: int, h: float) -> Array:
	var tt: String = map.tiles[y][x].t
	if not smooth() or tt in FLAT_TILES:  # water, lava and bridges stay level
		return [h, h, h, h]
	var out := []
	for off in [[-.5, -.5], [.5, -.5], [.5, .5], [-.5, .5]]:  # in rotated view space
		var g: Array = [off[0], off[1]]
		match rot:
			1: g = [off[1], -off[0]]
			2: g = [-off[0], -off[1]]
			3: g = [-off[1], off[0]]
		out.append(_vh(x + (1 if g[0] > 0 else 0), y + (1 if g[1] > 0 else 0)))
	return out


## Ground height at a grid point, for standing on slopes.
func terrain_h(x: float, y: float) -> float:
	if not smooth():
		var t = tile_at(x, y)
		return float(t.h) if t != null else 0.0
	var fx := x + .5
	var fy := y + .5
	var i := floori(fx)
	var j := floori(fy)
	var tx := fx - i
	var ty := fy - j
	return lerpf(lerpf(_vh(i, j), _vh(i + 1, j), tx), lerpf(_vh(i, j + 1), _vh(i + 1, j + 1), tx), ty)


func _make_block(x: int, y: int) -> Node2D:
	var t: Dictionary = map.tiles[y][x]
	var L: Dictionary = LOOK.get(t.t, LOOK.g)
	var r := rot_xy(x, y)
	var n := Node2D.new()
	n.position = ground(x, y)
	n.name = "Tile_%d_%d" % [x, y]
	if L.get("void"):
		_make_cloud(n, x, y)
		return n
	if map.get("hub") and L.get("side") in ["grass", "blockgrass"]:  # floating islands: bridges and pools hang from the island rock
		L = L.duplicate()
		L.side = "island"
		L.v0 = 0.0
	var h: float = t.h - (.35 if t.t == "W" else 0.0)
	# Corner heights: on a smooth map each corner is the average of the tiles around it, so tops slope
	# into their neighbours and there are no cliff steps.
	var ch := _corner_heights(x, y, h)
	var ty: float = -(ch[0] + ch[1] + ch[2] + ch[3]) / 4.0 * HS
	var top_t := Vector2(0, -TH - ch[0] * HS)
	var top_r := Vector2(TW, -ch[1] * HS)
	var top_b := Vector2(0, TH - ch[2] * HS)
	var top_l := Vector2(-TW, -ch[3] * HS)
	var bot_l := Vector2(-TW, BASE * HS)  # the sides always reach the same base level
	var bot_b := Vector2(0, TH + BASE * HS)
	var bot_r := Vector2(TW, BASE * HS)
	var depth: float = (-ty / HS + BASE) * HS
	var tint: Color = L.get("tint", Color.WHITE)
	# sides: the strip spans 4 tiles, so neighbours continue the same rock face
	var v0: float = L.v0
	var segl := posmod(int(r.x), 4) * TEX
	var segr := posmod(-int(r.y), 4) * TEX
	var left := _poly([top_l, top_b, bot_b, bot_l], "res://assets/tiles/side_%s_l.png" % L.side,
		[Vector2(segl, v0), Vector2(segl + TEX, v0), Vector2(segl + TEX, v0 + (bot_b.y - top_b.y) * SIDE_PX), Vector2(segl, v0 + (bot_l.y - top_l.y) * SIDE_PX)], tint)
	var right := _poly([top_b, top_r, bot_r, bot_b], "res://assets/tiles/side_%s_r.png" % L.side,
		[Vector2(segr, v0), Vector2(segr + TEX, v0), Vector2(segr + TEX, v0 + (bot_r.y - top_r.y) * SIDE_PX), Vector2(segr, v0 + (bot_b.y - top_b.y) * SIDE_PX)], tint)
	_shade_side(left, tint * LEFT_LIGHT, [1.0, 1.0, .55, .55])
	_shade_side(right, tint * RIGHT_LIGHT, [1.0, 1.0, .5, .5])
	n.add_child(left)
	n.add_child(right)
	# top
	var path := ""
	var top_uv := [Vector2(0, 0), Vector2(TEX, 0), Vector2(TEX, TEX), Vector2(0, TEX)]
	var seamless: bool = L.top in SEAMLESS and not L.has("water") and not L.get("lava") and L.n > 0
	if seamless:  # one big texture per terrain laid out by position, so the ground has no tile borders
		path = "res://assets/tiles/ground_%s.png" % L.top
		top_uv = [Vector2(r.x * TEX, r.y * TEX), Vector2((r.x + 1) * TEX, r.y * TEX), Vector2((r.x + 1) * TEX, (r.y + 1) * TEX), Vector2(r.x * TEX, (r.y + 1) * TEX)]
	elif L.n:
		path = "res://assets/tiles/%s_%02d.png" % [L.top, int(hash01(x, y) * L.n) % L.n]
	var grow := 1.015 if seamless else 1.0  # a hair larger so neighbours overlap and no gaps show
	var tc := (top_t + top_r + top_b + top_l) / 4.0
	var top := _poly([tc + (top_t - tc) * grow, tc + (top_r - tc) * grow, tc + (top_b - tc) * grow, tc + (top_l - tc) * grow], path, top_uv, Color.WHITE)
	if seamless:
		top.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if smooth():  # shade by slope: light comes from behind, so slopes rising toward the viewer are brighter
		var sx: float = ((ch[1] + ch[2]) - (ch[0] + ch[3])) / 2.0
		var sy: float = ((ch[2] + ch[3]) - (ch[0] + ch[1])) / 2.0
		var lit := clampf(.9 + SLOPE_SHADE * (sx + sy), .55, 1.0)
		top.color = Color(lit, lit, lit * .98)
	if not L.has("water") and not L.get("lava"):
		var sh := corner_shade(x, y, h, ch)
		var base := top.color * TOP_LIGHT
		var cols := PackedColorArray()
		for i in 4:
			var v: float = sh[i]
			cols.append(Color(base.r * v, base.g * v, base.b * v, 1.0))
		top.vertex_colors = cols
		top.material = _face_mat
	if L.has("water"):
		top.material = _water_mats[L.water]
	elif L.get("lava"):
		top.material = _lava_mat
	n.add_child(top)
	if map.get("shadows") and not smooth() and h > 0:  # raised tiles cast a soft shadow onto the ground
		var sh := Sprite2D.new()
		sh.texture = tex("res://assets/fx/shadow.png")
		sh.scale = Vector2(1.5, .75)
		sh.position = Vector2(8, ty + TH * .8 + depth * .1)
		sh.modulate = Color(0, 0, 0, .35)
		sh.z_index = -1
		n.add_child(sh)
		n.move_child(sh, 0)
	if map.get("tufts") and t.t == "g" and hash01(x, y, 20) < .5:  # standing grass on some tiles
		var tf := Sprite2D.new()
		tf.texture = tex("res://assets/props/tuft_%d.png" % (int(hash01(x, y, 21) * 4) % 4))
		tf.offset = Vector2(0, -tf.texture.get_height() / 2.0 + 4)
		tf.position = Vector2((hash01(x, y, 22) - .5) * 26, ty + (hash01(x, y, 23) - .5) * 10)
		tf.scale = Vector2.ONE * (.7 + hash01(x, y, 24) * .3)
		tf.flip_h = hash01(x, y, 25) > .5
		n.add_child(tf)
	if not seamless and not L.get("tree") and L.n > 0 and not L.has("water") and not L.get("lava"):  # soft seam line, only for the few unbaked tops (bridges)
		var edge := Line2D.new()
		edge.points = PackedVector2Array([top_t, top_r, top_b, top_l, top_t])
		edge.width = 1.0
		edge.default_color = Color(0.05, 0.06, 0.02, .22)
		n.add_child(edge)
	if L.get("tree"):
		var tree := Sprite2D.new()
		tree.texture = tex("res://assets/props/tree.png")
		tree.offset = Vector2(0, -tree.texture.get_height() / 2.0 + 6)
		tree.position = Vector2((hash01(x, y, 5) - .5) * 6, ty)
		tree.scale = Vector2.ONE * (.62 + hash01(x, y, 6) * .12)
		tree.flip_h = hash01(x, y, 7) > .5
		n.add_child(tree)
	for p in map.get("props", []):
		if p.x == x and p.y == y:
			_add_prop(n, p.k, ty)
	if L.get("lava"):
		var light := PointLight2D.new()
		light.texture = tex("res://assets/fx/soft_dot.png")
		light.texture_scale = 3.2
		light.color = Color(1, .55, .2)
		light.energy = .9
		light.position = Vector2(0, ty)
		n.add_child(light)
	n.set_meta("top", ty)
	n.set_meta("top_poly", PackedVector2Array([top_t, top_r, top_b, top_l]))  # the top face, block-local: for overlays
	return n


## Open sky: a puff of cloud that bobs. Neighbouring islands rise out of it.
func _make_cloud(n: Node2D, x: int, y: int) -> void:
	n.set_meta("top", 0.0)
	if hash01(x, y, 11) < .2 or not _near_land(x, y, 3):
		return
	n.z_index = -1  # behind every island, so clouds frame the rock instead of covering it
	var s := Sprite2D.new()
	s.texture = tex("res://assets/fx/cloud_%d.png" % (int(hash01(x, y, 12) * 3) % 3))
	s.position = Vector2((hash01(x, y, 13) - .5) * 30, 34 + hash01(x, y, 14) * 20)
	s.scale = Vector2.ONE * (.9 + hash01(x, y, 15) * .6)
	s.flip_h = hash01(x, y, 16) > .5
	s.modulate = Color(1, 1, 1, .94)
	n.add_child(s)
	var tw := s.create_tween().set_loops()
	var dy := 2.0 + hash01(x, y, 17) * 2.0
	tw.tween_property(s, "position:y", s.position.y + dy, 2.2 + hash01(x, y, 18) * 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", s.position.y - dy, 2.2 + hash01(x, y, 18) * 1.5).set_trans(Tween.TRANS_SINE)


func _near_land(x: int, y: int, r: int) -> bool:
	for yy in range(y - r, y + r + 1):
		for xx in range(x - r, x + r + 1):
			var t = tile_at(xx, yy)
			if t != null and t.t != "v":
				return true
	return false


## A pedestal sprite cut whole from a block sheet (assets/props/sky_<kind>.png), standing on the tile.
func _add_prop(n: Node2D, kind: String, ty: float) -> void:
	var path := "res://assets/props/sky_%s.png" % kind
	if not ResourceLoader.exists(path):
		return
	var pt := tex(path)
	var ps := Sprite2D.new()
	ps.texture = pt
	ps.centered = false
	var sc := 2.0 * TW * (.9 if kind == "obelisk" else .62) / pt.get_width()
	ps.scale = Vector2.ONE * sc
	ps.position = Vector2(-pt.get_width() * sc / 2, ty + TH * .55 - pt.get_height() * sc)
	n.add_child(ps)


## Vertex shades of a tile's top (screen order top, right, bottom, left): ambient occlusion where the
## surroundings of a corner stand higher than the tile, plus the soft shadow of a taller tile on the
## lit side (view-grid down-left of this tile: the light comes from the front-left, shadows fall up-right).
func corner_shade(x: int, y: int, h: float, ch: Array) -> Array:
	var shade := []
	for i in 4:
		shade.append(1.0 - AO_PER_LEVEL * clampf(ch[i] - h, 0.0, 3.0))
	var g := Vector2i(0, 1)  # view-space neighbour toward the light, mapped to grid space
	match rot:
		1: g = Vector2i(1, 0)
		2: g = Vector2i(0, -1)
		3: g = Vector2i(-1, 0)
	var nt = tile_at(x + g.x, y + g.y)
	if nt != null and nt.t != "v":
		var dh := clampf(float(nt.h) - h, 0.0, 3.0)
		if dh > 0.0:
			var s := minf(SHADOW_PER_LEVEL * dh, SHADOW_MAX)
			shade[2] -= s  # bottom corner and left corner touch the edge beside the caster
			shade[3] -= s
			shade[0] -= s * .35
			shade[1] -= s * .35
	return shade


## Per-vertex shading of a side face: `v` is [top-left, top-right, bottom-right, bottom-left] brightness
## (the faces get darker toward the ground, as if occluded by it), `col` the face's light color.
func _shade_side(p: Polygon2D, col: Color, v: Array) -> void:
	var cols := PackedColorArray()
	for i in 4:
		cols.append(Color(col.r * v[i], col.g * v[i], col.b * v[i], 1.0))
	p.vertex_colors = cols
	p.material = _face_mat


func _poly(pts: Array, path: String, uv: Array, tint: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.uv = PackedVector2Array(uv)
	p.texture = tex(path)
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	p.color = tint
	return p
