class_name LastBenedictionScenery
extends RefCounted
## The Last Benediction's cathedral from its GLB (the owner's Blender export), ready to place in a scene: scaled to 1-unit tiles and shifted so
## the GLB's tile (col, row) has its centre at (col + 0.5, floor top, 10.5 - row), the GLB's own orientation (not mirrored).
##
## The 121 `playable floor XX-YY` nodes stay separate meshes (optionally each with a StaticBody3D slab: the only collision); every other mesh
## (about two thousand: walls, props, banners, crystals) is merged into one mesh per material, with tangents, and is visual only.
## Used by LastBenedictionBoard (the standalone scene) and Board3D (a map with a "scenery" key, the real battle).

const GLB := "res://art_src/environment/last_benediction/last_benediction.glb"
const GLB_TILE := 1.24          ## the GLB's distance between two floor centres
const SIZE := 11
const FLOOR_LAYER := 1          ## physics layer of the playable floors when they have collision


## {"root": Node3D, "floors": {Vector2i(col, row): MeshInstance3D}, "tops": {Vector2i(col, row): float} (the floor surface's height in the scene's
## units), "merged": Array[MeshInstance3D], "scenery_meshes": int, "triangles": int}; an empty Dictionary if the GLB does not load.
static func build(with_floor_collision := false) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		push_error("last benediction: the GLB did not load")
		return {}
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return {}
	var out := {"root": root, "floors": {}, "tops": {}, "merged": [], "scenery_meshes": 0, "triangles": 0}
	var visual: Array[MeshInstance3D] = []
	var rx := RegEx.create_from_string("^playable floor (\\d\\d)-(\\d\\d)$")
	for c in root.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi: MeshInstance3D = c
		var m := rx.search(String(mi.name))
		if m:
			_keep_floor(out, mi, Vector2i(int(m.get_string(1)), int(m.get_string(2))), with_floor_collision)
		else:
			visual.append(mi)
	out.scenery_meshes = visual.size()
	_merge(out, root, visual)
	root.name = "Cathedral"
	root.scale = Vector3.ONE / GLB_TILE
	root.position = Vector3(SIZE * 0.5, 0, SIZE * 0.5)
	return out


static func _keep_floor(out: Dictionary, mi: MeshInstance3D, cell: Vector2i, with_collision: bool) -> void:
	out.floors[cell] = mi
	var aabb := mi.mesh.get_aabb()
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "FloorBody"
		body.collision_layer = FLOOR_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size
		shape.shape = box
		shape.position = aabb.get_center()
		body.add_child(shape)
		mi.add_child(body)
	out.tops[cell] = (mi.position.y + aabb.end.y) / GLB_TILE  # the floor node's height plus its slab's top, in this scene's units


## Merges every non-floor mesh into one mesh per material (about thirty draw calls instead of two thousand). They get no collision.
static func _merge(out: Dictionary, root: Node3D, visual: Array[MeshInstance3D]) -> void:
	var batches := {}
	var triangles := 0
	for mi in visual:
		if mi.mesh == null:
			continue
		var xf := mi.transform  # the GLB's meshes are direct children of its root
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if not batches.has(mat):
				var nst := SurfaceTool.new()
				nst.begin(Mesh.PRIMITIVE_TRIANGLES)
				if mat:
					nst.set_material(mat)
				batches[mat] = nst
			var st: SurfaceTool = batches[mat]
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: Variant = arrays[Mesh.ARRAY_NORMAL]
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = idx if idx != null else PackedInt32Array(range(verts.size()))
			for i in order:
				st.set_uv(uvs[i] if uvs != null else Vector2.ZERO)  # a surface without UVs (or normals) still writes them, so a material's batch is uniform
				st.set_normal((xf.basis * norms[i]).normalized() if norms != null else Vector3.UP)
				st.add_vertex(xf * verts[i])
			triangles += order.size() / 3
	for mi in visual:
		mi.free()
	for mat in batches:
		var st: SurfaceTool = batches[mat]
		st.index()
		st.generate_tangents()
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.name = "Scenery %s" % (mat.resource_name if mat and mat.resource_name != "" else "default")
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mesh)  # no collision: NONPLAY scenery and props are visual only
		out.merged.append(mesh)
	out.triangles = triangles
