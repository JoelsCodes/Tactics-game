class_name LastBenedictionBoard
extends Node3D
## The Last Benediction: the owner's 3D cathedral battlefield (Nov 2026) built from its GLB and navigation JSON.
##
## The 11x11 tactical grid is the combat grid (`grid`, a TacticalGrid, so every movement rule is the existing one); the cathedral around it is
## scenery: visual only, no collision, no navigation. The scene is scaled from the GLB's 1.24-unit tiles to 1-unit tiles.
##
## Cells: cell (x, y) is the navigation JSON's tile (x = column, y = row = the GLB's `playable floor XX-YY`). Its centre in this scene is
## (x + 0.5, top height, 10.5 - y): the GLB's own orientation, not mirrored (the combat board's y runs the other way; this scene is separate).
##
## What it builds: the 121 playable floors as separate meshes, each with a StaticBody3D slab (the only collision); every other mesh (about
## two thousand: walls, props, banners, crystals) merged into one mesh per material, with tangents; an isometric camera; a sun and ambient light.

const GLB := "res://art_src/environment/last_benediction/last_benediction.glb"
const NAV := "res://data/environment/last_benediction_nav.json"
const GLB_TILE := 1.24          ## the GLB's distance between two floor centres
const SIZE := 11
const FLOOR_LAYER := 1          ## physics layer of the playable floors (the scenery has none)
const PROBE_LAYER := 2          ## temporary: the occlusion survey's scenery colliders
const DEFAULT_VIEW := 3          ## the camera corner used by default (see set_view): the one with the least scenery in front of the floors
const ISO_PITCH := 35.264       ## the camera's true isometric pitch, in degrees

var nav: Dictionary = {}
var grid: TacticalGrid
var floors := {}                ## Vector2i -> MeshInstance3D, the playable floor of each cell
var tops := {}                  ## Vector2i -> float, the height of each cell's floor surface in this scene
var scenery_meshes := 0         ## meshes in the GLB that are not playable floors, before merging
var merged: Array[MeshInstance3D] = []
var triangles := 0
var camera: Camera3D
var view_corner := DEFAULT_VIEW
var sun: DirectionalLight3D


func build() -> bool:
	nav = JSON.parse_string(FileAccess.get_file_as_string(NAV))
	if nav == null or nav.get("tiles", []).size() != SIZE * SIZE:
		push_error("last benediction: the navigation JSON is missing or not 11x11")
		return false
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		push_error("last benediction: the GLB did not load")
		return false
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return false
	var visual: Array[MeshInstance3D] = []
	for c in root.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi: MeshInstance3D = c
		var m := RegEx.create_from_string("^playable floor (\\d\\d)-(\\d\\d)$").search(String(mi.name))
		if m:
			_keep_floor(mi, Vector2i(int(m.get_string(1)), int(m.get_string(2))))
		else:
			visual.append(mi)
	scenery_meshes = visual.size()
	_merge(root, visual)
	root.name = "Cathedral"
	root.scale = Vector3.ONE / GLB_TILE
	root.position = Vector3(SIZE * 0.5, 0, SIZE * 0.5)
	add_child(root)
	_build_grid()
	_build_camera()
	_build_light()
	return true


func _keep_floor(mi: MeshInstance3D, cell: Vector2i) -> void:
	floors[cell] = mi
	var body := StaticBody3D.new()
	body.name = "FloorBody"
	body.collision_layer = FLOOR_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var aabb := mi.mesh.get_aabb()
	box.size = aabb.size
	shape.shape = box
	shape.position = aabb.get_center()
	body.add_child(shape)
	mi.add_child(body)
	tops[cell] = (mi.position.y + aabb.end.y) / GLB_TILE  # the floor node's height plus its slab's top, in this scene's units


## Merges every non-floor mesh into one mesh per material (about thirty draw calls instead of two thousand). They get no collision.
func _merge(root: Node3D, visual: Array[MeshInstance3D]) -> void:
	var batches := {}
	for mi in visual:
		if mi.mesh == null:
			continue
		var xf := mi.transform  # the GLB's meshes are direct children of its root
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if not batches.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				if mat:
					st.set_material(mat)
				batches[mat] = st
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
		var out := MeshInstance3D.new()
		out.mesh = st.commit()
		out.name = "Scenery %s" % (mat.resource_name if mat and mat.resource_name != "" else "default")
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(out)  # no collision: NONPLAY scenery and props are visual only
		merged.append(out)


func _build_grid() -> void:
	var rows: Array = []
	var by_cell := {}
	for t in nav.tiles:
		by_cell[Vector2i(int(t.x), int(t.y))] = t
	for y in SIZE:
		var row: PackedStringArray = []
		for x in SIZE:
			row.append("g%d" % int(by_cell[Vector2i(x, y)].elevation))
		rows.append(" ".join(row))
	grid = TacticalGrid.from_rows(rows)  # the existing grid and its movement rules (step_cost, reachable)
	for t in nav.tiles:
		if t.blocked:
			grid.add_obstacle(Vector2i(int(t.x), int(t.y)))


## The centre of a cell's floor surface in this scene.
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, tops.get(c, 0.0), SIZE + 0.5 - 1.0 - c.y)


## A 2D sprite unit (the project's own UnitView3D) standing on a cell and registered on the combat grid. The sprite is stretched by 1 / cos(pitch)
## on Y, as the combat board does, so it keeps its drawn proportions on screen while it stays vertical.
func place_unit(character: String, cell: Vector2i, team := 0) -> UnitView3D:
	var u := UnitView3D.new()
	add_child(u)
	u.setup(character)
	u.fit(1.0 / cos(deg_to_rad(ISO_PITCH)))
	u.position = cell_to_world(cell)
	grid.place(u, cell, team)
	return u


## Which floors scenery stands in front of, from the camera's current corner. The scenery has no collision, so this adds temporary trimesh
## colliders to it on their own layer, casts a ray along the view into each floor's centre, and removes them again. A hit nearer than the floor by
## more than `margin` counts (floor decals and trim lie within it). Needs the board in the tree; awaits two physics frames.
func covered_tiles(margin := 0.12) -> Array[Vector2i]:
	var probes: Array[StaticBody3D] = []
	for m in merged:
		var body := StaticBody3D.new()
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = m.mesh.create_trimesh_shape()
		body.add_child(shape)
		m.add_child(body)
		probes.append(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var dir: Vector3 = -camera.global_transform.basis.z
	var out: Array[Vector2i] = []
	for c in floors:
		var target := cell_to_world(c)
		var origin := target - dir * 40.0
		var q := PhysicsRayQueryParameters3D.create(origin, target)
		q.collision_mask = PROBE_LAYER
		var hit := space.intersect_ray(q)
		if hit.size() > 0 and origin.distance_to(hit.position) < 40.0 - margin:
			out.append(c)
	for body in probes:
		body.queue_free()
	await get_tree().process_frame
	return out


func objective() -> Vector2i:
	return Vector2i(int(nav.objective[0]), int(nav.objective[1]))


func spawns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for s in nav.player_spawns:
		out.append(Vector2i(int(s[0]), int(s[1])))
	return out


## An isometric tactical camera: orthographic, 45 degrees round and the true isometric pitch (35.264), looking at the middle of the grid.
func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "IsoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	camera.near = 0.1
	camera.far = 80.0
	add_child(camera)
	set_view(view_corner)
	camera.current = true


## Which corner the camera looks from: 0 low x and high z, then a quarter turn each (3 is the default: high x and high z, the spawns' side). The camera never zooms or tilts.
func set_view(corner: int) -> void:
	view_corner = posmod(corner, 4)
	var mid := Vector3(SIZE * 0.5, 0.3, SIZE * 0.5)
	var dir := Vector3(-1, 0, 1).normalized().rotated(Vector3.UP, -PI * 0.5 * view_corner)
	var from := mid + Vector3(dir.x, 0, dir.z) * 30.0 + Vector3(0, 30.0 * tan(deg_to_rad(ISO_PITCH)), 0)
	camera.look_at_from_position(from, mid, Vector3.UP)


func _build_light() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(0.86, 0.84, 1.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.66)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)
