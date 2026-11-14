class_name EmberwellScenery
extends RefCounted
## Emberwell Village (the owner's Blender village, Nov 2026) from its GLB, ready to place in a scene as a board's scenery (Board3D, a map with "scenery": "emberwell").
##
## The village ground is 20 x 20 at one unit a tile, x 0..20 and z -20..0 in the GLB; the board's rows run the same way (row y is z = y - 20), so the scene is only
## moved 20 units along z (no mirroring): the cell (x, y) is centred at (x + 0.5, height, y + 0.5). The owner's two map files (samples/emberwell_village.json:
## the terrace test, a one-level terrace at x 10-12, rows 4-6, with half-step ramps at rows 3 and 7) were made for this GLB: structure footprints cover 81 of
## the 82 blocked cells, and the GLB's `Terrace continuous bed` is 0.42 high where the map has its terrace (one level = 0.42, the board's own).
##
## Everything is visual only (no collision, no navigation). The 140 animated nodes (embers, flames, smoke) stay as they are, with their animations looping;
## every other mesh is merged into one mesh per material. Nodes named ArtOnlySmoke are for the Blender renders and are hidden.

const GLB := "res://art_src/environment/emberwell/emberwell.glb"
const SIZE := 20

## Materials that left Blender as plain white with no texture (their shaders were procedural node setups, which glTF cannot carry): the ones that have a textured
## sibling take its maps (and a tint), the vegetation and cloth get colours, and the smoke and fire volumes become translucent. A stopgap done in Godot when the village
## loads; the real fix is baking those shaders to image textures in the Blender source. `from`: the material whose maps and settings are copied.
const COPY := {
	"Timber 0": {"from": "Timber 1"},
	"Fieldstone 0": {"from": "Fieldstone 1"},
	"Soil • moss and ash": {"from": "Cold ash and charcoal", "tint": Color(0.66, 0.6, 0.5)},
	"Terrace • mossy soil": {"from": "Cold ash and charcoal", "tint": Color(0.5, 0.56, 0.4)},
}
const COLOUR := {
	"Dry grass": Color("#6f6a37"), "Grass olive": Color("#46591f"), "Fern shadow": Color("#2f4a2c"),
	"Pine 0": Color("#2a4a2c"), "Pine 1": Color("#325634"), "Pine 2": Color("#274226"),
	"Dyed canvas": Color("#9b5b3c"), "Weathered green paint": Color("#4a6a58"),
}
const SMOKE := ["Smoke • turbulent volume", "Upgrade | Volumetric charcoal smoke"]
const FIRE := "Animated fire • turbulent emissive volume"


## {"root": Node3D, "merged": Array[MeshInstance3D], "scenery_meshes": int, "triangles": int, "animated": int, "player": AnimationPlayer, "hidden": int}; an empty
## Dictionary if the GLB does not load.
static func build() -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(GLB, state) != OK:
		push_error("emberwell: the GLB did not load")
		return {}
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return {}
	var out := {"root": root, "merged": [], "scenery_meshes": 0, "triangles": 0, "animated": 0, "hidden": 0, "player": null, "players": 0, "repaired": 0}
	var animated := {}
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		var player: AnimationPlayer = players[0]
		out.player = player
		var base: Node = player.get_node(player.root_node)
		for name in player.get_animation_list():
			var a := player.get_animation(name)
			a.loop_mode = Animation.LOOP_LINEAR  # embers and smoke go on burning
			for t in a.get_track_count():
				var n := base.get_node_or_null(NodePath(a.track_get_path(t).get_concatenated_names()))
				if n != null:
					animated[n] = true
	out.repaired = repair_materials(root)
	var visual: Array[MeshInstance3D] = []
	for c in root.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi: MeshInstance3D = c
		if String(mi.name).begins_with("ArtOnly"):
			mi.visible = false
			out.hidden += 1
			continue
		if animated.has(mi):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a flame or a puff of smoke casts no shadow
			continue
		visual.append(mi)
	out.animated = animated.size()
	out.scenery_meshes = visual.size()
	LastBenedictionScenery.merge(out, root, visual)
	root.name = "Emberwell"
	root.position = Vector3(0, 0, SIZE)
	out.players = _burn(root, out.player)
	return out


## An AnimationPlayer plays one animation at a time and the GLB has 140 (one per ember, flame or smoke node), so each one gets a player of its own that loops it,
## started at a random point so the fires do not pulse together. Returns how many players are burning.
static func _burn(root: Node3D, source: AnimationPlayer) -> int:
	if source == null:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var n := 0
	for name in source.get_animation_list():
		var a := source.get_animation(name)
		var p := AnimationPlayer.new()
		p.name = "Burn%d" % n
		p.root_node = source.root_node
		var lib := AnimationLibrary.new()
		lib.add_animation(&"burn", a)
		p.add_animation_library(&"", lib)
		root.add_child(p)
		p.play(&"burn")
		p.seek(rng.randf() * maxf(a.length, 0.01), true)
		n += 1
	source.queue_free()  # its animations now belong to the burning players
	return n


## Repairs the white materials in place (see COPY, COLOUR, SMOKE, FIRE). Returns how many it changed.
static func repair_materials(root: Node) -> int:
	var by_name := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m != null and not by_name.has(m.resource_name):
				by_name[m.resource_name] = m
	var fixed := 0
	for name in by_name:
		var m: BaseMaterial3D = by_name[name]
		if COPY.has(name) and by_name.has(COPY[name].from):
			var src: BaseMaterial3D = by_name[COPY[name].from]
			m.albedo_texture = src.albedo_texture
			m.normal_enabled = src.normal_enabled
			m.normal_texture = src.normal_texture
			m.roughness_texture = src.roughness_texture
			m.roughness = src.roughness
			m.uv1_scale = src.uv1_scale
			m.albedo_color = COPY[name].get("tint", Color.WHITE)
			fixed += 1
		elif COLOUR.has(name):
			m.albedo_color = COLOUR[name]
			m.roughness = 0.95
			fixed += 1
		elif name in SMOKE:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.1, 0.095, 0.09, 0.3)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			fixed += 1
		elif name == FIRE:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(1.0, 0.45, 0.12, 0.45)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.42, 0.1)
			m.emission_energy_multiplier = 2.2
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			fixed += 1
	return fixed
