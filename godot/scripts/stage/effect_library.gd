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
## If the owner's effect sheet has the look and piece (assets/sprites/effects/fx_<look>_<piece>.png, cut by tools/art/effect_sheet.py) the piece plays
## those six frames (FxSprite); otherwise it is drawn from textures made here in code (additive particles), as a fallback. Both free themselves. At most MAX_LIVE pieces exist at once; more are
## skipped. This only draws: nothing here knows about damage or turns. HitFeedback and BattleStage will ask for pieces once the owner has seen them
## (tests/effects_sheet.tscn renders every look with every piece).

const LOOKS_PATH := "res://data/effect_looks.json"
const MAX_LIVE := 48
const GROUND := 0.05
const SHEET_DIR := "res://assets/sprites/effects/"
const FRAME_PX := Vector2(134, 100)  ## one frame of a strip
const UNIT_PER_PX := 0.0135  ## world units per art pixel at the default size (a frame is 1.8 x 1.35 tiles)
const HEAD_PX := 45.0  ## the projectile's head is this many px right of its frame's centre
const AURA_FEET_PX := 18.0  ## the aura's ring sits this many px below its frame's centre
const BEAM_PX := 111.0  ## the beam's drawn length inside its frame
const RING_PX := 88.0  ## the ring's drawn width inside its frame
const PIECE_SCALE := 1.6  ## projectiles and bursts are drawn this much larger than the sheet's default: at the battle camera the default is small beside a character
const AURA_SCALE := 1.75  ## the aura is drawn this much larger than the sheet's default so it wraps a character (about 1.8 tiles tall on screen)
const AURA_BEHIND := 0.3  ## tiles the aura stands behind the unit, so the unit is not covered by it

static var _looks := {}
static var _tex := {}
static var _mats := {}
static var live := 0
static var _strips := {}
static var aura_style := "behind"  ## "front" (small, over the unit), "behind" (large, behind it) or "behind_add" (the same, glowing)


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
	if _strip(look_name, "projectile") != null:
		await _sheet_projectile(parent, look_name, from, to)
		return
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
	if _strip(look_name, "burst") != null:
		_sheet_burst(parent, look_name, at, size)
		return
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
	if _strip(look_name, "ring") != null:
		_sheet_ring(parent, look_name, at, radius)
		return
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
	if _strip(look_name, "aura") != null:
		_sheet_aura(parent, look_name, at, secs)
		return
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
	if _strip(look_name, "beam") != null:
		_sheet_beam(parent, look_name, from, to, secs)
		return
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


# ---------- the owner's sheet ----------

## The strip for a look and piece (mipmapped once), or null when the sheet has none (an unknown look uses "spark"'s).
static func _strip(look_name: String, piece: String) -> Texture2D:
	var name := look_name if looks().has(look_name) else "spark"
	var key := "%s_%s" % [name, piece]
	if _strips.has(key):
		return _strips[key]
	var path := SHEET_DIR + "fx_%s.png" % key
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var src := load(path) as Texture2D
		if src != null:
			var img := src.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.fix_alpha_edges()
				img.generate_mipmaps()
				t = ImageTexture.create_from_image(img)
	_strips[key] = t
	return t


## The basis of a quad that faces the camera, turned by `roll` radians in the screen plane (identity without a camera).
static func _facing(parent: Node3D, roll := 0.0) -> Basis:
	var cam := parent.get_viewport().get_camera_3d() if parent.get_viewport() != null else null
	var b := cam.global_transform.basis.orthonormalized() if cam != null else Basis.IDENTITY
	return b * Basis(Vector3(0, 0, 1), roll)


## A direction in the screen plane: (angle of the screen direction of `d`, its length in the camera plane).
static func _screen_of(parent: Node3D, d: Vector3) -> Vector2:
	var cam := parent.get_viewport().get_camera_3d() if parent.get_viewport() != null else null
	if cam == null:
		return Vector2(atan2(d.z, d.x), Vector2(d.x, d.z).length())
	var b := cam.global_transform.basis
	var v := Vector2(d.dot(b.x), d.dot(b.y))
	return Vector2(atan2(v.y, v.x), v.length())


static func _fx(parent: Node3D, strip: Texture2D, size: Vector2, secs: float, looping: bool, additive := false) -> FxSprite:
	var fx := FxSprite.new()
	fx.setup(strip, size, 6, 6.0 / maxf(secs, 0.05), looping, additive)
	parent.add_child(fx)
	live += 1
	fx.tree_exited.connect(func(): live = maxi(live - 1, 0))
	return fx


static func _sheet_projectile(parent: Node3D, look_name: String, from: Vector3, to: Vector3) -> void:
	if not _room(parent):
		return
	var l := look(look_name)
	var sc := _screen_of(parent, to - from)
	var fx := _fx(parent, _strip(look_name, "projectile"), FRAME_PX * UNIT_PER_PX * PIECE_SCALE, 0.42, true)
	fx.mesh.center_offset = Vector3(-HEAD_PX * UNIT_PER_PX * PIECE_SCALE, 0, 0)  # the head, not the middle of the frame, rides the path
	fx.global_transform = Transform3D(_facing(parent, sc.x), from)
	var secs := clampf(from.distance_to(to) / maxf(float(l.get("projectile_speed", 10.0)), 1.0), 0.1, 0.6)
	var tw := fx.create_tween()
	tw.tween_property(fx, "global_position", to, secs)
	await tw.finished
	if is_instance_valid(fx):
		fx.fade_out(0.12)


static func _sheet_burst(parent: Node3D, look_name: String, at: Vector3, size: float) -> void:
	if not _room(parent):
		return
	var fx := _fx(parent, _strip(look_name, "burst"), FRAME_PX * UNIT_PER_PX * PIECE_SCALE * size, 0.5, false)
	fx.global_transform = Transform3D(_facing(parent), at)


## The ring is drawn already flattened for the game's camera, so it lies on the ground stretched back by 1 / sin(pitch): it then looks as drawn.
static func _sheet_ring(parent: Node3D, look_name: String, at: Vector3, radius: float) -> void:
	if not _room(parent):
		return
	var cam := parent.get_viewport().get_camera_3d() if parent.get_viewport() != null else null
	var w := FRAME_PX.x / RING_PX * 2.0 * radius * float(look(look_name).get("ring", 1.0))
	var sin_pitch := 0.77
	var right := Vector3.RIGHT
	var away := Vector3.FORWARD
	if cam != null:
		var cb := cam.global_transform.basis
		right = Vector3(cb.x.x, 0, cb.x.z).normalized()
		away = Vector3(-cb.z.x, 0, -cb.z.z).normalized()
		sin_pitch = clampf(-(-cb.z).y, 0.3, 1.0)
	var fx := _fx(parent, _strip(look_name, "ring"), Vector2(w, w * (FRAME_PX.y / FRAME_PX.x) / sin_pitch), 0.6, false)
	fx.global_transform = Transform3D(Basis(right, away, Vector3.UP), Vector3(at.x, at.y + GROUND, at.z))


## A looping aura round a unit standing at `at` for `secs` seconds: it fades in, breathes a little, and fades out. It is drawn larger than the sheet's
## default and a little BEHIND the unit (so the unit stays clear and the glow wraps it). Normal blending, not additive: on bright ground the additive one washes out (tests/aura_shot compares them).
static func _sheet_aura(parent: Node3D, look_name: String, at: Vector3, secs: float) -> void:
	if not _room(parent):
		return
	var front := aura_style == "front"
	var k := 1.0 if front else AURA_SCALE
	var fx := _fx(parent, _strip(look_name, "aura"), FRAME_PX * UNIT_PER_PX * k, 0.7, true, aura_style == "behind_add")
	var cam := parent.get_viewport().get_camera_3d() if parent.get_viewport() != null else null
	var back := Vector3.ZERO
	if cam != null and not front:
		var cb := cam.global_transform.basis
		back = Vector3(-cb.z.x, 0, -cb.z.z).normalized() * AURA_BEHIND  # away from the camera
	fx.global_transform = Transform3D(_facing(parent), at + back + Vector3(0, 0.12 + AURA_FEET_PX * UNIT_PER_PX * k, 0))
	fx.transparency = 1.0
	var tw := fx.create_tween()
	tw.tween_property(fx, "transparency", 0.0, 0.22)
	tw.tween_interval(maxf(secs - 0.47, 0.05))
	tw.tween_callback(func(): if is_instance_valid(fx): fx.fade_out(0.25))
	var br := fx.create_tween().set_loops()  # a slow breath
	br.tween_property(fx, "scale", Vector3(1.04, 1.06, 1.0), 0.55).set_trans(Tween.TRANS_SINE)
	br.tween_property(fx, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_SINE)


## A beam from `from` to `to`: the strip is stretched to the length it covers on screen, its flared end at the source.
static func _sheet_beam(parent: Node3D, look_name: String, from: Vector3, to: Vector3, secs: float) -> void:
	if not _room(parent) or from.distance_to(to) < 0.05:
		return
	var sc := _screen_of(parent, to - from)
	var w := maxf(sc.y, 0.3) * FRAME_PX.x / BEAM_PX
	var fx := _fx(parent, _strip(look_name, "beam"), Vector2(w, 1.25), secs, false)
	var mid := (from + to) / 2.0
	fx.global_transform = Transform3D(_facing(parent, sc.x), mid)


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
