class_name BoardLife
extends Node3D
## The life on a map (owner request, Nov 2026): braziers and torches with flickering light and rising embers, banners that sway, crates, barrels, weapon racks,
## bones and rubble, glowing crystals that pulse, hanging lanterns and wisps that bob, and an ambient weather of drifting particles. Everything is real 3D
## (boxes, cylinders, emissive materials, lights, particles): no flat cut-out props (owner rule), and nothing blocks a tile (it is all decoration, placed on tiles
## the map data names).
##
## Map data (`life` and `ambient` in the map JSON, written by tools/life_kit.py):
##   "life":    [{"type": "brazier", "x": 3, "y": 7, "ox": 0.2, "oy": -0.1, "rot": 30, "color": "#7fc8ff", "s": 1.0}, ...]   x, y are the cell (x up the screen), ox/oy an offset
##              in tiles, rot a turn in degrees, s a scale, color the accent (banner cloth, crystal glow, lantern light)
##   types:     brazier, torch, banner, standard (a tall war banner), crates, barrel, rack (weapons), bones, rubble, crystal, lantern (hangs from a post), wisp, grave,
##              bench, stall (a market table under a coloured canopy), hay (festival bales)
##   "ambient": embers | spirit | leaves | snow | fireflies | motes   a slow weather over the whole board

const TYPES := ["brazier", "torch", "banner", "standard", "crates", "barrel", "rack", "bones", "rubble", "crystal", "lantern", "wisp", "grave", "bench", "stall", "hay"]
const AMBIENTS := ["embers", "spirit", "leaves", "snow", "fireflies", "motes"]
const MAX_LIGHTS := 18  ## real lights on a board: the rest of the fires only glow

var board: Board3D
var count := 0  ## items built
var lights := 0
var _t := 0.0
var _flames: Array = []  ## {light, mesh, base, phase}
var _sways: Array = []  ## {node, base, phase, amp}
var _bobs: Array = []  ## {node, base, phase, amp}
var _pulses: Array = []  ## {mat, light, phase}
var _dot: Texture2D = load("res://assets/fx/soft_dot.png")


func build(b: Board3D, map: Dictionary) -> void:
	name = "Life"
	board = b
	for item in map.get("life", []):
		if item is Dictionary and String(item.get("type", "")) in TYPES:
			_make(item)
	var amb := String(map.get("ambient", ""))
	if amb in AMBIENTS:
		_ambient(amb, map)


func _process(delta: float) -> void:
	_t += delta
	for f in _flames:
		var k: float = 0.82 + 0.2 * sin(_t * 11.0 + f.phase) + 0.1 * sin(_t * 23.0 + f.phase * 2.1) + 0.06 * sin(_t * 37.0 + f.phase)
		if f.light != null:
			f.light.light_energy = f.base * k
		f.mesh.scale = Vector3(1.0 - 0.1 * (k - 0.8), 0.85 + 0.45 * (k - 0.6), 1.0 - 0.1 * (k - 0.8))
	for s in _sways:
		s.node.rotation.z = s.base + s.amp * sin(_t * 1.6 + s.phase) + 0.4 * s.amp * sin(_t * 3.7 + s.phase)
	for b in _bobs:
		b.node.position.y = b.base + b.amp * sin(_t * 1.1 + b.phase)
	for p in _pulses:
		var k2 := 0.5 + 0.5 * sin(_t * 1.8 + p.phase)
		p.mat.emission_energy_multiplier = 1.2 + 2.2 * k2
		if p.light != null:
			p.light.light_energy = p.base * (0.6 + 0.8 * k2)


func _make(it: Dictionary) -> void:
	var x := int(it.x)
	var y := int(it.y)
	if x < 0 or y < 0 or x >= board.map.w or y >= board.map.d:
		return
	var root := Node3D.new()
	root.name = "%s_%d_%d" % [it.type, x, y]
	root.position = board.top_point(x, y) + Vector3(float(it.get("ox", 0.0)), -0.05, float(it.get("oy", 0.0)))  # sunk a little: wall tops are uneven
	root.rotation_degrees.y = float(it.get("rot", 0.0)) + (90.0 if String(it.type) in ["banner", "standard", "lantern"] else 0.0)  # cloth and arms face the camera
	root.scale = Vector3.ONE * float(it.get("s", 1.0))
	add_child(root)
	var accent := Color(String(it.get("color", "")) if String(it.get("color", "")) != "" else "#ffffff")
	match String(it.type):
		"brazier": _brazier(root)
		"torch": _torch(root)
		"banner": _banner(root, accent if it.has("color") else Color("#8a2a2a"), 1.0)
		"standard": _banner(root, accent if it.has("color") else Color("#2a3f7a"), 1.8)
		"crates": _crates(root)
		"barrel": _barrel(root)
		"rack": _rack(root)
		"bones": _bones(root)
		"rubble": _rubble(root)
		"crystal": _crystal(root, accent if it.has("color") else Color("#7fc8ff"))
		"lantern": _lantern(root, accent if it.has("color") else Color("#8fd0ff"))
		"wisp": _wisp(root, accent if it.has("color") else Color("#9fd8ff"))
		"grave": _grave(root)
		"bench": _bench(root)
		"stall": _stall(root, accent if it.has("color") else Color("#b0402a"))
		"hay": _hay(root)
	count += 1


# ---------------------------------------------------------------------------- materials and shapes

func _mat(c: Color, rough := 0.9, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0, glow := 0.0, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, 0.9, glow)
	mi.position = pos
	mi.rotation_degrees.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(c, 0.85, glow)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, pos: Vector3, c: Color, glow: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(c, 0.4, glow)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _light(parent: Node3D, pos: Vector3, c: Color, energy: float, rng: float) -> OmniLight3D:
	if lights >= MAX_LIGHTS:
		return null
	lights += 1
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	parent.add_child(l)
	return l


## A flame: a glowing teardrop (flickering scale) with a hot core, a flickering light, and a few embers rising from it.
func _flame(parent: Node3D, pos: Vector3, size: float, c := Color("#ff8a2a")) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var outer := _ball(holder, 0.11 * size, Vector3(0, 0.1 * size, 0), c, 3.0)
	outer.scale = Vector3(1, 1.5, 1)
	_ball(holder, 0.06 * size, Vector3(0, 0.07 * size, 0), Color("#ffe6a0"), 4.0)
	var l := _light(parent, pos + Vector3(0, 0.25, 0), c.lerp(Color.WHITE, 0.15), 1.5 * size, 3.2 + size)
	_flames.append({"light": l, "mesh": holder, "base": 1.5 * size, "phase": randf() * 6.28})
	_sparks(parent, pos + Vector3(0, 0.15, 0), c, 5)


func _sparks(parent: Node3D, pos: Vector3, c: Color, amount: int) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.1, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	p.draw_pass_1 = _dot_quad(0.05, Color(c.r * 1.6, c.g * 1.3, c.b * 1.1, 1.0))
	parent.add_child(p)


func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _dot_quad(size: float, c: Color) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = _dot
	m.disable_receive_shadows = true
	q.material = m
	return q


# ---------------------------------------------------------------------------- the things

func _brazier(r: Node3D) -> void:
	var stone := Color("#4a4640")
	_box(r, Vector3(0.34, 0.1, 0.34), Vector3(0, 0.05, 0), stone)
	_cyl(r, 0.05, 0.07, 0.36, Vector3(0, 0.28, 0), Color("#3a3632"))
	_cyl(r, 0.2, 0.1, 0.14, Vector3(0, 0.52, 0), Color("#2c2825"))
	_box(r, Vector3(0.16, 0.05, 0.16), Vector3(0, 0.58, 0), Color("#e05a1a"), 0.0, 2.0, false)  # the coals
	_flame(r, Vector3(0, 0.6, 0), 1.0)


func _torch(r: Node3D) -> void:
	_cyl(r, 0.04, 0.055, 0.9, Vector3(0, 0.45, 0), Color("#4b3626"))
	_cyl(r, 0.1, 0.06, 0.12, Vector3(0, 0.92, 0), Color("#2e2a27"))
	_flame(r, Vector3(0, 0.98, 0), 1.0)


func _banner(r: Node3D, cloth: Color, height: float) -> void:
	_cyl(r, 0.03, 0.04, 1.3 * height, Vector3(0, 0.65 * height, 0), Color("#3f2f22"))
	_box(r, Vector3(0.68, 0.06, 0.06), Vector3(0, 1.28 * height, 0), Color("#3f2f22"))
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.3, 1.26 * height, 0)
	r.add_child(pivot)
	var w := 0.6
	var h := 0.85 * height
	_box(pivot, Vector3(w, h, 0.025), Vector3(w / 2.0, -h / 2.0, 0), cloth)
	_box(pivot, Vector3(w * 0.5, h * 0.12, 0.03), Vector3(w / 2.0, -h * 0.45, 0), cloth.lightened(0.35))  # a stripe
	_box(pivot, Vector3(w, 0.05, 0.03), Vector3(w / 2.0, -h, 0), cloth.darkened(0.3))  # the hem
	_sways.append({"node": pivot, "base": 0.0, "phase": randf() * 6.28, "amp": 0.06})


func _crates(r: Node3D) -> void:
	var wood := Color("#6b4a2e")
	_box(r, Vector3(0.36, 0.3, 0.36), Vector3(0, 0.15, 0), wood, 8.0)
	_box(r, Vector3(0.3, 0.26, 0.3), Vector3(0.28, 0.13, 0.06), wood.darkened(0.12), -14.0)
	_box(r, Vector3(0.28, 0.24, 0.28), Vector3(0.04, 0.42, -0.02), wood.lightened(0.08), 24.0)
	_box(r, Vector3(0.38, 0.04, 0.38), Vector3(0, 0.3, 0), wood.darkened(0.3), 8.0)


func _barrel(r: Node3D) -> void:
	_cyl(r, 0.17, 0.15, 0.4, Vector3(0, 0.2, 0), Color("#5a3d27"))
	_cyl(r, 0.176, 0.176, 0.04, Vector3(0, 0.1, 0), Color("#2d2a28"))
	_cyl(r, 0.176, 0.176, 0.04, Vector3(0, 0.3, 0), Color("#2d2a28"))


func _rack(r: Node3D) -> void:
	var wood := Color("#4b3626")
	_box(r, Vector3(0.05, 0.55, 0.05), Vector3(-0.3, 0.27, 0), wood)
	_box(r, Vector3(0.05, 0.55, 0.05), Vector3(0.3, 0.27, 0), wood)
	_box(r, Vector3(0.68, 0.04, 0.05), Vector3(0, 0.42, 0), wood)
	for i in 4:  # spears and swords leaning in it
		var s := _box(r, Vector3(0.03, 0.75, 0.03), Vector3(-0.2 + i * 0.13, 0.4, 0.03), Color("#8f8a80") if i % 2 == 0 else Color("#6a5a48"))
		s.rotation_degrees.z = -6.0 + i * 4.0
		_box(r, Vector3(0.05, 0.1, 0.05), Vector3(-0.2 + i * 0.13 + 0.02 * (i - 1), 0.83, 0.03), Color("#9b958a"))


func _bones(r: Node3D) -> void:
	var b := Color("#cfc7b2")
	_box(r, Vector3(0.3, 0.035, 0.05), Vector3(0, 0.02, 0), b, 20.0)
	_box(r, Vector3(0.24, 0.035, 0.05), Vector3(0.05, 0.03, 0.06), b, -40.0)
	_box(r, Vector3(0.12, 0.1, 0.1), Vector3(-0.15, 0.06, -0.08), b.darkened(0.05), 15.0)  # a skull-ish block
	_box(r, Vector3(0.04, 0.04, 0.04), Vector3(-0.18, 0.1, -0.05), Color("#1c1a18"))


func _rubble(r: Node3D) -> void:
	var s := Color("#6a655c")
	_box(r, Vector3(0.22, 0.12, 0.2), Vector3(0, 0.06, 0), s, 12.0)
	_box(r, Vector3(0.14, 0.09, 0.15), Vector3(0.2, 0.045, 0.08), s.darkened(0.15), -30.0)
	_box(r, Vector3(0.1, 0.07, 0.1), Vector3(-0.17, 0.035, 0.12), s.lightened(0.1), 50.0)
	_box(r, Vector3(0.08, 0.06, 0.09), Vector3(0.05, 0.03, -0.18), s, 5.0)


func _grave(r: Node3D) -> void:
	var s := Color("#77736a")
	_box(r, Vector3(0.3, 0.05, 0.4), Vector3(0, 0.025, 0), s.darkened(0.2))
	_box(r, Vector3(0.22, 0.42, 0.07), Vector3(0, 0.26, -0.15), s)
	_box(r, Vector3(0.14, 0.1, 0.07), Vector3(0, 0.5, -0.15), s)  # the rounded top, blocky
	_box(r, Vector3(0.05, 0.12, 0.02), Vector3(0, 0.3, -0.11), s.darkened(0.35))


func _bench(r: Node3D) -> void:
	var wood := Color("#6b4a2e")
	_box(r, Vector3(0.7, 0.05, 0.24), Vector3(0, 0.27, 0), wood)
	_box(r, Vector3(0.7, 0.2, 0.04), Vector3(0, 0.42, -0.12), wood.darkened(0.1))
	_box(r, Vector3(0.05, 0.27, 0.2), Vector3(-0.3, 0.135, 0), wood.darkened(0.2))
	_box(r, Vector3(0.05, 0.27, 0.2), Vector3(0.3, 0.135, 0), wood.darkened(0.2))


func _stall(r: Node3D, cloth: Color) -> void:
	var wood := Color("#5a3d27")
	_box(r, Vector3(0.8, 0.06, 0.4), Vector3(0, 0.35, 0), wood)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(r, Vector3(0.04, 0.8, 0.04), Vector3(0.38 * sx, 0.4, 0.18 * sz), wood.darkened(0.15))
	var canopy := _box(r, Vector3(0.92, 0.04, 0.5), Vector3(0, 0.8, 0), cloth)
	canopy.rotation_degrees.x = 6.0
	_box(r, Vector3(0.92, 0.1, 0.03), Vector3(0, 0.74, 0.25), cloth.lightened(0.3))
	_box(r, Vector3(0.18, 0.1, 0.16), Vector3(-0.25, 0.43, 0), Color("#c9a24a"))
	_ball(r, 0.07, Vector3(0.1, 0.45, 0.03), Color("#c04a2a"), 0.0)
	_ball(r, 0.07, Vector3(0.24, 0.45, -0.02), Color("#7aa83a"), 0.0)


func _hay(r: Node3D) -> void:
	var h := Color("#c9a24a")
	_box(r, Vector3(0.42, 0.28, 0.3), Vector3(0, 0.14, 0), h, 8.0)
	_box(r, Vector3(0.38, 0.26, 0.28), Vector3(0.3, 0.13, 0.05), h.darkened(0.1), -12.0)
	_box(r, Vector3(0.36, 0.24, 0.28), Vector3(0.1, 0.4, 0), h.lightened(0.08), 20.0)
	_box(r, Vector3(0.44, 0.03, 0.04), Vector3(0, 0.14, 0.151), Color("#7a5a30"), 8.0)


func _crystal(r: Node3D, c: Color) -> void:
	var mat := _mat(c, 0.2, 2.0)
	mat.albedo_color = c.darkened(0.3)
	for i in 4:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		var h := 0.45 + 0.28 * float((i * 37) % 5) / 4.0
		pm.size = Vector3(0.16, h, 0.16)
		mi.mesh = pm
		mi.material_override = mat
		mi.position = Vector3(-0.12 + 0.12 * i - 0.05 * (i % 2), h / 2.0, 0.05 * ((i % 3) - 1))
		mi.rotation_degrees = Vector3(0, 40 * i, -10 + 7 * i)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.add_child(mi)
	_box(r, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.03, 0), Color("#3a3a40"))
	var l := _light(r, Vector3(0, 0.5, 0), c, 1.1, 3.6)
	_pulses.append({"mat": mat, "light": l, "base": 1.1, "phase": randf() * 6.28})
	_sparks(r, Vector3(0, 0.6, 0), c, 4)


func _lantern(r: Node3D, c: Color) -> void:
	_cyl(r, 0.025, 0.035, 1.5, Vector3(0, 0.75, 0), Color("#3a3028"))
	_box(r, Vector3(0.42, 0.04, 0.04), Vector3(0.2, 1.48, 0), Color("#3a3028"))
	var hang := Node3D.new()
	hang.position = Vector3(0.4, 1.46, 0)
	r.add_child(hang)
	_box(hang, Vector3(0.01, 0.2, 0.01), Vector3(0, -0.1, 0), Color("#2a2622"))
	_box(hang, Vector3(0.14, 0.2, 0.14), Vector3(0, -0.3, 0), Color("#2e2a27"))
	var core := _ball(hang, 0.06, Vector3(0, -0.3, 0), c, 4.0)
	core.scale = Vector3(1, 1.3, 1)
	var l := _light(hang, Vector3(0, -0.3, 0), c, 1.3, 3.8)
	_sways.append({"node": hang, "base": 0.0, "phase": randf() * 6.28, "amp": 0.07})
	_pulses.append({"mat": core.material_override, "light": l, "base": 1.3, "phase": randf() * 6.28})


func _wisp(r: Node3D, c: Color) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.9, 0)
	r.add_child(holder)
	var core := _ball(holder, 0.07, Vector3.ZERO, c, 4.5)
	_ball(holder, 0.14, Vector3.ZERO, Color(c.r, c.g, c.b, 1.0).darkened(0.35), 1.2).scale = Vector3(1, 1, 1)
	var l := _light(holder, Vector3.ZERO, c, 1.0, 3.4)
	_bobs.append({"node": holder, "base": 0.9, "phase": randf() * 6.28, "amp": 0.18})
	_pulses.append({"mat": core.material_override, "light": l, "base": 1.0, "phase": randf() * 6.28})
	_sparks(holder, Vector3.ZERO, c, 3)


# ---------------------------------------------------------------------------- weather

func _ambient(kind: String, map: Dictionary) -> void:
	var w: float = map.w
	var d: float = map.d
	var area := w * d
	var p := GPUParticles3D.new()
	p.name = "Ambient_" + kind
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var size := Vector3(w, 2.6, d)
	pm.emission_box_extents = size / 2.0
	p.position = Vector3(w / 2.0, 1.4, d / 2.0)
	p.visibility_aabb = AABB(-size, size * 2.0)
	var col := Color.WHITE
	var psize := 0.07
	match kind:
		"embers":
			p.amount = int(0.22 * area)
			p.lifetime = 7.0
			pm.direction = Vector3(0.3, 1, 0.1)
			pm.spread = 35.0
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.55
			pm.gravity = Vector3(0, 0.05, 0)
			col = Color(2.0, 0.85, 0.3, 1.0)
		"spirit":
			p.amount = int(0.28 * area)
			p.lifetime = 9.0
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 50.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.2
			pm.gravity = Vector3(0, 0.03, 0)
			col = Color(0.5, 0.95, 1.6, 1.0)
			psize = 0.09
		"leaves":
			p.amount = int(0.1 * area)
			p.lifetime = 8.0
			pm.direction = Vector3(1, -0.15, 0.3)
			pm.spread = 25.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 0.9
			pm.gravity = Vector3(0, -0.08, 0)
			col = Color(0.75, 0.62, 0.3, 1.0)
			psize = 0.11
		"snow":
			p.amount = int(0.45 * area)
			p.lifetime = 8.0
			pm.direction = Vector3(0.25, -1, 0.1)
			pm.spread = 14.0
			pm.initial_velocity_min = 0.25
			pm.initial_velocity_max = 0.5
			pm.gravity = Vector3(0.02, -0.05, 0)
			col = Color(1.3, 1.4, 1.6, 1.0)
			psize = 0.08
		"fireflies":
			p.amount = int(0.12 * area)
			p.lifetime = 6.0
			pm.direction = Vector3(0, 0.3, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = 0.04
			pm.initial_velocity_max = 0.14
			col = Color(1.5, 1.7, 0.5, 1.0)
			psize = 0.1
		_:  # motes: warm dust in the light
			p.amount = int(0.3 * area)
			p.lifetime = 10.0
			pm.direction = Vector3(0.4, 0.2, 0)
			pm.spread = 80.0
			pm.initial_velocity_min = 0.03
			pm.initial_velocity_max = 0.1
			col = Color(1.4, 1.2, 0.8, 0.9)
	p.preprocess = p.lifetime
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	p.draw_pass_1 = _dot_quad(psize, col)
	add_child(p)
