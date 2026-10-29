class_name TileHighlights
extends Node3D
## Neon-blue floor highlights on the 3D board (shaders/tile_highlight_3d.gdshader): one mesh per kind,
## a quad laid just above each highlighted tile's top. Several kinds can show at once; each region glows
## along its outer border. The board never changes when the view turns, so nothing is rebuilt then.

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
const LIFT := 0.012  ## height above the tile top (each kind a little higher, so they layer)

var board: Board3D
var cells := {}  ## Kind -> Array[Vector2i]
var meshes := {}  ## Kind -> MeshInstance3D
var _materials := {}  ## Kind -> ShaderMaterial


func _init(b: Board3D = null) -> void:
	board = b


func _ready() -> void:
	var shader := load("res://shaders/tile_highlight_3d.gdshader")
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
		m.set_shader_parameter("scanlines", 0.5 if k in [Kind.MOVE, Kind.REACH] else 0.2)
		m.render_priority = k  # later kinds draw over earlier ones
		_materials[k] = m
		var mi := MeshInstance3D.new()
		mi.name = "HL_%s" % Kind.keys()[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		meshes[k] = mi


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


## Which edges of `c` are on the border of `region`, as a Color: r = the -y edge, g = +x, b = +y,
## a = -x (1 = border). Grid space: the view rotation does not matter in 3D.
static func edge_flags(region: Dictionary, c: Vector2i) -> Color:
	var f := []
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		f.append(0.0 if region.has(c + d) else 1.0)
	return Color(f[0], f[1], f[2], f[3])


func _draw(kind: Kind) -> void:
	var mi: MeshInstance3D = meshes.get(kind)
	if mi == null:
		return
	var list: Array = cells.get(kind, [])
	if list.is_empty():
		mi.mesh = null
		return
	var region := {}
	for c in list:
		region[c] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := LIFT * (1 + int(kind))
	for c in list:
		if not board.in_bounds(c):
			continue
		var y := board.top_point(c.x, c.y).y + lift
		var col := edge_flags(region, c)
		var a := Vector3(c.x, y, c.y)
		var b := Vector3(c.x + 1, y, c.y)
		var cc := Vector3(c.x + 1, y, c.y + 1)
		var d := Vector3(c.x, y, c.y + 1)
		for v in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [cc, Vector2(1, 1)], [a, Vector2(0, 0)], [cc, Vector2(1, 1)], [d, Vector2(0, 1)]]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, _materials[kind])
	mi.mesh = mesh
