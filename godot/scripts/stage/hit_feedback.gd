class_name HitFeedback
extends Node
## The combat feedback controller: what an attack looks, moves and sounds like, kept apart from the rules. BattleStage hands it
## an action's ActionResult (the numbers are already decided by BattleController) and it only presents them:
##
##   anticipation  the attacker leans back (`anticipate`)
##   impact        on the strike frame, or when a projectile arrives: hitstop (the attacker's and target's animation
##                 freezes), white flash, recoil (starts when the hitstop ends), lunge, particles, camera shake, the damage
##                 number and the sounds, all at the same instant (`play_hits` / `_land`)
##   recovery      the lunge and recoil ease back; everything ends exactly on the tile
##
## Feedback profiles live in `data/hit_profiles.json` (sword, dagger, hammer, bow, magic, plus the `critical` modifiers and
## per-skill `overrides`); `profile_for` picks one. Nothing here changes a unit's cell, HP or the turn: a stuck effect can
## cost a few frames of looks, never the battle (every freeze has a timer and `cleanup` puts everything back).

signal settled  ## every hit this controller was asked to show has finished

const PROFILE_PATH := "res://data/hit_profiles.json"
const SETTINGS_PATH := "user://settings.cfg"
const RANGED_TILES := 3  ## a physical blow from this far away or more is a thrown or shot projectile
const MAX_HITSTOP := 0.14  ## seconds: no profile can freeze the picture longer than this
const MAX_BURSTS := 24  ## live particle bursts at once; more are skipped
const MAX_COUNT := 24  ## particles in one burst
const NUMBER_STEP := 0.3  ## vertical gap between damage numbers stacked over one unit

static var reduce_shake := false  ## accessibility: no camera shake
static var reduce_flash := false  ## accessibility: no white flashes (the recoil and the numbers remain)
static var _data := {}
static var _settings_loaded := false
static var _mats := {}  ## particle kind -> shared material

var board: Board3D
var fx_root: Node3D
var views: Dictionary  ## BattleUnit -> UnitView3D (the stage's own dictionary)
var enabled := true
var _busy := 0  ## hits still being shown
var _freezes := {}  ## UnitView3D -> the id of the freeze that owns it now
var _freeze_id := 0
var _shake_tween: Tween
var _bursts := 0
var _live_numbers := {}  ## BattleUnit -> how many of its damage numbers are still on screen
var _last_shake_amount := 0.0  ## the strongest shake asked for (tests read it)
var log: Array[Dictionary] = []  ## what was shown, newest last, capped (tests read it)


func setup(b: Board3D, root: Node3D, v: Dictionary) -> void:
	board = b
	fx_root = root
	views = v
	load_settings()


# ---------- settings ----------

static func load_settings() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		reduce_shake = bool(cf.get_value("accessibility", "reduce_shake", false))
		reduce_flash = bool(cf.get_value("accessibility", "reduce_flash", false))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("accessibility", "reduce_shake", reduce_shake)
	cf.set_value("accessibility", "reduce_flash", reduce_flash)
	cf.save(SETTINGS_PATH)


# ---------- profiles ----------

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = parsed if parsed is Dictionary else {"profiles": {"sword": {}}, "critical": {}, "element_colors": {}, "overrides": {}}
	return _data


## The feedback profile for one hit: the skill's override by name, else its animation and category (a heavy blow is the
## hammer, a physical blow from RANGED_TILES away a projectile, anything else physical a sword, every other proficiency magic),
## with the `critical` modifiers on top when `crit`. A fresh Dictionary: callers may change it.
static func profile_for(a: BattleAction, anim: String, crit: bool, distance: int) -> Dictionary:
	var d := data()
	var profiles: Dictionary = d.get("profiles", {})
	var name := ""
	var extra := {}
	if a != null and a.skill != null:
		var ov: Dictionary = d.get("overrides", {}).get(a.skill.display_name, {})
		extra = ov.duplicate()
		name = String(extra.get("profile", ""))
		extra.erase("profile")
	if name == "" or not profiles.has(name):
		var physical := a == null or a.category() == Proficiency.Category.PHYSICAL
		if physical:
			name = "hammer" if anim == "heavy" else ("bow" if distance >= RANGED_TILES else "sword")
		else:
			name = "magic"
	var p: Dictionary = profiles.get(name, profiles.get("sword", {})).duplicate()
	p.merge(extra, true)
	p["name"] = name
	if a != null and a.skill != null and not physical_skill(a):
		var look := SkillLook.of(a.skill)
		if look != "":
			p["look"] = look  # the shared effect library dresses this skill (the "magic" particles stay out of it)
	if a != null and a.skill != null and name == "magic" and not extra.has("color"):
		var ec: Dictionary = d.get("element_colors", {})
		if ec.has(a.skill.effect):
			p["color"] = ec[a.skill.effect]
	if crit:
		var c: Dictionary = d.get("critical", {})
		p["hitstop_ms"] = float(p.get("hitstop_ms", 60)) + float(c.get("hitstop_add_ms", 0))
		p["recoil"] = float(p.get("recoil", 0.1)) * float(c.get("recoil_mult", 1.0))
		p["shake"] = maxf(float(p.get("shake", 0.0)) * float(c.get("shake_mult", 1.0)), float(c.get("shake_min", 0.0)))
		p["flash_ms"] = float(p.get("flash_ms", 60)) + float(c.get("flash_add_ms", 0))
		p["count"] = int(float(p.get("count", 6)) * float(c.get("count_mult", 1.0)))
		p["number_scale"] = float(p.get("number_scale", 1.0)) * float(c.get("number_scale_mult", 1.0))
		if c.has("sfx_impact"):
			p["sfx_impact"] = c["sfx_impact"]
		p["crit"] = true
	return p


static func physical_skill(a: BattleAction) -> bool:
	return a == null or a.category() == Proficiency.Category.PHYSICAL


# ---------- the attack ----------

## The attacker's anticipation, when its animation starts: it leans back from the target and the swing sound plays.
func anticipate(bu: BattleUnit, a: BattleAction, anim: String, at: Vector2i) -> void:
	if not enabled or board == null:
		return
	var v: UnitView3D = views.get(bu)
	if v == null or not v.is_inside_tree():
		return
	var p := profile_for(a, anim, false, absi(bu.cell.x - at.x) + absi(bu.cell.y - at.y))
	CombatAudio.play(self, String(p.get("sfx_swing", "")))
	if p.has("look") and fx_root != null and v.is_inside_tree():
		EffectLibrary.ring(fx_root, String(p.look), v.global_position, 0.55)  # the cast gathers at the caster's feet
	if bool(p.get("melee", false)) and float(p.get("lunge", 0.0)) > 0.0:
		v.anticipate(_dir_to(v, at), float(p.lunge) * 0.4)


## Shows every hit of an action at the moment of impact. Hits that are not damage (a heal, a miss) get their number only.
func play_hits(attacker: BattleUnit, r: ActionResult, anim: String, at: Vector2i) -> void:
	if not enabled:
		return
	var area_look := ""
	if r.hits.size() > 1 and r.action != null and r.action.skill != null and fx_root != null and board != null and not physical_skill(r.action):
		area_look = SkillLook.of(r.action.skill)
	if area_look != "":
		# an area skill: ONE projectile flies to the aimed tile, a ring opens there, then every target is hit together
		var av: UnitView3D = views.get(attacker)
		var centre := board.to_global(board.top_point(at.x, at.y))
		if av != null and av.is_inside_tree() and absi(attacker.cell.x - at.x) + absi(attacker.cell.y - at.y) >= 2:
			await EffectLibrary.projectile(fx_root, area_look, av.global_position + Vector3(0, 0.9, 0), centre + Vector3(0, 0.6, 0))
		EffectLibrary.ring(fx_root, area_look, centre, 1.3)
	for h in r.hits:
		_hit(attacker, r.action, h, anim, area_look != "")


func busy() -> bool:
	return _busy > 0


func _hit(attacker: BattleUnit, a: BattleAction, h: ActionResult.Hit, anim: String, flew_already := false) -> void:
	_busy += 1
	var tv: UnitView3D = views.get(h.target)
	var av: UnitView3D = views.get(attacker)
	var dist := absi(attacker.cell.x - h.target.cell.x) + absi(attacker.cell.y - h.target.cell.y)
	if h.missed:
		number(h.target, "Resisted" if h.resisted else "Miss", "resist" if h.resisted else "miss")
		CombatAudio.play(self, "miss")
	elif h.heal:
		number(h.target, "+%d" % h.amount if h.amount > 0 else "", "heal")
		var heal_look := SkillLook.of(a.skill) if a != null and a.skill != null else ""
		if tv != null and heal_look != "" and fx_root != null and tv.is_inside_tree():
			EffectLibrary.aura(fx_root, heal_look, tv.global_position, 1.3)  # the sheet's aura wraps the one healed
			if h.amount > 0:
				CombatAudio.play(self, "heal")
		elif tv != null and h.amount > 0:
			_burst(tv, "heal", Color(0.5, 1.0, 0.65), 8, Vector3.ZERO)
			CombatAudio.play(self, "heal")
		for n in h.notes:
			number(h.target, n, "note")
	else:
		var p := profile_for(a, anim, h.crit, dist)
		if p.has("look") and tv != null and tv.is_inside_tree() and h.target.team == attacker.team and h.amount <= 0:
			# a buff or support on a friend (no damage): the aura, no flash and no burst
			EffectLibrary.aura(fx_root, String(p.look), tv.global_position, 1.3)
			for n in h.notes:
				number(h.target, n, "note")
			_busy -= 1
			if _busy <= 0:
				_busy = 0
				settled.emit()
			return
		if p.has("look") and not flew_already and av != null and tv != null and av.is_inside_tree() and tv.is_inside_tree() and dist >= 2:
			await EffectLibrary.projectile(fx_root, String(p.look), av.global_position + Vector3(0, 0.9, 0), tv.global_position + Vector3(0, 0.8, 0))
		elif bool(p.get("projectile", false)) and av != null and tv != null and dist >= 2 and h.amount > 0:
			await _fly(av, tv, p)
		_land(attacker, av, h, tv, p)
		var secs := minf(float(p.get("hitstop_ms", 0.0)) / 1000.0, MAX_HITSTOP)
		if h.knocked_out and tv != null:  # the fall waits for the freeze to end, so the blow is seen before the unit drops
			if secs > 0.0:
				await get_tree().create_timer(secs, true, false, true).timeout
			if is_instance_valid(tv):
				tv.play("ko")
				tv.set_gray(0.45)
				CombatAudio.play(self, "ko")
	_busy -= 1
	if _busy <= 0:
		_busy = 0
		settled.emit()


## The impact itself: all of it at one instant.
func _land(attacker: BattleUnit, av: UnitView3D, h: ActionResult.Hit, tv: UnitView3D, p: Dictionary) -> void:
	var secs := minf(float(p.get("hitstop_ms", 0.0)) / 1000.0, MAX_HITSTOP)
	var dir := Vector3.ZERO
	if tv != null and av != null and tv != av:
		dir = tv.position - av.position
		dir.y = 0.0
	if h.amount > 0 or not h.notes.is_empty():
		var text := ""
		if h.amount > 0:
			text = str(h.amount)
		for n in h.notes:
			text = n if text == "" else text + "  " + n
		number(h.target, text, "crit" if h.crit else ("block" if h.blocked else ("damage" if h.amount > 0 else "note")), float(p.get("number_scale", 1.0)))
	if p.has("look") and tv != null and tv.is_inside_tree() and fx_root != null:
		EffectLibrary.burst(fx_root, String(p.look), tv.global_position + Vector3(0, 0.7, 0), 1.0 if h.amount > 0 else 0.7)
	if h.amount <= 0:
		return
	CombatAudio.play(self, String(p.get("sfx_impact", "")))
	if h.blocked:
		CombatAudio.play(self, "block")
	entry_log({"hit": h.target.data.display_name, "profile": p.get("name", ""), "hitstop": secs, "recoil": float(p.get("recoil", 0.0)), "crit": h.crit, "blocked": h.blocked, "amount": h.amount})
	var flash := 0.0 if reduce_flash else float(p.get("flash_ms", 60)) / 1000.0
	if tv != null:
		var recoil := float(p.get("recoil", 0.1)) * (0.5 if h.blocked else 1.0)
		tv.hit_react(dir, recoil, flash, secs)
		if tv.plays_hit() and not h.knocked_out:
			tv.act("hit")  # the drawn hurt animation, on top of the flash and the recoil (a knockout plays its own fall)
		if not p.has("look"):  # a skill with the library's burst does not also throw the plain particles
			_burst(tv, String(p.get("particles", "sparks")), _color(p), int(p.get("count", 6)), -dir.normalized() if dir.length() > 0.001 else Vector3.ZERO)
	var freeze: Array = []
	if tv != null:
		freeze.append(tv)
	if av != null and av != tv and bool(p.get("melee", false)):
		freeze.append(av)
		av.lunge(dir, float(p.get("lunge", 0.0)) * (0.6 if reduce_shake else 1.0), secs)
	hitstop(freeze, secs)
	var amount := float(p.get("shake", 0.0))
	if amount > 0.0 and tv != null:
		shake(_screen_dir(dir), amount)


# ---------- hitstop ----------

## Freezes the sprites' animation for `seconds` (capped), then runs them again. Only the pictures stop: the battle logic, the UI and
## input are untouched, the timer ignores the engine's time scale, and a later freeze of the same unit takes over from an earlier one.
func hitstop(vs: Array, seconds: float) -> void:
	seconds = clampf(seconds, 0.0, MAX_HITSTOP)
	if seconds <= 0.0 or vs.is_empty():
		return
	_freeze_id += 1
	var id := _freeze_id
	for v in vs:
		if is_instance_valid(v):
			_freezes[v] = id
			v.freeze(true)
	await get_tree().create_timer(seconds, true, false, true).timeout
	for v in vs:
		if is_instance_valid(v) and _freezes.get(v, -1) == id:
			_freezes.erase(v)
			v.freeze(false)


func frozen() -> bool:
	return not _freezes.is_empty()


# ---------- camera ----------

## A short directional shake of the picture (the camera's offsets, put back exactly; never its position, lens or angle).
func shake(dir: Vector2, amount: float, secs := 0.16) -> void:
	if reduce_shake or board == null or board.cam == null or amount <= 0.0:
		return
	_last_shake_amount = maxf(_last_shake_amount, amount)
	if _shake_tween:
		_shake_tween.kill()
	var d := dir.normalized() if dir.length() > 0.001 else Vector2(0.0, 1.0)
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(t: float): board.set_shake(d * amount * (1.0 - t) * cos(t * TAU * 2.5)), 0.0, 1.0, secs)
	_shake_tween.tween_callback(func(): board.set_shake(Vector2.ZERO))


## Where a world-space blow points on the screen, in camera-offset terms (see Board3D.set_shake).
func _screen_dir(dir: Vector3) -> Vector2:
	if board == null or board.cam == null or dir.length() < 0.001:
		return Vector2(1.0, 0.0)
	var b := board.cam.global_transform.basis
	return Vector2(-dir.dot(b.x), -dir.dot(b.y))  # the image shifts by (-h_offset, +v_offset)


# ---------- projectile ----------

## A small bright bolt flies from the attacker to the target; the hit lands when it arrives.
func _fly(av: UnitView3D, tv: UnitView3D, p: Dictionary) -> void:
	CombatAudio.play(self, String(p.get("sfx_swing", "")))
	var m := MeshInstance3D.new()
	m.mesh = _quad_mesh(0.16)
	m.material_override = _material("bolt")
	fx_root.add_child(m)
	var from := av.global_position + Vector3(0, 0.9, 0)
	var to := tv.global_position + Vector3(0, 0.9, 0)
	m.global_position = from
	var secs := clampf(from.distance_to(to) / maxf(float(p.get("projectile_speed", 16.0)), 1.0), 0.06, 0.45)
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", to, secs)
	await tw.finished
	if is_instance_valid(m):
		m.queue_free()


# ---------- particles ----------

static func _quad_mesh(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


static func _material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true  # without it a billboard drops each particle's own scale and every quad is drawn at the mesh's full size
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.particles_anim_loop = false
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 5
	if kind in ["magic", "heal", "bolt", "sparks"]:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if kind == "bolt":
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(1.0, 0.95, 0.75)
	_mats[kind] = m
	return m


func _color(p: Dictionary) -> Color:
	var c: Array = p.get("color", [1.0, 1.0, 1.0])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## A one-shot burst at the target's contact point: sparks fly away from the attacker, dust rises and drifts, magic scatters and
## lingers. Few small quads on shared materials; at most MAX_BURSTS at once, each freed when it is over.
func _burst(tv: UnitView3D, kind: String, color: Color, count: int, away: Vector3) -> void:
	if fx_root == null or _bursts >= MAX_BURSTS or tv == null or not tv.is_inside_tree():
		return
	count = clampi(count, 1, MAX_COUNT)
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.amount = count
	ps.emitting = false
	ps.color = color
	ps.mesh = _quad_mesh(2.0)  # the kinds' sizes below are half-sizes: sparks come out 7 to 14 cm across
	ps.material_override = _material(kind)
	ps.local_coords = false
	var life := 0.3
	match kind:
		"dust":
			life = 0.55
			ps.direction = Vector3(away.x, 0.5, away.z)
			ps.spread = 70.0
			ps.initial_velocity_min = 0.4
			ps.initial_velocity_max = 1.2
			ps.gravity = Vector3(0, 0.3, 0)
			ps.scale_amount_min = 0.14
			ps.scale_amount_max = 0.26
		"magic":
			life = 0.6
			ps.direction = Vector3(0, 1, 0)
			ps.spread = 180.0
			ps.initial_velocity_min = 0.5
			ps.initial_velocity_max = 1.7
			ps.gravity = Vector3(0, 0.9, 0)
			ps.damping_min = 1.5
			ps.damping_max = 2.5
			ps.scale_amount_min = 0.05
			ps.scale_amount_max = 0.11
		"heal":
			life = 0.7
			ps.direction = Vector3(0, 1, 0)
			ps.spread = 35.0
			ps.initial_velocity_min = 0.5
			ps.initial_velocity_max = 1.0
			ps.gravity = Vector3(0, 0.4, 0)
			ps.scale_amount_min = 0.05
			ps.scale_amount_max = 0.09
		_:  # sparks
			ps.direction = Vector3(away.x, 0.4, away.z) if away.length() > 0.001 else Vector3(0, 1, 0)
			ps.spread = 55.0 if away.length() > 0.001 else 180.0
			ps.initial_velocity_min = 1.8
			ps.initial_velocity_max = 3.6
			ps.gravity = Vector3(0, -7.0, 0)
			ps.scale_amount_min = 0.035
			ps.scale_amount_max = 0.07
	ps.lifetime = life
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	fx_root.add_child(ps)
	ps.global_position = tv.global_position + Vector3(0, 0.55, 0) + away * 0.25
	ps.emitting = true
	_bursts += 1
	get_tree().create_timer(life + 0.25).timeout.connect(func():
		_bursts = maxi(0, _bursts - 1)
		if is_instance_valid(ps):
			ps.queue_free())


# ---------- damage numbers ----------

const NUMBER_STYLE := {  # kind -> [colour, size factor]
	"damage": [Color("#ffd27a"), 1.0],
	"crit": [Color("#ff6a3d"), 1.0],
	"block": [Color("#9cc3e6"), 0.9],
	"heal": [Color("#6be08a"), 1.0],
	"miss": [Color(0.75, 0.75, 0.8), 0.85],
	"resist": [Color("#b9a2e6"), 0.85],
	"note": [Color(0.9, 0.9, 1.0), 0.8],
}


## A number or word over a unit: it pops in (small, overshoot, settle), rises and fades. Numbers over the same unit stack so they stay readable.
func number(bu: BattleUnit, text: String, kind := "damage", scale_mult := 1.0) -> Label3D:
	if text == "" or board == null or fx_root == null:
		return null
	var style: Array = NUMBER_STYLE.get(kind, NUMBER_STYLE.damage)
	var l := Label3D.new()
	l.text = text + ("!" if kind == "crit" else "")
	l.font = HudStyle.font(true)
	l.font_size = 44
	l.outline_size = 14 if kind == "crit" else 12
	l.modulate = style[0]
	l.outline_modulate = Color(0.25, 0.04, 0.0, 0.95) if kind == "crit" else Color(0, 0, 0, 0.9)
	l.pixel_size = 0.011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	var stack := int(_live_numbers.get(bu, 0))
	_live_numbers[bu] = stack + 1
	var x := (0.14 if stack % 2 == 1 else -0.14) * minf(stack, 2)
	l.position = board.top_point(bu.cell.x, bu.cell.y) + Vector3(x, 2.3 + stack * NUMBER_STEP, 0)
	var size := float(style[1]) * scale_mult
	l.scale = Vector3.ONE * size * 0.4
	l.set_meta("kind", kind)
	fx_root.add_child(l)
	log.append({"number": text, "kind": kind, "unit": bu.data.display_name})
	if log.size() > 64:
		log.pop_front()
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * size * 1.3, 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "scale", Vector3.ONE * size, 0.09).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var rise := l.create_tween().set_parallel()
	rise.tween_property(l, "position:y", l.position.y + 0.6, 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	rise.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.55)
	rise.chain().tween_callback(func():
		_live_numbers[bu] = maxi(0, int(_live_numbers.get(bu, 1)) - 1)
		l.queue_free())
	return l


# ---------- housekeeping ----------

## Puts every view back exactly (animation running, no recoil, no lunge), the camera where the framing left it, and ends every effect.
func cleanup() -> void:
	for v in views.values():
		if is_instance_valid(v):
			v.reset_motion()
	_freezes.clear()
	if _shake_tween:
		_shake_tween.kill()
	if board != null:
		board.set_shake(Vector2.ZERO)
	_busy = 0


func entry_log(e: Dictionary) -> void:
	log.append(e)
	if log.size() > 64:
		log.pop_front()


func _dir_to(v: UnitView3D, at: Vector2i) -> Vector3:
	var d := board.top_point(at.x, at.y) - v.position
	d.y = 0.0
	return d


func _exit_tree() -> void:
	cleanup()
