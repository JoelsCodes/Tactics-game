class_name SacredCanalScenery
extends RefCounted
## The Sacred Canal Bridge (the owner's Blender export, Nov 2026) from its GLB, ready to place as a board's scenery (Board3D, a map with "scenery": "sacred_canal").
##
## The owner's navigation file (data/environment/sacred_canal_nav.json, 160 cells: a 6x20 bridge and a 10x4 gate landing) uses x = bridge width and y = toward the gate,
## world (x - 2.5, y + 0.5) in Blender, so in the GLB (Y up) the cell (nx, ny) is centred at (nx - 2.5, 3.46, -(ny + 0.5)). The map (samples/sacred_canal.json) is 10 deep (x,
## up the screen) and 24 long (y, left to right), the fight running from the bridge's far end to the gate landing. The board's cell (bx, by) is the nav cell (7 - bx, by):
## the scene is turned half a circle about the vertical axis (never mirrored) and lowered so the deck's top sits at height 0 (`floor_base` 0).
##
## The deck is flat (all 160 cells are elevation 0), so the board's own heights are the deck's. The deck mesh's top (3.461 in the GLB) is the surface units stand on;
## the owner's JSON quotes 3.5, which is the pavers' crown rather than the mean surface. Everything is visual only (no collision, no navigation): the canal, the parapets,
## the gatehouse, the banks and the outer district are NONPLAY scenery and add no cells. Every mesh is merged into one mesh per material (about fifty draw calls instead of
## 143 meshes / 177 surfaces); the canal keeps the owner's animated water shader (shaders/canal.gdshader, the way godot/check.gd in the owner's package applies it).

const GLB := "res://art_src/environment/sacred_canal/sacred_canal_bridge.glb"
const NAV := "res://data/environment/sacred_canal_nav.json"
const CANAL_SHADER := "res://shaders/canal.gdshader"
const CANAL_MATERIAL := "Canal rippled PBR"
const DECK_MESH := "Bridge deck | narrow hand-laid stone courses"
const NO_NORMAL_SCALE := "Bridge deck | scanned limestone setts"  ## the owner's check leaves this material's normal strength alone
const NORMAL_SCALE := 0.71  ## every other stone's normal strength (godot/check.gd in the owner's package)
const DECK_TOP := 3.461  ## the deck mesh's top in the GLB (measured; `build` reads it from the mesh)
const GATE_SIDE_Z := -23.55  ## GLB z beyond which (the gate facade starts at -23.56, on the landing's far edge at -24) a triangle belongs to the gate side if it stands above the plaza
const GATE_SIDE_ABOVE := 0.35  ## ... by more than this over the deck top
const GATE_VIEW_ROT := 0  ## the Board3D view whose camera sits behind the gate (rot 0: the board is seen from beyond its far end)
const DEPTH := 10
const LENGTH := 24


## {"root": Node3D, "merged": Array[MeshInstance3D], "scenery_meshes": int, "triangles": int, "deck_top": float (GLB units), "canal": int}; an empty Dictionary if the GLB
## does not load.
static func build() -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		push_error("sacred canal: the GLB did not load")
		return {}
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return {}
	var out := {"root": root, "merged": [], "scenery_meshes": 0, "triangles": 0, "deck_top": DECK_TOP, "canal": 0}
	var visual: Array[MeshInstance3D] = []
	for c in root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			visual.append(c)
			if c.name == DECK_MESH:
				out.deck_top = (c as MeshInstance3D).mesh.get_aabb().end.y
	for mi in visual:
		_finish_materials(mi, out)
	out.scenery_meshes = visual.size()
	_merge(out, root, visual)
	root.name = "SacredCanal"
	root.rotation.y = PI  # the board's x runs the other way from the nav's x (depth), and the half turn keeps the art unmirrored
	root.position = Vector3(DEPTH * 0.5, -float(out.deck_top), 0.0)
	return out


## The canal gets the owner's water shader (its ripple normal map is the GLB material's own normal texture); the stones' normals are eased, as in the owner's check.
static func _finish_materials(mi: MeshInstance3D, out: Dictionary) -> void:
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s) as StandardMaterial3D
		if m == null:
			continue
		if m.resource_name == CANAL_MATERIAL and m.normal_texture != null:
			var water := ShaderMaterial.new()
			water.shader = load(CANAL_SHADER)
			water.set_shader_parameter("ripple_normal", m.normal_texture)
			water.resource_name = "canal water"
			mi.set_surface_override_material(s, water)
			out.canal += 1
		elif m.normal_enabled and m.resource_name != NO_NORMAL_SCALE:
			m.normal_scale *= NORMAL_SCALE


## Like LastBenedictionScenery.merge (one mesh per material, tangents, no collision), but every triangle standing above the plaza floor beyond the landing (the gatehouse,
## the chapel facade and the roofs: its centre is past the landing's far edge and higher than the deck) goes to a second set of meshes, out.gate_side. In the one view
## whose camera sits behind the gate those walls stand between it and the landing (19% of the standing cells hidden by measurement), so Board3D hides that set in
## that view (out.view_hidden: {board rot: Array of meshes}); in the other three the gate is the backdrop and stays.
static func _merge(out: Dictionary, root: Node3D, visual: Array[MeshInstance3D]) -> void:
	var batches := [{}, {}]  ## [0] the rest, [1] the gate side: material -> SurfaceTool
	var triangles := 0
	var gate_tris := 0
	var deck: float = out.deck_top
	for mi in visual:
		var xf := mi.transform  # the GLB's meshes are direct children of its root
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: Variant = arrays[Mesh.ARRAY_NORMAL]
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = idx if idx != null else PackedInt32Array(range(verts.size()))
			for t in range(0, order.size() - 2, 3):
				var p0 := xf * verts[order[t]]
				var p1 := xf * verts[order[t + 1]]
				var p2 := xf * verts[order[t + 2]]
				var centre := (p0 + p1 + p2) / 3.0
				var gate := centre.z < GATE_SIDE_Z and centre.y > deck + GATE_SIDE_ABOVE
				var group: Dictionary = batches[1 if gate else 0]
				if gate:
					gate_tris += 1
				if not group.has(mat):
					var nst := SurfaceTool.new()
					nst.begin(Mesh.PRIMITIVE_TRIANGLES)
					if mat:
						nst.set_material(mat)
					group[mat] = nst
				var st: SurfaceTool = group[mat]
				for k in 3:
					var i := order[t + k]
					st.set_uv(uvs[i] if uvs != null else Vector2.ZERO)
					st.set_normal((xf.basis * norms[i]).normalized() if norms != null else Vector3.UP)
					st.add_vertex(xf * verts[i])
				triangles += 1
	for mi in visual:
		mi.free()
	var gate_side: Array[MeshInstance3D] = []
	for g in 2:
		for mat in batches[g]:
			var st: SurfaceTool = batches[g][mat]
			st.index()
			st.generate_tangents()
			var mesh := MeshInstance3D.new()
			mesh.mesh = st.commit()
			mesh.name = "Scenery %s%s" % ["gate " if g == 1 else "", mat.resource_name if mat and mat.resource_name != "" else "default"]
			root.add_child(mesh)  # no collision: the scenery is visual only
			out.merged.append(mesh)
			if g == 1:
				gate_side.append(mesh)
	out.triangles = triangles
	out.gate_triangles = gate_tris
	out.gate_side = gate_side
	out.view_hidden = {GATE_VIEW_ROT: gate_side}
