class_name TileHighlights
extends Node
## Neon-blue overlays on tile tops (shaders/tile_highlight.gdshader), drawn into the Terrain so they
## sit on the ground under the units. Several kinds can show at once; each region glows along its
## outer border. Re-attaches itself when the terrain is rebuilt (view rotation).

enum Kind {
	MOVE,    ## where the unit can walk
	REACH,   ## where an attack or skill can be aimed (its footprint)
	AREA,    ## what the aimed attack or skill would hit
	AIM,     ## the aimed tile
	SUMMON,  ## relic props the King can summon onto
}

## Look of each kind: [tint, fill, edge, hatch, pulse, brackets]. All in the blue family.
const LOOK := {
	Kind.MOVE: [Color(0.05, 0.45, 1.0), 0.30, 0.95, 0.0, 0.0, 0.0],
	Kind.REACH: [Color(0.18, 0.28, 1.0), 0.22, 0.95, 1.0, 0.0, 0.0],
	Kind.AREA: [Color(0.30, 0.80, 1.0), 0.40, 1.0, 0.0, 1.0, 0.0],
	Kind.AIM: [Color(0.85, 0.97, 1.0), 0.20, 1.0, 0.0, 0.5, 1.0],
	Kind.SUMMON: [Color(0.35, 0.95, 0.95), 0.26, 1.0, 0.0, 0.8, 0.0],
}

var terrain: Terrain
var cells := {}  ## Kind -> Array[Vector2i]
var _nodes := {}  ## Kind -> Array[Polygon2D]
var _materials := {}  ## Kind -> ShaderMaterial
var _white: ImageTexture  ## 1x1: Polygon2D divides UVs by its texture size, so this keeps them 0..1


func _init(t: Terrain = null) -> void:
	terrain = t


func _ready() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)
	var shader := load("res://shaders/tile_highlight.gdshader")
	for k in LOOK:
		var m := ShaderMaterial.new()
		m.shader = shader
		var l: Array = LOOK[k]
		m.set_shader_parameter("tint", l[0])
		m.set_shader_parameter("fill", l[1])
		m.set_shader_parameter("edge", l[2])
		m.set_shader_parameter("hatch", l[3])
		m.set_shader_parameter("pulse", l[4])
		m.set_shader_parameter("brackets", l[5])
		_materials[k] = m
	terrain.rebuilt.connect(_redraw_all)


## Shows `kind` on these cells (replacing what that kind showed before).
func show_cells(kind: Kind, list: Array) -> void:
	var typed: Array[Vector2i] = []
	typed.assign(list)
	cells[kind] = typed
	_draw(kind)


func clear(kind: Kind) -> void:
	show_cells(kind, [])


func clear_all() -> void:
	for k in LOOK:
		clear(k)


func shown(kind: Kind) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(cells.get(kind, []))
	return out


## Which edges of `c`'s top face are on the border of `region` under view rotation `rot`, as a Color:
## r = top-right edge, g = bottom-right, b = bottom-left, a = top-left (1 = border).
static func edge_flags(region: Dictionary, c: Vector2i, rot: int, w: int, d: int) -> Color:
	var f := [1.0, 1.0, 1.0, 1.0]
	for dir in TacticalMath.ORTHOGONAL:
		var r := IsoProjection.rotate(Vector2(c + dir), rot, w, d) - IsoProjection.rotate(Vector2(c), rot, w, d)
		var v := Vector2i(roundi(r.x), roundi(r.y))
		var i := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)].find(v)
		if i >= 0 and region.has(c + dir):
			f[i] = 0.0
	return Color(f[0], f[1], f[2], f[3])


func _redraw_all() -> void:
	for k in cells:
		_draw(k)


func _draw(kind: Kind) -> void:
	for n in _nodes.get(kind, []):
		if is_instance_valid(n):
			n.queue_free()
	var made: Array = []
	var region := {}
	for c in cells.get(kind, []):
		region[c] = true
	for c in cells.get(kind, []):
		var b := terrain.block(c)
		if b == null or not b.has_meta("top_poly"):
			continue
		var p := Polygon2D.new()
		p.polygon = b.get_meta("top_poly")
		p.texture = _white
		p.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		p.color = edge_flags(region, c, terrain.rot, terrain.map.w, terrain.map.d)
		p.material = _materials[kind]
		# drawn as the last child of its tile block: over that tile's top, under anything in front of it
		p.name = "HL_%s" % Kind.keys()[kind]
		b.add_child(p)
		made.append(p)
	_nodes[kind] = made
