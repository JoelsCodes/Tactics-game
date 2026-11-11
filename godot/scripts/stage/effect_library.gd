class_name EffectLibrary
extends RefCounted
## The shared effect pieces for skills (owner OK'd procedural effects, Nov 2026): five pieces, tinted and shaped by a LOOK from data/effect_looks.json
## (fire, ice, spark, holy), so a new element is a few lines of data, not new art:
##
##   projectile   a glowing head flying from a point to a point, with a particle trail; awaitable: it returns when the head arrives
##   burst        an impact flash with a puff of particles
##   ring         a ring that opens on the ground
##   aura         particles rising round a unit for a while
##   beam         a quick stretched line of light between two points
##
## Everything is drawn from textures made here in code (no art files), additive, unshaded, and frees itself. At most MAX_LIVE pieces exist at once; more are
## skipped. This only draws: nothing here knows about damage or turns. HitFeedback and BattleStage will ask for pieces once the owner has seen them
## (tests/effects_sheet.tscn renders every look with every piece).

const LOOKS_PATH := "res://data/effect_looks.json"
const MAX_LIVE := 48
const GROUND := 0.05

static var _looks := {}
static var _tex := {}
static var _mats := {}
static var live := 0


static func looks() -> Dictionary:
	if _looks.is_empty():
		var f := FileAccess.get_file_as_string(LOOKS_PATH)
		var j = JSON.parse_string(f) if f != "" else null
		_looks = j.get("looks", {}) if j is Dictionary else {}
	return _looks


## A look's data; an unknown name gets "spark" (so a skill with a typo still shows something).
static func look(name: String) -> Dictionary:
	var all := looks()
	return all.get(name, all.get("spark", {}))


static func color(l: Dictionary, key: String, fallback := Color.WHITE) -> Color:
	var c: Array = l.get(key, [])
	return Color(float(c[0]), float(c[1]), float(c[2])) if c.size() >= 3 else fallback


# ---------- the pieces ----------

## A glowing head flies from `from` to `to` (world positions) leaving a trail; returns when it arrives (the caller lands the hit then).
static func projectile(parent: Node3D, look_name: String, from: Vector3, to: Vector3) -> void:
	if not _room(parent):
		return
	var l := look(look_name)
	var head := _sprite(parent, "soft", color(l, "glow"), float(l.get("head", 0.36)), true)
	var core := _sprite(head, "soft", color(l, "core"), float(l.get("head", 0.36)) * 0.45, true)
	head.global_position = from
	var trail := _particles(head, l, int(l.get("count", 16)) * 2, 0.35, false)
	trail.emitting = true
	trail.spread = 25.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = float(l.get("speed", 1.0)) * 0.35
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	var secs := clampf(from.distance_to(to) / maxf(float(l.get("projectile_speed", 10.0)), 1.0), 0.1, 0.6)
	var tw := head.create_tween()
	tw.tween_property(head, "global_position", to, secs)
	await tw.finished
	if is_instance_valid(trail):
		trail.emitting = false
	if is_instance_valid(core):
		core.visible = false
	if is_instance_valid(head):
		head.visible = false
		_free_later(head, 0.5)


## A flash and a puff of particles at `at`.
static func burst(parent: Node3D, look_name: String, at: Vector3, size := 1.0) -> void:
	if not _room(parent):
		return
	var l := look(look_name)
	var flash := _sprite(parent, "soft", color(l, "glow"), 0.5 * size, true)
	flash.global_position = at
	var tw := flash.create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3.ONE * 3.2, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "transparency", 1.0, 0.3)
	var core := _sprite(parent, "soft", color(l, "core"), 0.35 * size, true)
	core.global_position = at
	var tc := core.create_tween().set_parallel()
	tc.tween_property(core, "scale", Vector3.ONE * 1.8, 0.16)
	tc.tween_property(core, "transparency", 1.0, 0.18)
	var ps := _particles(parent, l, int(float(l.get("count", 16)) * size), float(l.get("life", 0.6)), true)
	ps.global_position = at
	ps.explosiveness = 0.95
	ps.emitting = true
	_free_later(flash, 0.4)
	_free_later(core, 0.3)
	_free_later(ps, float(l.get("life", 0.6)) + 0.3)


## A ring opening on the ground at `at`; radius in tiles (the look's own size scales it).
static func ring(parent: Node3D, look_name: String, at: Vector3, radius := 1.0) -> void:
	if not _room(parent):
		return
	var l := look(look_name)
	var r := radius * float(l.get("ring", 1.0))
	for i in 2:
		var m := _sprite(parent, "ring", color(l, "glow") if i == 0 else color(l, "color"), 0.3, false)
		m.global_position = Vector3(at.x, at.y + GROUND + 0.01 * i, at.z)
		m.rotation.x = -PI / 2.0
		var t := 0.55 + 0.25 * i
		var tw := m.create_tween().set_parallel()
		tw.tween_property(m, "scale", Vector3.ONE * r * 2.0 / 0.3, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "transparency", 1.0, t).set_delay(t * 0.35)
		_free_later(m, t + 0.1)


## Particles rising round a unit standing at `at` for `secs` seconds.
static func aura(parent: Node3D, look_name: String, at: Vector3, secs := 1.2, height := 1.7) -> void:
	if not _room(parent):
		return
	var l := look(look_name)
	var ps := _particles(parent, l, int(l.get("count", 16)) * 2, float(l.get("life", 0.7)) * 1.2, true)
	ps.global_position = at + Vector3(0, 0.1, 0)
	ps.one_shot = false
	ps.explosiveness = 0.0
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	ps.emission_ring_axis = Vector3.UP
	ps.emission_ring_radius = 0.5
	ps.emission_ring_inner_radius = 0.35
	ps.emission_ring_height = 0.05
	ps.direction = Vector3.UP
	ps.spread = 12.0
	ps.initial_velocity_min = height * 0.5
	ps.initial_velocity_max = height * 0.9
	ps.gravity = Vector3.ZERO
	ps.emitting = true
	var tw := ps.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(func(): if is_instance_valid(ps): ps.emitting = false)
	_free_later(ps, secs + float(l.get("life", 0.7)) * 1.2 + 0.2)
	ring(parent, look_name, at, 0.55)


## A quick line of light from `from` to `to`.
static func beam(parent: Node3D, look_name: String, from: Vector3, to: Vector3, secs := 0.4) -> void:
	if not _room(parent) or from.distance_to(to) < 0.05:
		return
	var l := look(look_name)
	var node := Node3D.new()
	parent.add_child(node)
	node.global_position = (from + to) / 2.0
	node.look_at(to, Vector3.UP)  # -Z points at the target
	var length := from.distance_to(to)
	var w := float(l.get("beam_width", 0.4))
	for pass_i in 2:  # two quads crossed along the beam, so it has body from any side
		var pivot := Node3D.new()
		node.add_child(pivot)
		pivot.rotate_object_local(Vector3(0, 0, 1), PI / 2.0 * pass_i)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w, length)
		mi.mesh = q
		mi.material_override = _material("beam", color(l, "glow") if pass_i == 0 else color(l, "color"), false)
		mi.rotation.x = -PI / 2.0
		pivot.add_child(mi)
	var core := _sprite(node, "soft", color(l, "core"), w * 0.9, true)
	core.position = Vector3(0, 0, length / 2.0)
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, "scale", Vector3(0.25, 0.25, 1.0), secs).from(Vector3(1.0, 1.0, 1.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_free_later(node, secs + 0.05)


# ---------- building blocks ----------

static func _room(parent: Node3D) -> bool:
	return parent != null and parent.is_inside_tree() and live < MAX_LIVE


static func _free_later(n: Node, secs: float) -> void:
	live += 1
	var tree := n.get_tree()
	if tree == null:
		n.queue_free()
		live -= 1
		return
	tree.create_timer(secs).timeout.connect(func():
		live = maxi(live - 1, 0)
		if is_instance_valid(n):
			n.queue_free())


## A textured quad: billboarded (faces the camera) or flat (the caller rotates it); `size` in world units.
static func _sprite(parent: Node, tex: String, tint: Color, size: float, billboard: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = _material(tex, tint, billboard)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Particles of the look's texture. `world`: stay where they were emitted (a trail), else they ride the node.
static func _particles(parent: Node, l: Dictionary, amount: int, life: float, one_shot: bool) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.amount = clampi(amount, 1, 64)
	ps.lifetime = life
	ps.one_shot = one_shot
	ps.emitting = false
	ps.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2.ONE * float(l.get("size", 0.18))
	ps.mesh = q
	ps.material_override = _material(String(l.get("tex", "soft")), Color.WHITE, true, true)
	ps.direction = Vector3.UP
	ps.spread = float(l.get("spread", 180.0))
	ps.initial_velocity_min = float(l.get("speed", 1.0)) * 0.5
	ps.initial_velocity_max = float(l.get("speed", 1.0))
	ps.gravity = Vector3(0, float(l.get("gravity", 0.0)), 0)
	ps.damping_min = 0.4
	ps.damping_max = 1.2
	ps.color = color(l, "color")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(color(l, "glow"), 0.0)])
	ps.color_ramp = g
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0.1))
	ps.scale_amount_curve = curve
	parent.add_child(ps)
	return ps


## One material per (texture, tint, billboard) kind: additive, unshaded, double sided.
static func _material(tex: String, tint: Color, billboard: bool, particles := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [tex, tint.to_html(), billboard, particles]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = texture(tex)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.render_priority = 6
	m.disable_receive_shadows = true
	if particles:
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.particles_anim_h_frames = 1
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = false
	elif billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	_mats[key] = m
	return m


# ---------- textures drawn in code ----------

static func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := 128
	var w := 32 if kind == "beam" else n
	var img := Image.create(w, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in w:
			var u := (float(x) + 0.5) / float(w) * 2.0 - 1.0  # -1 .. 1 across
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0  # -1 .. 1 down
			var a := 0.0
			match kind:
				"soft":
					var d := sqrt(u * u + v * v)
					a = pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
				"ring":
					var d2 := sqrt(u * u + v * v)
					a = exp(-pow((d2 - 0.82) / 0.07, 2.0)) + 0.18 * pow(clampf(1.0 - d2, 0.0, 1.0), 1.5)
				"shard":
					var f := absf(u) / 0.42 + absf(v) / 0.85
					a = clampf((1.0 - f) * 3.0, 0.0, 1.0)
					a = maxf(a, 0.25 * pow(clampf(1.0 - sqrt(u * u + v * v), 0.0, 1.0), 2.0))
				"star":
					var s := absf(u) * absf(v) * 22.0 + (absf(u) + absf(v)) * 1.25
					a = pow(clampf(1.0 - s, 0.0, 1.0), 1.6)
				"beam":
					a = exp(-pow(u / 0.34, 2.0)) * clampf((1.0 - absf(v)) * 4.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t
