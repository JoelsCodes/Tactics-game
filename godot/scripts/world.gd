class_name BattleWorld
extends Node2D
## The battlefield. Each map tile is a block of textured Polygon2D faces (top plus the
## two visible sides, cut from the terrain sheet) placed in a Y-sorted field, so units
## and terrain overlap correctly. Also owns the camera (drag, pinch, wheel, rotation),
## tile picking, highlights, the facing arrows, effects and per-map ambience.

signal tile_tapped(x: float, y: float)  ## a ground point in grid units (free movement)

const TW := 32.0  ## tile half-width
const TH := 16.0  ## tile half-height
const HS := 14.0  ## height of one level
const BASE := 1.3  ## how far blocks reach below level 0
const TEX := 96.0  ## top texture size; side strips are 4 tiles (384 px) wide
const SIDE_PX := 3.0  ## side texture pixels per world pixel
## Grass block tops (assets/tiles/blocktop_NN.png, numbered row by row on the 8x8 sheet), grouped into
## families so neighbouring tiles match: smooth lawn, tufted, mossy; flowers and stones come in small patches.
const GRASS_SMOOTH := [0, 2, 4, 6, 7, 13, 27, 28, 35, 36]
const GRASS_TUFTED := [1, 3, 5, 9, 11, 30, 31]
const GRASS_MOSSY := [8, 10, 12, 16, 17, 24, 25, 32, 33]
const GRASS_FLOWERS := [14, 15, 22, 45, 46, 47]
const GRASS_STONES := [23, 52, 53, 54]
const SLOPE_SHADE := .3  ## brightness change per level of slope on smooth maps
const BLOCKER_ALPHA := .4  ## opacity of units standing in front of the active one

## Per terrain: top texture set, side strip, how far down the strip starts (skips the grass lip), tint.
const LOOK := {
	"g": {"top": "grass", "n": 8, "side": "blockgrass", "v0": 34.0},
	"m": {"top": "mud", "n": 4, "side": "grass", "v0": 26.0, "tint": Color(.7, .75, .65)},
	"d": {"top": "dirt", "n": 8, "side": "grass", "v0": 26.0},
	"a": {"top": "sand", "n": 8, "side": "grass", "v0": 26.0, "tint": Color(1.12, 1.0, .8)},
	"s": {"top": "stone", "n": 8, "side": "ash2", "v0": 0.0},
	"r": {"top": "crag", "n": 8, "side": "ash2", "v0": 0.0, "tint": Color(1.25, 1.15, 1.05)},
	"c": {"top": "cinder", "n": 8, "side": "ash", "v0": 0.0},
	"b": {"top": "bridge", "n": 2, "side": "grass", "v0": 26.0, "tint": Color(.62, .5, .4)},
	"w": {"top": "shallow", "n": 2, "side": "grass", "v0": 26.0, "tint": Color(.65, .8, .95), "water": 0.0},
	"W": {"top": "deep", "n": 2, "side": "grass", "v0": 26.0, "tint": Color(.5, .62, .85), "water": 1.0},
	"t": {"top": "grass", "n": 8, "side": "blockgrass", "v0": 34.0, "tree": true},
	"l": {"top": "lava", "n": 2, "side": "lava", "v0": 0.0, "lava": true},
	"M": {"top": "marble", "n": 8, "side": "skymarble", "v0": 0.0, "tint": Color(.94, .98, 1.06)},
	"k": {"top": "crag", "n": 8, "side": "skyrock", "v0": 0.0, "tint": Color(1.7, 1.55, 1.4)},
	"v": {"void": true},
}
const MOOD := {
	"briar": {"light": Color(1, .98, .94), "sky": [Color("#2b4a6b"), Color("#0e1726")], "air": "pollen"},
	"quarry": {"light": Color(.86, .78, .76), "sky": [Color("#3a2522"), Color("#120b0b")], "air": "embers"},
	"base": {"light": Color(1, .985, .96), "sky": [Color("#5f93d6"), Color("#e9e2d2")], "air": "sky"},
	"mirewood": {"light": Color(.7, .8, .78), "sky": [Color("#1d3330"), Color("#070e0e")], "air": "fireflies"},
}

var B: Dictionary
var rot := 0
var blocks := {}  ## "x,y" -> Node2D
var views := {}  ## unit id -> UnitView
var obj_nodes := {}  ## vessel object id -> placeholder marker (no art yet)
var hl := {}  ## "x,y" -> Color
var area := {}  ## "x,y" -> true
var cursor = null
var active = null
var min_zoom := .6
var max_zoom := 2.4

var _tex := {}
var _water_mats := {}
var _lava_mat: ShaderMaterial
var _clock := 0.0
var _touches := {}
var _drag = null
var _moved := false
var _pinch = null
var _arrows: Array = []
var _shake := 0.0

@onready var field: Node2D = $Field
@onready var fx: Node2D = $FX
@onready var cam: Camera2D = $Camera
@onready var mood: CanvasModulate = $Mood
@onready var ambient: Node2D = $Ambient

var unit_scene := preload("res://scenes/unit.tscn")


func _ready() -> void:
	field.y_sort_enabled = true


func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


# ---------- setup ----------
func setup(battle: Dictionary) -> void:
	B = battle
	var m: Dictionary = MOOD.get(B.map.key, MOOD.briar)
	mood.color = m.light
	_lava_mat = ShaderMaterial.new()
	_lava_mat.shader = load("res://shaders/lava.gdshader")
	for d in [0.0, 1.0]:
		var wm := ShaderMaterial.new()
		wm.shader = load("res://shaders/water.gdshader")
		wm.set_shader_parameter("depth", d)
		_water_mats[d] = wm
	for u in B.units:
		u.vx = float(u.x)
		u.vy = float(u.y)
		u.vh = float(Rules.tile_at(B, u.x, u.y).h)
		var v: UnitView = unit_scene.instantiate()
		field.add_child(v)
		v.setup(u)
		views[u.id] = v
	rebuild()
	_build_ambient(m.air)
	var n: float = B.map.w + B.map.d
	var fit: float = get_viewport_rect().size.x / (n * TW * .62)
	min_zoom = clampf(fit * .8, .45, 1.0)
	cam.zoom = Vector2.ONE * clampf(1.2, min_zoom, max_zoom)
	center_on(B.map.w / 2.0, B.map.d / 2.0, true)


func sky_colors() -> Array:
	return MOOD.get(B.map.key, MOOD.briar).sky


## Rebuilds every tile block (on setup and after rotating the view).
func rebuild() -> void:
	for k in blocks:
		blocks[k].queue_free()
	blocks = {}
	for y in B.map.d:
		for x in B.map.w:
			var b := _make_block(x, y)
			field.add_child(b)
			field.move_child(b, 0)
			blocks[Rules.key(x, y)] = b
	_apply_hl()
	sync_units(true)


func rot_xy(x: float, y: float) -> Vector2:
	var w: float = B.map.w
	var d: float = B.map.d
	match rot:
		1: return Vector2(d - 1 - y, x)
		2: return Vector2(w - 1 - x, d - 1 - y)
		3: return Vector2(y, w - 1 - x)
	return Vector2(x, y)


## Ground point (level 0) of a grid position.
func ground(x: float, y: float) -> Vector2:
	var r := rot_xy(x, y)
	return Vector2((r.x - r.y) * TW, (r.x + r.y) * TH)


func iso(x: float, y: float, h: float) -> Vector2:
	return ground(x, y) - Vector2(0, h * HS)


## Screen direction of a grid facing (sprite mirroring, facing arrows).
func screen_dir(f: int) -> Vector2:
	var d: Array = Rules.DIRS[f]
	var r := rot_xy(d[0], d[1]) - rot_xy(0, 0)
	return Vector2(r.x - r.y, (r.x + r.y) / 2)


static func hash01(x: int, y: int, k := 0) -> float:
	var h := (x * 374761393 + y * 668265263 + k * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h & 0xffff) / 65535.0


## Smooth value noise in 0..1 over the map (cells of `scale` tiles), so choices change in patches.
static func _noise(x: float, y: float, scale: float, salt: int) -> float:
	var fx := x / scale
	var fy := y / scale
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := hash01(x0, y0, salt)
	var b := hash01(x0 + 1, y0, salt)
	var c := hash01(x0, y0 + 1, salt)
	var d := hash01(x0 + 1, y0 + 1, salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Which grass top a tile uses: a family chosen by slow noise (so areas match), with flower and stone patches.
static func _grass_top(x: int, y: int) -> int:
	var pool: Array
	if _noise(x, y, 4.0, 41) > .8 and hash01(x, y, 42) < .75:
		pool = GRASS_FLOWERS
	elif _noise(x, y, 5.0, 43) > .84 and hash01(x, y, 44) < .7:
		pool = GRASS_STONES
	else:
		var n := _noise(x, y, 6.0, 40)
		pool = GRASS_SMOOTH if n < .45 else GRASS_MOSSY if n < .62 else GRASS_TUFTED
	return pool[int(hash01(x, y, 45) * pool.size()) % pool.size()]


## Height of the map corner at vertex (i, j), which sits at grid point (i - .5, j - .5): the mean of the tiles around it.
func _vh(i: int, j: int) -> float:
	var sum := 0.0
	var n := 0
	for o in [[i - 1, j - 1], [i, j - 1], [i - 1, j], [i, j]]:
		var t = Rules.tile_at(B, o[0], o[1])
		if t != null and t.t != "v":
			sum += t.h
			n += 1
	return sum / n if n else 0.0


## Heights of a tile's four corners in screen order (top, right, bottom, left). Flat tiles: all the same.
func _corner_heights(x: int, y: int, h: float) -> Array:
	if not B.map.get("smooth"):
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
	if not B.map.get("smooth"):
		var t = Rules.tile_at(B, x, y)
		return float(t.h) if t != null else 0.0
	var fx := x + .5
	var fy := y + .5
	var i := floori(fx)
	var j := floori(fy)
	var tx := fx - i
	var ty := fy - j
	return lerpf(lerpf(_vh(i, j), _vh(i + 1, j), tx), lerpf(_vh(i, j + 1), _vh(i + 1, j + 1), tx), ty)


func _make_block(x: int, y: int) -> Node2D:
	var t: Dictionary = B.map.tiles[y][x]
	var L: Dictionary = LOOK.get(t.t, LOOK.g)
	var r := rot_xy(x, y)
	var n := Node2D.new()
	n.position = ground(x, y)
	n.name = "Tile_%d_%d" % [x, y]
	if L.get("void"):
		_make_cloud(n, x, y)
		return n
	if B.map.get("hub") and L.get("side") == "grass":  # bridges and pools hang from the island rock
		L = L.duplicate()
		L.side = "skyrock"
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
	n.add_child(left)
	n.add_child(right)
	# top
	var path := ""
	var top_uv := [Vector2(0, 0), Vector2(TEX, 0), Vector2(TEX, TEX), Vector2(0, TEX)]
	var seamless: bool = t.t == "g"
	if seamless:  # grass: one big texture laid out by position, so the ground has no tile borders
		path = "res://assets/tiles/ground_grass.png"
		top_uv = [Vector2(r.x * TEX, r.y * TEX), Vector2((r.x + 1) * TEX, r.y * TEX), Vector2((r.x + 1) * TEX, (r.y + 1) * TEX), Vector2(r.x * TEX, (r.y + 1) * TEX)]
	elif L.n:
		path = "res://assets/tiles/%s_%02d.png" % [L.top, int(hash01(x, y) * L.n) % L.n]
	var grow := 1.015 if seamless else 1.0  # a hair larger so neighbours overlap and no gaps show
	var tc := (top_t + top_r + top_b + top_l) / 4.0
	var top := _poly([tc + (top_t - tc) * grow, tc + (top_r - tc) * grow, tc + (top_b - tc) * grow, tc + (top_l - tc) * grow], path, top_uv, Color.WHITE)
	if seamless:
		top.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if B.map.get("smooth"):  # shade by slope: light comes from behind, so slopes rising toward the viewer are brighter
		var sx: float = ((ch[1] + ch[2]) - (ch[0] + ch[3])) / 2.0
		var sy: float = ((ch[2] + ch[3]) - (ch[0] + ch[1])) / 2.0
		var lit := clampf(.9 + SLOPE_SHADE * (sx + sy), .55, 1.0)
		top.color = Color(lit, lit, lit * .98)
	if L.has("water"):
		top.material = _water_mats[L.water]
	elif L.get("lava"):
		top.material = _lava_mat
	n.add_child(top)
	if B.map.get("shadows") and not B.map.get("smooth") and h > 0:  # raised tiles cast a soft shadow onto the ground
		var sh := Sprite2D.new()
		sh.texture = tex("res://assets/fx/shadow.png")
		sh.scale = Vector2(1.5, .75)
		sh.position = Vector2(8, ty + TH * .8 + depth * .1)
		sh.modulate = Color(0, 0, 0, .35)
		sh.z_index = -1
		n.add_child(sh)
		n.move_child(sh, 0)
	if B.map.get("tufts") and t.t == "g" and hash01(x, y, 20) < .5:  # standing grass on some tiles
		var tf := Sprite2D.new()
		tf.texture = tex("res://assets/props/tuft_%d.png" % (int(hash01(x, y, 21) * 4) % 4))
		tf.offset = Vector2(0, -tf.texture.get_height() / 2.0 + 4)
		tf.position = Vector2((hash01(x, y, 22) - .5) * 26, ty + (hash01(x, y, 23) - .5) * 10)
		tf.scale = Vector2.ONE * (.7 + hash01(x, y, 24) * .3)
		tf.flip_h = hash01(x, y, 25) > .5
		n.add_child(tf)
	if not seamless:  # soft grid line, like the tile seams in the art (grass has none)
		var edge := Line2D.new()
		edge.points = PackedVector2Array([top_t, top_r, top_b, top_l, top_t])
		edge.width = 1.0
		edge.default_color = Color(0.05, 0.06, 0.02, .22)
		n.add_child(edge)
	# overlays: highlight, area pulse, cursor
	var hlp := Polygon2D.new()
	hlp.name = "HL"
	hlp.polygon = PackedVector2Array([top_t, top_r, top_b, top_l])
	hlp.visible = false
	n.add_child(hlp)
	var cur := Line2D.new()
	cur.name = "Cursor"
	cur.points = PackedVector2Array([top_t, top_r, top_b, top_l, top_t])
	cur.width = 2.0
	cur.default_color = Color("#fff1b0")
	cur.visible = false
	n.add_child(cur)
	if L.get("tree"):
		var tree := Sprite2D.new()
		tree.texture = tex("res://assets/props/tree.png")
		tree.offset = Vector2(0, -tree.texture.get_height() / 2.0 + 6)
		tree.position = Vector2((hash01(x, y, 5) - .5) * 6, ty)
		tree.scale = Vector2.ONE * (.62 + hash01(x, y, 6) * .12)
		tree.flip_h = hash01(x, y, 7) > .5
		n.add_child(tree)
	for p in B.map.get("props", []):
		if p.x == x and p.y == y:
			_add_prop(n, p.k, ty, x, y)
	if L.get("lava"):
		var light := PointLight2D.new()
		light.texture = tex("res://assets/fx/soft_dot.png")
		light.texture_scale = 3.2
		light.color = Color(1, .55, .2)
		light.energy = .9
		light.position = Vector2(0, ty)
		n.add_child(light)
	n.set_meta("outline", PackedVector2Array([top_t, top_r, bot_r, bot_b, bot_l, top_l]))
	n.set_meta("top", ty)
	return n


## Open sky: a puff of cloud that bobs. Neighbouring islands rise out of it.
func _make_cloud(n: Node2D, x: int, y: int) -> void:
	n.set_meta("outline", PackedVector2Array())
	n.set_meta("top", 0.0)
	var hlp := Polygon2D.new()  # keeps the highlight and cursor code uniform; never shown
	hlp.name = "HL"
	hlp.visible = false
	n.add_child(hlp)
	var cur := Line2D.new()
	cur.name = "Cursor"
	cur.visible = false
	n.add_child(cur)
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
			var t = Rules.tile_at(B, xx, yy)
			if t != null and t.t != "v":
				return true
	return false


## Hub props, drawn in code (no art yet): the portal obelisk and glowing crystal clusters.
func _add_prop(n: Node2D, kind: String, ty: float, x: int, y: int) -> void:
	var glow := Sprite2D.new()
	glow.texture = tex("res://assets/fx/soft_dot.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.modulate = Color(.55, .8, 1, .55)
	var shards: Array = []
	if kind == "obelisk":
		shards = [[0.0, 52.0, 7.0]]
		glow.position = Vector2(0, ty - 30)
		glow.scale = Vector2.ONE * 1.5
		var plinth := Polygon2D.new()
		plinth.polygon = PackedVector2Array([Vector2(0, ty - 9), Vector2(20, ty), Vector2(0, ty + 9), Vector2(-20, ty)])
		plinth.color = Color("#c9ccd6")
		n.add_child(plinth)
	else:
		shards = [[-6.0, 16.0, 4.0], [3.0, 24.0, 5.0], [9.0, 12.0, 3.5]]
		glow.position = Vector2(0, ty - 12)
		glow.scale = Vector2.ONE * .7
	n.add_child(glow)
	for s in shards:
		var cx: float = s[0]
		var h: float = s[1]
		var w: float = s[2]
		var base := Vector2(cx, ty + 2)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w, -h * .75), base + Vector2(0, -h), base + Vector2(w, -h * .75), base + Vector2(w, 0)])
		body.color = Color("#9fd4ff")
		n.add_child(body)
		var lit := Polygon2D.new()
		lit.polygon = PackedVector2Array([base + Vector2(0, 0), base + Vector2(0, -h), base + Vector2(w, -h * .75), base + Vector2(w, 0)])
		lit.color = Color("#d9f0ff")
		n.add_child(lit)


func _poly(pts: Array, path: String, uv: Array, tint: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.uv = PackedVector2Array(uv)
	p.texture = tex(path)
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	p.color = tint
	return p


# ---------- units ----------
func view_of(u: Dictionary) -> UnitView:
	return views.get(u.id)


## Places unit nodes from their visual positions (vx, vy, vh).
func sync_units(force := false) -> void:
	for u in B.units:
		var v: UnitView = views[u.id]
		v.visible = not u.jailed or u.get("flying", false)
		v.position = ground(u.vx, u.vy) + Vector2(0, .1)
		if B.map.get("smooth"):
			u.vh = terrain_h(u.vx, u.vy)  # walk up and down the slopes
		v.set_height(u.vh, u.get("hop", 0.0), HS)
		if not u.ko:
			v.face(screen_dir(u.f))
		var t = Rules.tile_at(B, roundi(u.vx), roundi(u.vy))
		v.set_wading(t != null and Data.TERRAIN[t.t].get("water") and absf(u.vx - roundi(u.vx)) < .2 and absf(u.vy - roundi(u.vy)) < .2)
		if force:
			v.refresh()
	_sync_objs()


## Vessel objects: a gold diamond that bobs over its tile. Placeholder until there is art for it.
func _sync_objs() -> void:
	var live := {}
	for o in B.get("objs", []):
		live[o.id] = true
		if not obj_nodes.has(o.id):
			var n := Polygon2D.new()
			n.polygon = PackedVector2Array([Vector2(0, -9), Vector2(6, 0), Vector2(0, 9), Vector2(-6, 0)])
			n.color = Color("#ffd36a")
			field.add_child(n)
			obj_nodes[o.id] = n
		var t = Rules.tile_at(B, o.x, o.y)
		obj_nodes[o.id].position = iso(o.x, o.y, t.h) + Vector2(0, -12 + sin(_clock * 2.5 + o.x * 2 + o.y) * 2)
	for id in obj_nodes.keys():
		if not live.has(id):
			obj_nodes[id].queue_free()
			obj_nodes.erase(id)


func set_active(u) -> void:
	if active != null and views.has(active.id):
		views[active.id].set_active(false)
	active = u
	if u != null:
		views[u.id].set_active(true)


## Units drawn in front of the active unit that cover it turn see-through.
func _fade_blockers(delta: float) -> void:
	var av: UnitView = views.get(active.id) if active != null else null
	var focus := Rect2()
	if av != null and av.visible:
		focus = av.body_rect()
		focus = focus.grow_individual(-focus.size.x * .2, 0, -focus.size.x * .2, 0)  # ignore edge overlaps
	for id in views:
		var v: UnitView = views[id]
		var covers := av != null and v != av and v.position.y > av.position.y and v.body_rect().intersects(focus)
		v.fade_to(BLOCKER_ALPHA if covers else 1.0, delta)


# ---------- camera ----------
func center_on(x: float, y: float, instant := false) -> void:
	var t = Rules.tile_at(B, roundi(x), roundi(y))
	# keep the unit in the open band between the top bar and the bottom windows
	var p := iso(x, y, terrain_h(x, y)) + Vector2(0, 14 / cam.zoom.y)
	cam.position = p
	if instant:
		cam.reset_smoothing()


func zoom_by(f: float, at = null) -> void:
	var z := clampf(cam.zoom.x * f, min_zoom, max_zoom)
	cam.zoom = Vector2(z, z)


func rotate_view(dir: int) -> void:
	var a = active if active != null else {"vx": B.map.w / 2.0, "vy": B.map.d / 2.0}
	rot = (rot + dir + 4) % 4
	rebuild()
	center_on(a.vx, a.vy, true)


## Opening shot: the whole map, then ease in to normal zoom.
func intro(dur := 1.2) -> void:
	var z := cam.zoom.x
	cam.zoom = Vector2.ONE * min_zoom
	center_on(B.map.w / 2.0, B.map.d / 2.0, true)
	var tw := create_tween()
	tw.tween_interval(.5)
	tw.tween_property(cam, "zoom", Vector2.ONE * z, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func _process(delta: float) -> void:
	_clock += delta
	if B.is_empty():
		return
	sync_units()
	_fade_blockers(delta)
	var pulse := .3 + sin(_clock * 6.5) * .14
	for k in area:
		if blocks.has(k):
			blocks[k].get_node("HL").color = Color(1, .85, .35, pulse)
	if _shake > 0:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = max(0.0, _shake - delta * 30)
	else:
		cam.offset = Vector2.ZERO
	for i in _arrows.size():
		var a: Node2D = _arrows[i]
		a.position = a.get_meta("base") + a.get_meta("dir") * (sin(_clock * 5) * 1.5)


# ---------- highlights ----------
func set_highlights(h: Dictionary, a := {}) -> void:
	hl = h
	area = a
	_apply_hl()


func set_cursor(c) -> void:
	if cursor != null and blocks.has(Rules.key(cursor[0], cursor[1])):
		blocks[Rules.key(cursor[0], cursor[1])].get_node("Cursor").visible = false
	cursor = c
	if c != null and blocks.has(Rules.key(c[0], c[1])):
		blocks[Rules.key(c[0], c[1])].get_node("Cursor").visible = true


func _apply_hl() -> void:
	for k in blocks:
		var p: Polygon2D = blocks[k].get_node("HL")
		if area.has(k):
			p.visible = true
		elif hl.has(k):
			p.visible = true
			p.color = hl[k]
		else:
			p.visible = false
	set_cursor(cursor)


## Gold arrows on the four sides of a unit for choosing a facing.
func show_facing(u: Dictionary) -> void:
	hide_facing()
	for f in 4:
		var d: Array = Rules.DIRS[f]
		var sd := screen_dir(f).normalized()
		var base := iso(u.x, u.y, u.vh) + Vector2(sd.x * 30, sd.y * 30) - Vector2(0, 2)
		var arrow := Polygon2D.new()
		var side := Vector2(-sd.y, sd.x)
		arrow.polygon = PackedVector2Array([sd * 11, -sd * 4 + side * 8, -sd * 1, -sd * 4 - side * 8])
		arrow.color = Color("#ffd36a") if u.f == f else Color(1, 1, 1, .75)
		arrow.position = base
		arrow.set_meta("base", base)
		arrow.set_meta("dir", sd)
		var line := Line2D.new()
		line.points = PackedVector2Array([sd * 11, -sd * 4 + side * 8, -sd * 1, -sd * 4 - side * 8, sd * 11])
		line.width = 1.5
		line.default_color = Color(0.2, 0.12, 0.02)
		arrow.add_child(line)
		arrow.z_index = 30
		fx.add_child(arrow)
		_arrows.append(arrow)


func hide_facing() -> void:
	for a in _arrows:
		a.queue_free()
	_arrows = []


# ---------- effects ----------
func _particles(at: Vector2, col: Color, kind: String) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.texture = tex("res://assets/fx/spark.png" if kind == "hit" else "res://assets/fx/soft_dot.png")
	p.amount = 18 if kind == "hit" else 26
	p.lifetime = .55 if kind == "hit" else .9
	p.spread = 180
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 50 if kind == "hit" else 20
	p.initial_velocity_max = 120 if kind == "hit" else 60
	p.gravity = Vector2(0, 160) if kind == "hit" else Vector2(0, -60)
	p.scale_amount_min = .12 if kind == "hit" else .08
	p.scale_amount_max = .3 if kind == "hit" else .22
	var g := Gradient.new()
	g.set_color(0, Color(col.lightened(.5), 1))
	g.set_color(1, Color(col, 0))
	p.color_ramp = g
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _ring(at: Vector2, col: Color, size := 1.0, dur := .5) -> void:
	var s := Sprite2D.new()
	s.texture = tex("res://assets/fx/ring.png")
	s.position = at
	s.scale = Vector2(.1, .05) * size
	s.modulate = col
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	fx.add_child(s)
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2(.62, .31) * size, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)


## Hit or spell burst on a tile.
func burst(x: float, y: float, col: Color, kind: String) -> void:
	var t = Rules.tile_at(B, x, y)
	var at := iso(x, y, terrain_h(x, y)) - Vector2(0, 18)
	_particles(at, col, kind)
	_ring(iso(x, y, terrain_h(x, y)), col, 1.0 if kind == "hit" else 1.3)


## Rotating rune circle under a caster.
func spell_circle(u: Dictionary, col: Color) -> void:
	var s := Sprite2D.new()
	s.texture = tex("res://assets/fx/ring.png")
	s.position = iso(u.x, u.y, u.vh)
	s.scale = Vector2(.55, .275)
	s.modulate = Color(col, 0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.z_index = -1
	fx.add_child(s)
	var inner := Sprite2D.new()
	inner.texture = s.texture
	inner.scale = Vector2(.6, .6)
	inner.modulate = Color(1, 1, 1, .6)
	inner.material = m
	s.add_child(inner)
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 1.0, .15)
	tw.tween_interval(.45)
	tw.tween_property(s, "modulate:a", 0.0, .3)
	tw.tween_callback(s.queue_free)
	_particles(s.position - Vector2(0, 10), col, "mag")


func float_text(u: Dictionary, text: String, col: Color, big := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22 if big else 17)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 30)
	l.pivot_offset = Vector2(60, 15)
	var base := iso(u.vx, u.vy, u.vh) - Vector2(60, 92)
	l.position = base
	l.z_index = 60
	l.scale = Vector2(.4, .4)
	fx.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15) if big else Vector2.ONE, .12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, .08)
	tw.parallel().tween_property(l, "position:y", base.y - 26, .9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, .25)
	tw.tween_callback(l.queue_free)


# ---------- ambience ----------
func _build_ambient(kind: String) -> void:
	for c in ambient.get_children():
		c.queue_free()
	var size := Vector2((B.map.w + B.map.d) * TW, (B.map.w + B.map.d) * TH)
	var center := ground(B.map.w / 2.0 - .5, B.map.d / 2.0 - .5) - Vector2(0, 30)
	var p := CPUParticles2D.new()
	p.position = center
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size / 2
	p.texture = tex("res://assets/fx/soft_dot.png")
	p.local_coords = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	var g := Gradient.new()
	match kind:
		"pollen":
			p.amount = 40
			p.lifetime = 9
			p.gravity = Vector2(6, -3)
			p.initial_velocity_min = 2
			p.initial_velocity_max = 8
			p.scale_amount_min = .04
			p.scale_amount_max = .08
			g.colors = PackedColorArray([Color(1, 1, .8, 0), Color(1, 1, .8, .55), Color(1, 1, .8, 0)])
			g.offsets = PackedFloat32Array([0, .5, 1])
			_cloud_shadows(center, size)
		"sky":
			p.amount = 28
			p.lifetime = 10
			p.gravity = Vector2(-5, -4)
			p.initial_velocity_min = 2
			p.initial_velocity_max = 7
			p.scale_amount_min = .03
			p.scale_amount_max = .07
			g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, .97, .85, .6), Color(1, 1, 1, 0)])
			g.offsets = PackedFloat32Array([0, .5, 1])
		"embers":
			p.amount = 60
			p.lifetime = 3.5
			p.gravity = Vector2(3, -26)
			p.emission_rect_extents = Vector2(size.x * .2, size.y * .2)
			p.position = _lava_center()
			p.initial_velocity_min = 4
			p.initial_velocity_max = 14
			p.scale_amount_min = .03
			p.scale_amount_max = .07
			g.colors = PackedColorArray([Color(1, .8, .3, 0), Color(1, .55, .15, .95), Color(.8, .2, .05, 0)])
			g.offsets = PackedFloat32Array([0, .25, 1])
		"fireflies":
			p.amount = 30
			p.lifetime = 7
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 3
			p.initial_velocity_max = 10
			p.spread = 180
			p.scale_amount_min = .05
			p.scale_amount_max = .09
			g.colors = PackedColorArray([Color(.8, 1, .4, 0), Color(.85, 1, .45, .95), Color(.8, 1, .4, .2), Color(.85, 1, .45, .9), Color(.8, 1, .4, 0)])
			g.offsets = PackedFloat32Array([0, .2, .5, .75, 1])
			_mist(center, size)
	p.color_ramp = g
	p.z_index = 20
	ambient.add_child(p)
	p.emitting = true
	p.preprocess = p.lifetime


func _lava_center() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for y in B.map.d:
		for x in B.map.w:
			if B.map.tiles[y][x].t == "l":
				sum += ground(x, y)
				n += 1
	return sum / max(1, n) - Vector2(0, 10)


func _drifter(center: Vector2, size: Vector2, col: Color, scale: Vector2, speed: float, z: int) -> void:
	var s := Sprite2D.new()
	s.texture = tex("res://assets/fx/soft_dot.png")
	s.modulate = col
	s.scale = scale
	s.z_index = z
	var x0 := center.x - size.x * .7
	var x1 := center.x + size.x * .7
	s.position = Vector2(randf_range(x0, x1), center.y + randf_range(-size.y, size.y) * .4)
	ambient.add_child(s)
	var tw := create_tween().set_loops()
	var span := x1 - x0
	tw.tween_property(s, "position:x", x1, (x1 - s.position.x) / speed)
	tw.tween_callback(func(): s.position.x = x0)
	tw.tween_property(s, "position:x", x1, span / speed)


func _cloud_shadows(center: Vector2, size: Vector2) -> void:
	for i in 3:
		_drifter(center, size, Color(0, 0, 0, .10), Vector2(9, 4.5), 9.0, 15)


func _mist(center: Vector2, size: Vector2) -> void:
	for i in 5:
		_drifter(center, size, Color(.75, .9, .85, .07), Vector2(10, 3), 6.0, 25)


# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if B.is_empty():
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_drag = [e.position, cam.position]
				_moved = false
			elif _touches.size() == 2:
				var ps: Array = _touches.values()
				_pinch = {"d": max(1.0, ps[0].distance_to(ps[1])), "z": cam.zoom.x}
				_moved = true
		else:
			_touches.erase(e.index)
			if _touches.size() < 2:
				_pinch = null
			if _touches.is_empty() and _drag != null and not _moved:
				_tap(e.position)
			if _touches.is_empty():
				_drag = null
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() == 2 and _pinch != null:
			var ps: Array = _touches.values()
			var z := clampf(_pinch.z * ps[0].distance_to(ps[1]) / _pinch.d, min_zoom, max_zoom)
			cam.zoom = Vector2(z, z)
		elif _drag != null and _touches.size() == 1:
			var dv: Vector2 = e.position - _drag[0]
			if absf(dv.x) + absf(dv.y) > 8:
				_moved = true
			if _moved:
				cam.position = _drag[1] - dv / cam.zoom.x
				cam.reset_smoothing()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(1.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else .9)
	elif e is InputEventMagnifyGesture:
		zoom_by(e.factor)


func screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _tap(screen_pos: Vector2) -> void:
	var t = pick(screen_to_world(screen_pos))
	if t != null:
		set_cursor(t)
		tile_tapped.emit(t[0], t[1])


var _marker: Node2D = null


## A ring on the ground at a chosen spot (move destination or aim point); null hides it.
func set_marker(p, col := Color("#ffe9a0")) -> void:
	if _marker == null:
		_marker = Sprite2D.new()
		_marker.texture = tex("res://assets/fx/ring.png")
		_marker.scale = Vector2(.32, .16)
		_marker.z_index = 35
		fx.add_child(_marker)
	_marker.visible = p != null
	if p != null:
		var t = Rules.tile_at(B, p[0], p[1])
		_marker.position = iso(p[0], p[1], terrain_h(p[0], p[1]))
		_marker.modulate = col


## Tile under a world point: units first (they stand above their tiles), then the
## front-most tile block.
func pick(p: Vector2) -> Variant:
	var hit = null
	var best := -1.0
	for u in B.units:
		if u.jailed:
			continue
		var feet := iso(u.vx, u.vy, u.vh)
		if absf(p.x - feet.x) < 13 and p.y < feet.y + 6 and p.y > feet.y - 62:
			var r := rot_xy(u.x, u.y)
			if r.x + r.y > best:
				best = r.x + r.y
				hit = [u.x, u.y]
	if hit != null:
		return hit
	var order: Array = blocks.keys()
	order.sort_custom(func(a, b): return blocks[a].position.y > blocks[b].position.y)
	for k in order:
		var blk: Node2D = blocks[k]
		if Geometry2D.is_point_in_polygon(p - blk.position, blk.get_meta("outline")):
			var parts: PackedStringArray = k.split(",")
			var tx := parts[0].to_int()
			var ty := parts[1].to_int()
			# Where on the tile's top: undo the iso projection, then the view rotation.
			var l: Vector2 = p - blk.position - Vector2(0, blk.get_meta("top"))
			var ru := clampf((l.x / TW + l.y / TH) / 2.0, -.49, .49)
			var rv := clampf((l.y / TH - l.x / TW) / 2.0, -.49, .49)
			var d := Vector2(ru, rv)
			match rot:
				1: d = Vector2(rv, -ru)
				2: d = Vector2(-ru, -rv)
				3: d = Vector2(-rv, ru)
			return [tx + d.x, ty + d.y]
	return null
