class_name HollowmarkScenery
extends RefCounted
## The Claude-built Hollowmark maps (Nov 2026) from their Blender GLBs, ready to place as a board's scenery (Board3D, a map whose "scenery" key is in MAPS):
## the Drowned Reliquary (sluice_vault), the Last Terrace Garden, the Night Express passenger car, the dining car and Hollowmark Station.
##
## Every map uses one convention: the board's x (up the screen) is the Blender Y axis (the map's "north"), the board's y is Blender X. In the GLB
## (Y up) a Blender point (X, Y, Z) is (X, Z, -Y); turning the scene -90 degrees about Y and moving it by `offset` puts it on the cells:
## board cell (bx, by) is centred at Blender (by - offset.z + 0.5, bx - offset.x + 0.5). Never mirrored.
##
## What happens at load, for speed without touching the art:
## - meshes the GLB shares between many objects (the gardens' 8000 plant and ivy instances) become one MultiMeshInstance3D per mesh (a draw call per mesh,
##   not per plant); everything else is kept as authored;
## - FX_Water / FX_Waterfall meshes get Godot shaders (shaders/hollowmark_water.gdshader, hollowmark_waterfall.gdshader);
## - the lights, steam/mist puffs and cloud banks Blender rendered come back from <map>_fx.json as OmniLight3D, GPUParticles3D and flat cloud cards;
## - the walls between each quarter-turn camera and the board are split out (by node name, or by triangles beyond a plane) into `view_hidden`.
## Everything is visual only (no collision, no navigation): the cells come from the map's rows.

const DIR := "res://art_src/environment/"
const BATCH_MIN := 6  ## a mesh drawn this many times or more is batched into a MultiMesh

## The four foggy swamps (owner, Nov 23 2026: "4 maps in the day time but a foggy swamp, make each map creepy"): a pale overcast day, a grey-green sky that the
## distance fades into, and height fog lying low on the water (depth fog, not the volumetric haze the graphics quality turns off on prelit maps).
const SWAMP_ENV := {"background_mode": Environment.BG_COLOR, "background_color": Color(0.6, 0.65, 0.62), "ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
	"ambient_light_color": Color(0.72, 0.78, 0.74), "ambient_light_energy": 0.75, "sun_energy": 0.7, "sun_color": Color(0.88, 0.92, 0.88), "glow_intensity": 0.5,
	"fog_enabled": true, "fog_mode": Environment.FOG_MODE_DEPTH, "fog_light_color": Color(0.6, 0.65, 0.62), "fog_light_energy": 1.0, "fog_density": 0.9,
	"fog_depth_begin": 17.0, "fog_depth_end": 50.0, "fog_depth_curve": 1.2, "fog_sky_affect": 1.0, "fog_aerial_perspective": 0.0}
const SWAMP_WATER := {"shallow": Color(0.5, 0.56, 0.36), "deep": Color(0.03, 0.06, 0.04), "glow": Color(0.2, 0.28, 0.12), "absorb_depth": 0.6, "glow_strength": 0.14, "foam_strength": 0.2}
const SWAMP_CLOUD := Color(0.72, 0.77, 0.74)

## per map: glb, offset (Godot), hide-by-name per view (rot -> node name prefixes), hide-by-plane per view (rot -> {axis, beyond (Godot coordinate,
## sign gives the side), above (world height)}), water and environment settings.
const MAPS := {
	"sluice_vault": {"glb": "drowned_reliquary/drowned_reliquary.glb", "offset": Vector3(8, 0, 8),
		"hide": {0: ["cavern east wall"], 1: ["cavern west wall"], 2: ["cavern west", "cavern north-west"], 3: ["cavern back wall", "back wall brick"]},
		"drop": ["stalactite"], "cut_above": 7.0,  # cutaway: the cave ceiling (and what hangs from it) would stand between the tactical camera and the arena in every view
		"planes": {3: {"axis": 0, "beyond": 15.6, "above": 2.2}},  # camera behind the throne: the sluice gateways and the wall above them
		"water": {"shallow": Color(0.24, 0.62, 0.48), "deep": Color(0.02, 0.16, 0.13), "glow": Color(0.1, 0.55, 0.38), "absorb_depth": 2.6, "glow_strength": 0.35},
		"env": {"background_color": Color(0.01, 0.015, 0.015), "ambient_light_color": Color(0.3, 0.42, 0.4), "ambient_light_energy": 0.55, "glow_intensity": 0.9,
			"volumetric_fog_enabled": true, "volumetric_fog_density": 0.014, "volumetric_fog_albedo": Color(0.6, 0.78, 0.74), "sun_energy": 0.12, "background_mode": Environment.BG_COLOR}},
	"last_terrace_garden": {"glb": "last_terrace_garden/last_terrace_garden.glb", "offset": Vector3(7.5, 0, 9.5),
		"hide": {0: ["tree canopy"], 2: ["ruin west"], 3: ["ruin back", "tree canopy"]},
		"water": {"shallow": Color(0.42, 0.66, 0.68), "deep": Color(0.06, 0.2, 0.24), "glow": Color(0.2, 0.4, 0.45), "absorb_depth": 0.9, "glow_strength": 0.12},
		"env": {"glow_intensity": 0.6, "sun_energy": 1.25}},
	"passenger_car": {"glb": "passenger_car/passenger_car.glb", "offset": Vector3(0, 0, 0),
		"planes": {3: {"axis": 0, "beyond": 3.5, "above": 1.3}, 2: {"axis": 2, "beyond": -0.7, "above": 1.3}, 0: {"axis": 2, "beyond": 17.3, "above": 1.3}},
		"env": {"background_color": Color(0.02, 0.025, 0.04), "ambient_light_color": Color(0.55, 0.45, 0.38), "ambient_light_energy": 0.45, "glow_intensity": 0.8, "sun_energy": 0.15, "background_mode": Environment.BG_COLOR}},
	"dining_car": {"glb": "dining_car/dining_car.glb", "offset": Vector3(0, 0, 0),
		"planes": {3: {"axis": 0, "beyond": 8.3, "above": 1.3}, 2: {"axis": 2, "beyond": -0.7, "above": 1.3}},
		"env": {"background_color": Color(0.02, 0.025, 0.04), "ambient_light_color": Color(0.55, 0.45, 0.38), "ambient_light_energy": 0.45, "glow_intensity": 0.8, "sun_energy": 0.15, "background_mode": Environment.BG_COLOR}},
	"colosseum": {"glb": "colosseum/colosseum.glb", "offset": Vector3(11, 0, 11),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 21.6, "above": 1.0}, 0: {"axis": 2, "beyond": 21.6, "above": 1.0}, 2: {"axis": 2, "beyond": -0.4, "above": 1.0}},
		"cut_any_vertex": true,  # the arena wall's long triangles straddle the cut planes: take the whole triangle so no dark shards stay in front of the camera
		"env": {"background_color": Color(0.012, 0.012, 0.016), "ambient_light_color": Color(0.55, 0.5, 0.44), "ambient_light_energy": 0.55, "glow_intensity": 0.8, "sun_energy": 0.9, "background_mode": Environment.BG_COLOR}},
	"star_gazer": {"glb": "star_gazer/star_gazer.glb", "offset": Vector3(9, 0, 11),
		"hide": {0: ["dome"], 2: ["dome"], 3: ["dome", "orrery", "spin orr"]},  # the dome's ribs and glass stand between the camera and the floor in these views; in view 3 the orrery (sun, rings, planets) hangs over the glass floor
		"glass": ["floor glass"],  # the glass disc over the gear pit: a clear Godot glass so the gears read through it
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.7}, 3: {"axis": 0, "beyond": 17.6, "above": 3.0}, 0: {"axis": 2, "beyond": 21.6, "above": 1.7}, 2: {"axis": 2, "beyond": -0.4, "above": 1.7}},
		"cloud_tint": Color(0.42, 0.5, 0.7),
		"env": {"background_color": Color(0.01, 0.015, 0.035), "ambient_light_color": Color(0.32, 0.4, 0.62), "ambient_light_energy": 0.7, "glow_intensity": 0.6, "sun_energy": 0.45, "sun_color": Color(0.6, 0.72, 1.0), "background_mode": Environment.BG_COLOR}},
	"train_station": {"glb": "train_station/train_station.glb", "offset": Vector3(3, 0, 0),
		"planes": {3: {"axis": 0, "beyond": 11.3, "above": 1.7}, 0: {"axis": 2, "beyond": 15.3, "above": 2.3}, 2: {"axis": 2, "beyond": -0.7, "above": 2.3}},
		"env": {"background_color": Color(0.03, 0.04, 0.06), "ambient_light_color": Color(0.42, 0.46, 0.56), "ambient_light_energy": 0.68, "glow_intensity": 0.8, "sun_energy": 0.3, "background_mode": Environment.BG_COLOR}},
	# the three thug hideouts (Nov 2026; built by C:/Users/joele/codex/hollowmark-hideouts/*.py from the grid, so the art sits on the cells)
	"rats_wharf": {"glb": "rats_wharf/rats_wharf.glb", "offset": Vector3(8, 0, 12),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.4}, 3: {"axis": 0, "beyond": 15.6, "above": 3.6}, 0: {"axis": 2, "beyond": 23.6, "above": 2.0}, 2: {"axis": 2, "beyond": -0.4, "above": 2.0}},
		"water": {"shallow": Color(0.3, 0.46, 0.42), "deep": Color(0.05, 0.14, 0.15), "glow": Color(0.2, 0.3, 0.28), "absorb_depth": 1.2, "glow_strength": 0.08},
		"env": {"glow_intensity": 0.5, "sun_energy": 1.25, "sun_color": Color(1.0, 0.95, 0.88)}},  # daytime (owner, Nov 21 2026): the prelit sky, as the garden
	"crooked_cellar": {"glb": "crooked_cellar/crooked_cellar.glb", "offset": Vector3(9, 0, 11),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.6}, 3: {"axis": 0, "beyond": 17.6, "above": 3.2}, 0: {"axis": 2, "beyond": 21.6, "above": 2.2}, 2: {"axis": 2, "beyond": -0.4, "above": 3.6}},
		"water": {"shallow": Color(0.3, 0.36, 0.22), "deep": Color(0.06, 0.1, 0.05), "glow": Color(0.2, 0.22, 0.12), "absorb_depth": 0.8, "glow_strength": 0.08},
		"env": {"glow_intensity": 0.5, "sun_energy": 1.05, "sun_color": Color(1.0, 0.95, 0.88)}},  # daytime: daylight falls in where the vault has gone
	"blackrock_quarry": {"glb": "blackrock_quarry/blackrock_quarry.glb", "offset": Vector3(9, 0, 12),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 17.6, "above": 2.4}, 0: {"axis": 2, "beyond": 23.6, "above": 2.6}, 2: {"axis": 2, "beyond": -0.4, "above": 2.4}},
		"water": {"shallow": Color(0.32, 0.5, 0.46), "deep": Color(0.05, 0.16, 0.16), "glow": Color(0.2, 0.3, 0.28), "absorb_depth": 1.0, "glow_strength": 0.08},
		"env": {"glow_intensity": 0.5, "sun_energy": 1.3, "sun_color": Color(1.0, 0.95, 0.88)}},  # daytime
	# the fourth hideout: a rooftop over a town street (no water); each view cuts away what lies beyond the board's near edge above the edge's own height
	"crows_roost": {"glb": "crows_roost/crows_roost.glb", "offset": Vector3(8, 0, 16),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.4}, 3: {"axis": 0, "beyond": 15.6, "above": 3.4}, 0: {"axis": 2, "beyond": 31.6, "above": 3.8}, 2: {"axis": 2, "beyond": -0.4, "above": 1.4}},
		"env": {"glow_intensity": 0.5, "sun_energy": 1.3, "sun_color": Color(1.0, 0.95, 0.88)}},  # daytime
	# the foggy swamps (Nov 23 2026; C:/Users/joele/codex/hollowmark-hideouts/swamp_kit.py and one script per map): bog water you wade (w), mud (m), deep pools
	"drowned_chapel": {"glb": "drowned_chapel/drowned_chapel.glb", "offset": Vector3(9, 0, 14),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 17.6, "above": 1.4}, 0: {"axis": 2, "beyond": 27.6, "above": 2.4}, 2: {"axis": 2, "beyond": -0.4, "above": 1.0}},
		"water": SWAMP_WATER, "cloud_tint": SWAMP_CLOUD, "env": SWAMP_ENV},
	"hangmans_fen": {"glb": "hangmans_fen/hangmans_fen.glb", "offset": Vector3(9, 0, 13),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 17.6, "above": 1.4}, 0: {"axis": 2, "beyond": 25.6, "above": 1.4}, 2: {"axis": 2, "beyond": -0.4, "above": 1.0}},
		"water": SWAMP_WATER, "cloud_tint": SWAMP_CLOUD, "env": SWAMP_ENV},
	"stilt_hollows": {"glb": "stilt_hollows/stilt_hollows.glb", "offset": Vector3(9, 0, 14),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 17.6, "above": 1.4}, 0: {"axis": 2, "beyond": 27.6, "above": 2.0}, 2: {"axis": 2, "beyond": -0.4, "above": 1.0}},
		"water": SWAMP_WATER, "cloud_tint": SWAMP_CLOUD, "env": SWAMP_ENV},
	"sunken_causeway": {"glb": "sunken_causeway/sunken_causeway.glb", "offset": Vector3(8, 0, 15),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 15.6, "above": 1.4}, 0: {"axis": 2, "beyond": 29.6, "above": 2.0}, 2: {"axis": 2, "beyond": -0.4, "above": 1.0}},
		"water": SWAMP_WATER, "cloud_tint": SWAMP_CLOUD, "env": SWAMP_ENV},
	# the owner's 30 x 30 swamp boss arena (their swamp_boss_map.py) rebuilt to this standard by bog_sanctum.py
	"bog_sanctum": {"glb": "bog_sanctum/bog_sanctum.glb", "offset": Vector3(15, 0, 15),
		"planes": {1: {"axis": 0, "beyond": -0.4, "above": 1.0}, 3: {"axis": 0, "beyond": 29.6, "above": 2.4}, 0: {"axis": 2, "beyond": 29.6, "above": 1.4}, 2: {"axis": 2, "beyond": -0.4, "above": 1.4}},
		"water": SWAMP_WATER, "cloud_tint": SWAMP_CLOUD, "env": SWAMP_ENV},
}


static func has(key: String) -> bool:
	return MAPS.has(key)


## {"root", "view_hidden", "env", "batched_instances", "multimeshes", "meshes", "lights", "puffs", "water", "falls", "triangles"}; empty if the GLB does not load.
static func build(key: String) -> Dictionary:
	var spec: Dictionary = MAPS[key]
	var path: String = DIR + String(spec.glb)
	var glb := _load_glb(path)
	if glb == null:
		return {}
	var root := Node3D.new()
	root.name = "HollowmarkScenery"
	root.rotation.y = -PI / 2.0
	root.position = spec.offset
	var out := {"root": root, "view_hidden": {}, "env": spec.get("env", {}), "batched_instances": 0, "spinners": 0, "multimeshes": 0, "meshes": 0, "lights": 0, "puffs": 0, "water": 0, "falls": 0, "triangles": 0}
	var placed: Array = []  ## [MeshInstance3D source, Transform3D relative to the GLB root]
	_collect(glb, Transform3D.IDENTITY, placed)
	var uses := {}
	for p in placed:
		var m: Mesh = (p[0] as MeshInstance3D).mesh
		uses[m] = int(uses.get(m, 0)) + 1
	var hide: Dictionary = spec.get("hide", {})
	var planes: Dictionary = spec.get("planes", {})
	var water_mat := _water_material(spec.get("water", {}))
	var batches := {}  ## mesh -> Array[Transform3D]
	for p in placed:
		var mi: MeshInstance3D = p[0]
		var xf: Transform3D = p[1]
		var n := String(mi.name).to_lower().replace("_", " ")
		var hidden_in := _hidden_views(n, hide)
		var dropped := false
		for d in spec.get("drop", []):
			dropped = dropped or n.begins_with(String(d))
		if dropped:
			continue
		if n.begins_with("fx waterfall"):
			out.root.add_child(_placed(mi, xf, _waterfall_material(mi.mesh.get_aabb(), xf)))
			out.falls += 1
		elif n.begins_with("fx water"):
			out.root.add_child(_placed(mi, xf, water_mat))
			out.water += 1
		elif n.begins_with("spin"):  # a gear or an orrery ring: turned slowly by a HollowmarkSpinner (rate in the name's last word)
			var sp := _spinner(mi, xf, n)
			out.root.add_child(sp)
			out.spinners += 1
			for r in hidden_in:
				_add_hidden(out, r, sp.get_child(0) as MeshInstance3D)
		elif n.begins_with("sky"):  # the star dome and the far mountains: never cut by a view's plane
			out.root.add_child(_placed(mi, xf, null))
			out.meshes += 1
		elif hidden_in.is_empty() and int(uses[mi.mesh]) >= BATCH_MIN:
			if not batches.has(mi.mesh):
				batches[mi.mesh] = []
			batches[mi.mesh].append(xf)
		elif not planes.is_empty():
			for part in _split(mi, xf, planes, root, float(spec.get("cut_above", 1e9)), bool(spec.get("cut_any_vertex", false))):
				root.add_child(part[0])
				out.meshes += 1
				if part[1] >= 0:
					_add_hidden(out, part[1], part[0])
				for r in hidden_in:
					_add_hidden(out, r, part[0])
		else:
			var copy := _placed(mi, xf, null)
			root.add_child(copy)
			out.meshes += 1
			for r in hidden_in:
				_add_hidden(out, r, copy)
		out.triangles += _tris(mi.mesh)
	for mesh in batches:
		var xfs: Array = batches[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Batched %s x%d" % [mesh.resource_name, xfs.size()]
		root.add_child(mmi)
		out.multimeshes += 1
		out.batched_instances += xfs.size()
		out.triangles += _tris(mesh) * (xfs.size() - 1)
	_add_fx(root, path.get_basename() + "_fx.json", out, spec.get("cloud_tint", Color(0.97, 0.98, 1.0)))
	if spec.has("glass"):
		_apply_glass(root, spec.glass)
	return out


## Surfaces whose GLB material is named in `names` get a clear glass (the glTF blend material reads as a dark, muddy sheet in Godot).
static func _apply_glass(node: Node, names: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m != null and names.has(m.resource_name.to_lower()):
					mi.set_surface_override_material(s, _glass())
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # the panes' shadow made the gear pit black (the mesh's other parts are loose papers)
		_apply_glass(c, names)


static var _glass_mat: StandardMaterial3D


static func _glass() -> StandardMaterial3D:
	if _glass_mat != null:
		return _glass_mat
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_mat.albedo_color = Color(0.6, 0.76, 0.95, 0.24)  # no sky to reflect in the game: a cool sheen stands in for it so the disc reads as glass
	_glass_mat.roughness = 0.05
	_glass_mat.metallic_specular = 0.8
	_glass_mat.rim_enabled = true
	_glass_mat.rim = 0.35
	_glass_mat.rim_tint = 0.2
	_glass_mat.emission_enabled = true
	_glass_mat.emission = Color(0.22, 0.36, 0.58)
	_glass_mat.emission_energy_multiplier = 0.55
	return _glass_mat


## The loaded GLB of the last map built, kept (outside the tree) so a retry or a return to the same map skips the multi-second parse and
## texture decode; only one map is kept, so memory does not grow as the player moves between maps. The built scenery only reads from it.
static var _glb_cache_path := ""
static var _glb_cache: Node3D


static func _load_glb(path: String) -> Node3D:
	if path == _glb_cache_path and is_instance_valid(_glb_cache):
		return _glb_cache
	var glb: Node3D = null
	if ResourceLoader.exists(path, "PackedScene"):
		# Godot's own import (art_src/environment is no longer .gdignore'd for these maps): a binary scene with GPU-compressed (Basis Universal)
		# textures, several times faster to load than parsing the GLB and decoding its WebP images, and far lighter on video memory
		var ps := load(path) as PackedScene
		if ps != null:
			glb = ps.instantiate() as Node3D
	if glb == null:  # not imported (a fresh checkout before the editor's first import): parse the GLB at runtime as before
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_error("hollowmark scenery: %s did not load" % path)
			return null
		glb = doc.generate_scene(state) as Node3D
	if glb == null:
		return null
	if is_instance_valid(_glb_cache):
		_glb_cache.free()
	_glb_cache = glb
	_glb_cache_path = path
	return glb


static func _collect(node: Node, xf: Transform3D, placed: Array) -> void:
	for c in node.get_children():
		var cxf := xf
		if c is Node3D:
			cxf = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			placed.append([c, cxf])
		_collect(c, cxf, placed)


static func _spinner(src: MeshInstance3D, xf: Transform3D, n: String) -> Node3D:
	var tok: String = n.split(" ")[-1]  # "p12" / "n07": direction and hundredths of a radian a second
	var sp := HollowmarkSpinner.new()
	sp.name = src.name
	sp.transform = xf
	sp.rate = float(tok.substr(1)) / 100.0 * (-1.0 if tok.begins_with("n") else 1.0)
	sp.add_child(_placed(src, Transform3D.IDENTITY, null))
	return sp


static func _hidden_views(name: String, hide: Dictionary) -> Array:
	var views := []
	for r in hide:
		for prefix in hide[r]:
			if name.begins_with(String(prefix)):
				views.append(int(r))
	return views


static func _add_hidden(out: Dictionary, r: int, mi: MeshInstance3D) -> void:
	if not out.view_hidden.has(r):
		out.view_hidden[r] = []
	out.view_hidden[r].append(mi)


static func _placed(src: MeshInstance3D, xf: Transform3D, override: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	mi.transform = xf
	mi.name = src.name
	for s in src.mesh.get_surface_count():
		var m := src.get_surface_override_material(s)
		if m != null:
			mi.set_surface_override_material(s, m)
	if override != null:
		mi.material_override = override
	return mi


static func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


## Splits a mesh's triangles: those standing beyond a view's plane (on the camera's side of the board and above `above`) go to a mesh that view hides.
static func _split(mi: MeshInstance3D, xf: Transform3D, planes: Dictionary, root: Node3D, cut_above := 1e9, any_vertex := false) -> Array:
	var to_world := Transform3D(Basis(Vector3.UP, root.rotation.y), root.position) * xf
	var groups := {}  ## view (-1 = always shown) -> {material -> SurfaceTool}
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s)
		var a := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var norms: Variant = a[Mesh.ARRAY_NORMAL]
		var uvs: Variant = a[Mesh.ARRAY_TEX_UV]
		var tans: Variant = a[Mesh.ARRAY_TANGENT]
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = idx if idx != null else PackedInt32Array(range(verts.size()))
		for t in range(0, order.size() - 2, 3):
			var w0 := to_world * verts[order[t]]
			var w1 := to_world * verts[order[t + 1]]
			var w2 := to_world * verts[order[t + 2]]
			var c := (w0 + w1 + w2) / 3.0
			if c.y > cut_above:
				continue
			var view := -1
			for r in planes:
				var pl: Dictionary = planes[r]
				var ax := int(pl.axis)
				var beyond: float = pl.beyond
				# a triangle is cut when its centre is beyond the plane, or (with "any_vertex") when any corner is: then the wall's
				# triangles that straddle the plane go too, instead of being left as dark jagged shards in front of the camera
				var vs: Array = [w0[ax], w1[ax], w2[ax]] if any_vertex else [c[ax]]
				var past := false
				for v in vs:
					past = past or (beyond >= 0.0 and float(v) > beyond) or (beyond < 0.0 and float(v) < -beyond)
				if c.y > float(pl.above) and past:
					view = int(r)
					break
			if not groups.has(view):
				groups[view] = {}
			if not groups[view].has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				if mat:
					st.set_material(mat)
				groups[view][mat] = st
			var stl: SurfaceTool = groups[view][mat]
			for k in 3:
				var i := order[t + k]
				if uvs != null: stl.set_uv(uvs[i])
				if norms != null: stl.set_normal(norms[i])
				if tans != null:
					var tn: PackedFloat32Array = tans
					stl.set_tangent(Plane(tn[i * 4], tn[i * 4 + 1], tn[i * 4 + 2], tn[i * 4 + 3]))
				stl.add_vertex(verts[i])
	var parts := []
	for view in groups:
		var mesh: ArrayMesh = null
		if groups[view].is_empty():
			continue
		for mat in groups[view]:
			mesh = (groups[view][mat] as SurfaceTool).commit(mesh)
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.transform = xf
		part.name = "%s%s" % [mi.name, "" if view < 0 else " (hidden in view %d)" % view]
		parts.append([part, view])
	return parts


static func _water_material(p: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hollowmark_water.gdshader")
	m.set_shader_parameter("ripple_normal", _noise(true, 0.02))
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## Each waterfall gets its own copy: the shader scrolls between the mesh's own top and bottom (world heights).
static func _waterfall_material(aabb: AABB, xf: Transform3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hollowmark_waterfall.gdshader")
	m.set_shader_parameter("noise_tex", _noise(false, 0.03))
	var top := (xf * aabb.end).y
	var bottom := (xf * aabb.position).y
	m.set_shader_parameter("top_y", maxf(top, bottom))
	m.set_shader_parameter("bottom_y", minf(top, bottom))
	return m


static var _noise_cache := {}


static func _noise(normal_map: bool, freq: float) -> NoiseTexture2D:
	var key := "%s%f" % [normal_map, freq]
	if _noise_cache.has(key):
		return _noise_cache[key]
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = normal_map
	t.bump_strength = 6.0
	t.noise = n
	_noise_cache[key] = t
	return t


## Blender coordinates (X, Y, Z) -> the scenery root's local space (the GLB's own: X, Z, -Y).
static func _local(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[2]), -float(v[1]))


static func _add_fx(root: Node3D, fx_path: String, out: Dictionary, cloud_tint := Color(0.97, 0.98, 1.0)) -> void:
	if not FileAccess.file_exists(fx_path):
		return
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fx_path))
	var lights: Array = fx.get("lights", [])
	lights.sort_custom(func(a, b): return float(a.watts) > float(b.watts))
	for l in lights.slice(0, 40):
		var w := float(l.watts)
		if String(l.type) == "SPOT" and w > 5000.0:
			continue  # Blender-only key/shaft lights: the board's sun and environment stand in for them
		var o := OmniLight3D.new()
		o.position = _local(l.pos)
		var c: Array = l.color
		o.light_color = Color(float(c[0]), float(c[1]), float(c[2]))
		o.light_energy = clampf(w / 150.0, 0.25, 4.0)
		o.omni_range = clampf(2.0 + sqrt(w) * 0.25, 2.5, 11.0)
		o.omni_attenuation = 1.3
		o.light_volumetric_fog_energy = 1.2
		o.name = String(l.name)
		root.add_child(o)
		out.lights += 1
	for p in fx.get("puffs", []):
		var pos := _local(p.pos)
		var r := float(p.radius)
		if String(p.kind) == "cloud":
			root.add_child(_cloud(pos, r, cloud_tint))
		else:
			root.add_child(_mist(pos, r))
		out.puffs += 1


static func _mist(pos: Vector3, r: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = int(clampf(r * 40.0, 16.0, 80.0))
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-r * 2, -r, -r * 2), Vector3(r * 4, r * 4, r * 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = r * 0.6
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = r * 0.8
	pm.scale_max = r * 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 0.16))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # lit (not unshaded): smoke in a dark arena stays dark, mist by a lamp takes its colour
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.albedo_color = Color(0.78, 0.76, 0.72, 0.45)
	m.albedo_texture = _soft_dot()
	quad.material = m
	p.draw_pass_1 = quad
	return p


static func _cloud(pos: Vector3, r: float, tint := Color(0.97, 0.98, 1.0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Cloud"
	var quad := PlaneMesh.new()
	quad.size = Vector2(r * 3.2, r * 2.6)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/hollowmark_cloud.gdshader")
	m.set_shader_parameter("noise_tex", _noise(false, 0.012))
	m.set_shader_parameter("tint", tint)
	quad.material = m
	mi.mesh = quad
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _dot: GradientTexture2D


static func _soft_dot() -> GradientTexture2D:
	if _dot != null:
		return _dot
	_dot = GradientTexture2D.new()
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_dot.gradient = g
	return _dot
