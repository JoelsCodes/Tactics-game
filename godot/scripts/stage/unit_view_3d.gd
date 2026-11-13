class_name UnitView3D
extends Node3D
## One character standing on the 3D board: an upright `AnimatedSprite3D` billboard (turns only around
## Y to face the camera, nearest filtering) playing the sheet's animations, with an invisible capsule
## that casts its shadow (a flat billboard only casts a hairline). The node's origin is the feet.
##
## Animations go through a SpriteAnimator (the state machine: movement per direction, one-shot actions
## with a strike frame, hurt interrupting, ko holding its last frame); eight-direction characters such as
## the King pick the drawn direction, older sheets use front/back frames mirrored left/right. Tints
## (vessels, enemies), the KO gray and wading are done with `modulate` and the sprite's height, since a
## sprite's own shader is not available on Sprite3D. Effects from the character's sheet (slash,
## eruption, circle, burst, smoke) play with `spawn_fx`.

signal struck(action: String)  ## an action reached its visible impact frame
signal action_finished(action: String)

const BODY_HEIGHT := 1.25
const WADE_DEPTH := 0.22  ## how far the feet sink into shallow water (units)

var char_name := ""
var animator: SpriteAnimator
var sprite := AnimatedSprite3D.new()
var body := MeshInstance3D.new()
var _meta: Dictionary
var _base := Color.WHITE  ## warm light plus the side's tint
var _gray := 0.0
var _stretch := 1.0
var _size := 1.0  ## uniform size factor from the board: keeps the unit the same size on screen near or far
var _wading := false
var _shift_x := 0.0  ## pixels from the frame's centre to the sheet's anchor (feet): the sprite is moved so the feet are at the origin
var guard_icon: Sprite3D  ## a shield over the head while the unit guards (Defend)
var flash_sprite: Sprite3D  ## the white silhouette shown in place of the sprite while a hit flashes (see hit_react)
var _flashing := false  ## white for a few frames after a hit (see hit_react)
var status_fx: StatusFx  ## the marks of the statuses on it (floating z, orbiting stars...), fed by BattleStage
var trail_color := Color(0, 0, 0, 0)  ## alpha > 0: leaves afterimages while it walks (a hasted unit)
var _trail_left := 0.0  ## seconds of afterimages still to leave (afterimages())
var _trail_acc := 0.0
var _trail_nodes: Array = []  ## the afterimages alive now
var _trail_tint := Color(1, 1, 1, 0.5)
var ghost: Sprite3D  ## the see-through silhouette shown where the ground hides the unit (set_ghost; shaders/unit_ghost.gdshader)
var _ghost_tex: Texture2D
var _flash_id := 0  ## a flash ends only if no newer hit restarted it
var _knock := Vector3.ZERO  ## how far a hit has pushed the sprite from the tile's centre (world units)
var _knock_tween: Tween
var _lunge := Vector3.ZERO  ## how far an attack has moved the sprite toward its target (world units; the unit's tile never changes)
var _lunge_tween: Tween
var _held := false  ## a frame is held as a still pose (hold)
var _orient := Basis.IDENTITY  ## the sprite's own orientation once the board takes over from the billboard (see set_orient)
var _use_orient := false


func setup(ch: String, tint := Color(1, 1, 1, 0), size := Board3D.UNIT_SCALE) -> void:
	char_name = ch
	_meta = Character.meta(ch)
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/characters/%s.tres" % Character.sheet(ch))
	sprite.pixel_size = Character.SPRITE_SCALE * size * float(_meta.get("scale", 1.0)) / Board3D.PX_PER_UNIT
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # crisp pixels: no mipmaps, no blending
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_shift_x = _meta.size[0] / 2.0 - _meta.anchor[0]
	sprite.offset = Vector2(_shift_x, _meta.anchor[1] - _meta.size[1] / 2.0)  # feet on the origin, centred on the tile
	sprite.shaded = false  # a camera-facing quad lit by the sun from the side reads as a dark cutout
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_base = Color(1.0, .96, .9).lerp(Color(tint.r, tint.g, tint.b), tint.a * 1.6)
	add_child(sprite)
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = BODY_HEIGHT
	body.name = "ShadowBody"
	body.mesh = cap
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(body)
	_refresh()
	status_fx = StatusFx.new(self)
	add_child(status_fx)
	animator = SpriteAnimator.new(sprite, _meta)
	animator.struck.connect(func(a): struck.emit(a))
	animator.finished.connect(func(a): action_finished.emit(a))
	play("idle")
	sprite.set_frame_and_progress(randi() % 4, randf())


## Undo the camera's foreshortening: the sprite is stretched by `k` = 1 / cos(pitch) on Y, so on screen
## it has its drawn proportions while it stays vertical. The shadow body keeps its real height.
func fit(k: float, m := 1.0) -> void:
	_stretch = k
	_size = m
	if _use_orient:
		sprite.basis = _orient * Basis.from_scale(Vector3(m, m * k, m))
	else:
		sprite.scale = Vector3(m, m * k, m)
	_refresh()


## The board orients the sprite itself (instead of the fixed-Y billboard) so it can stand upright ON SCREEN: a perspective camera makes a
## vertical line away from the screen's middle lean outward, and the board turns the sprite back by that lean (Board3D.upright_orient).
## `b` is the orientation the billboard would have, rolled about the view axis. Call before `fit`.
func set_orient(b: Basis) -> void:
	_orient = b
	if not _use_orient:
		_use_orient = true
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		if flash_sprite != null:
			flash_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED


## Breathing while idle: idle is one still frame, so the body rises and settles by about 1% (feet stay
## planted: the sprite scales from its feet).
const FLASH_TIME := 0.08  ## seconds a hit unit stays white: about five frames
const KNOCK_DISTANCE := 0.16  ## how far a hit pushes the unit back (world units: a tile is 1)
const KNOCK_OUT := 0.05  ## seconds to be pushed out ...
const KNOCK_BACK := 0.24  ## ... and eased back to the centre of the tile
const BREATH := 0.012
const BREATH_SPEED := 2.2
var _t := randf() * TAU


func _process(delta: float) -> void:
	_leave_trail(delta)
	sprite.offset.x = -_shift_x if sprite.flip_h else _shift_x  # a mirrored frame has its feet on the other side
	var shift := _knock + _lunge  # a hit's knock-back and an attack's lunge move the sprite and its shadow body, never the unit's own position
	sprite.position.x = shift.x
	sprite.position.z = shift.z
	body.position.x = shift.x
	body.position.z = shift.z
	_t += delta * BREATH_SPEED
	var idle := animator != null and animator.state == SpriteAnimator.State.MOVE and animator.move == "idle"
	if idle and animator.dirs8() and sprite.sprite_frames != null and sprite.sprite_frames.get_frame_count(sprite.animation) > 1:
		idle = false  # a drawn idle (alaric_v2's) already breathes: no extra scale wobble on top (other characters keep it)
	var ys := _stretch * _size * (1.0 + (BREATH * sin(_t) if idle else 0.0))
	if _use_orient:
		sprite.basis = _orient * Basis.from_scale(Vector3(_size, ys, _size))
	else:
		sprite.scale.y = ys
	if ghost != null:
		_sync_ghost()
	if _flashing:  # the white silhouette of the frame on show, placed exactly over the hidden sprite
		var ft := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if ft != flash_sprite.texture:
			flash_sprite.texture = ft  # sizes the quad; the shader draws it flat white from the same picture
			(flash_sprite.material_override as ShaderMaterial).set_shader_parameter("tex", ft)
		flash_sprite.offset = sprite.offset
		flash_sprite.flip_h = sprite.flip_h
		if _use_orient:
			flash_sprite.basis = sprite.basis
		else:
			flash_sprite.scale = sprite.scale
		flash_sprite.position = sprite.position


## Plays a one-shot action (attack, heavy, cast, hit), then returns to the movement animation. Hurt
## interrupts other actions; nothing plays over a knocked-out unit.
func act(a: String) -> bool:
	return animator.play_action(a)


## Movement (idle, walk, run, dash) or a held state: "ko" (plays once, holds the last frame), "victory".
## Asking for what already plays changes nothing.
func play(a: String) -> void:
	match a:
		"ko":
			animator.die()
		"victory":
			animator.pose("victory")
		_:
			if _held:
				release()
			if animator.state == SpriteAnimator.State.DEAD:
				animator.revive()
			animator.set_move(a)


## Holds one frame of an action as a still pose (the King's hunched hurt frame is Alaric slumped, worn out).
## `release` (or any new `play`) goes back to the movement animation.
func hold(a: String, frame: int) -> void:
	if a == "hit" and _meta.has("slump"):
		frame = int(_meta.slump)  # a sheet says which of its hurt frames shows him hunched over (alaric_v2: the peak)
	animator.clear_action()
	animator.play_action(a)
	var last := sprite.sprite_frames.get_frame_count(sprite.animation) - 1  # a sheet with a shorter animation holds its last frame
	sprite.set_frame_and_progress(clampi(frame, 0, maxi(last, 0)), 0.0)
	sprite.pause()
	_held = true


func release() -> void:
	_held = false
	animator.clear_action()


## Sets which way the character looks on screen (x right, y down; y < 0 = away from the viewer).
## A zero vector keeps the last facing.
func face(screen_dir: Vector2) -> void:
	animator.face(screen_dir)


## True when a blow plays the character's hurt animation (`plays_hit` in meta.json: Alaric's; the older sheets only flash and recoil).
func plays_hit() -> bool:
	return bool(_meta.get("plays_hit", false)) and animator.has_anim("hit_s")


## True when the character's melee frames already draw the slash arc (the Squire's), so no slash effect is added on top.
func slash_in_frames() -> bool:
	return bool(_meta.get("slash_in_frames", false))


## True when this character's sheet has the animation (e.g. "run_e", "heavy").
func has_anim(a: String) -> bool:
	return animator.has_anim(a) or animator.has_anim(a + "_s") or animator.has_anim(a + "_f")


## Plays one of the character's effects (meta.effects: slash, eruption, circle, burst, smoke, ...) once,
## as an upright billboard at `at` (world, relative to the board), then frees it. Returns the node, or
## null when the sheet has no such effect.
func spawn_fx(fx: String, at: Vector3, size := 1.0, tint := Color.WHITE) -> Node3D:
	var def: Dictionary = _meta.get("effects", {}).get(fx, {})
	if def.is_empty() or get_parent() == null:
		return null
	var frames := SpriteFrames.new()
	frames.add_animation("fx")
	frames.set_animation_loop("fx", false)
	frames.set_animation_speed("fx", float(def.get("fps", 14)))
	for f in def.frames:
		frames.add_frame("fx", load("res://assets/characters/%s/%s" % [_meta.get("effects_from", Character.sheet(char_name)), f]))
	var s := AnimatedSprite3D.new()
	s.sprite_frames = frames
	s.pixel_size = sprite.pixel_size * size
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.modulate = tint
	s.render_priority = 2
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.scale = Vector3(1, _stretch, 1)
	var tex: Texture2D = frames.get_frame_texture("fx", 0)
	s.offset = Vector2(0, tex.get_height() / 2.0)  # stands on the point
	s.position = at
	get_parent().add_child(s)
	s.animation_finished.connect(s.queue_free)
	s.play("fx")
	return s


## A blow lands: the sprite flashes white for `flash_time` seconds and the unit is knocked back `distance` along `dir`
## (world, horizontal: from the attacker toward this unit), starting after `delay` seconds (a hitstop), then eased back
## to the centre of its tile. Only the sprite moves, so a walk or a slide in progress is not disturbed. A zero `dir`
## flashes only; a `flash_time` of 0 (reduced flashes) only recoils.
func hit_react(dir: Vector3, distance := KNOCK_DISTANCE, flash_time := FLASH_TIME, delay := 0.0) -> void:
	if not is_inside_tree():
		return
	dir.y = 0.0
	_flash_id += 1
	var id := _flash_id
	if flash_time > 0.0:
		_show_flash(true)
	if dir.length() > 0.001 and distance > 0.0:
		dir = dir.normalized()
		if _knock_tween:
			_knock_tween.kill()
		_knock_tween = create_tween()
		if delay > 0.0:
			_knock_tween.tween_interval(delay)
		_knock_tween.tween_property(self, "_knock", dir * distance, KNOCK_OUT).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_knock_tween.tween_property(self, "_knock", Vector3.ZERO, KNOCK_BACK).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_knock_tween.tween_callback(func(): _knock = Vector3.ZERO)  # exactly on the tile again, whatever the easing left
	if flash_time > 0.0:
		await get_tree().create_timer(flash_time).timeout
		if id == _flash_id:
			_show_flash(false)


## The attacker's wind-up: the sprite leans a little away from the target (`dir` points at the target).
func anticipate(dir: Vector3, distance: float, secs := 0.12) -> void:
	dir.y = 0.0
	if not is_inside_tree() or dir.length() < 0.001:
		return
	_lunge_to(-dir.normalized() * distance, secs, Tween.EASE_OUT)


## The attacker's strike: a quick step toward the target, held through the hitstop, then back to the tile centre.
func lunge(dir: Vector3, distance: float, hold := 0.0, in_secs := 0.05, out_secs := 0.2) -> void:
	dir.y = 0.0
	if not is_inside_tree() or dir.length() < 0.001:
		return
	if _lunge_tween:
		_lunge_tween.kill()
	_lunge_tween = create_tween()
	distance = maxf(distance, _lunge.dot(dir.normalized()))  # a dash that already carried it further stays there for the blow
	_lunge_tween.tween_property(self, "_lunge", dir.normalized() * distance, in_secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if hold > 0.0:
		_lunge_tween.tween_interval(hold)
	_lunge_tween.tween_property(self, "_lunge", Vector3.ZERO, out_secs).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_lunge_tween.tween_callback(func(): _lunge = Vector3.ZERO)


func _lunge_to(v: Vector3, secs: float, ease_kind: int) -> void:
	if _lunge_tween:
		_lunge_tween.kill()
	_lunge_tween = create_tween()
	_lunge_tween.tween_property(self, "_lunge", v, secs).set_ease(ease_kind).set_trans(Tween.TRANS_QUAD)


## Hitstop: the sprite's animation stops (`on`) or runs again. Only the picture freezes; the battle, the HUD and input go on.
func freeze(on: bool) -> void:
	sprite.speed_scale = 0.0 if on else 1.0


## How far the sprite is off the tile's centre now (knock-back plus lunge): things that ride the unit follow it.
func visual_shift() -> Vector3:
	return _knock + _lunge


## A quick forward step toward `dir` (a world direction) by `distance`, with afterimages behind it: the dash of a fast skill. Only the
## picture moves; `lunge` (or reset_motion) brings it back to the tile.
func dash(dir: Vector3, distance: float, secs := 0.12, trail := Color(1, 1, 1, 0.5)) -> void:
	dir.y = 0.0
	if not is_inside_tree() or dir.length() < 0.001:
		return
	_lunge_to(dir.normalized() * distance, secs, Tween.EASE_OUT)
	afterimages(secs + 0.08, trail)


## Leaves fading afterimages of the unit for `secs` seconds: copies of its current frame as a flat colour, one every few frames, each
## fading out in a fraction of a second. Presentation only; they belong to the board, never to the unit.
func afterimages(secs: float, tint := Color(1, 1, 1, 0.5)) -> void:
	_trail_left = maxf(_trail_left, secs)
	_trail_tint = tint


const TRAIL_EVERY := 0.035  ## seconds between afterimages
const TRAIL_LIFE := 0.3  ## seconds an afterimage takes to fade
const TRAIL_MAX := 14  ## afterimages of one unit alive at once


func _leave_trail(delta: float) -> void:
	var walking := trail_color.a > 0.0 and animator != null and animator.state == SpriteAnimator.State.MOVE and animator.move != "idle"
	if _trail_left <= 0.0 and not walking:
		_trail_acc = 0.0
		return
	_trail_left = maxf(_trail_left - delta, 0.0)
	_trail_acc += delta
	if _trail_acc < (TRAIL_EVERY if _trail_left > 0.0 else TRAIL_EVERY * 1.8):
		return
	_trail_acc = 0.0
	_spawn_afterimage(_trail_tint if _trail_left > 0.0 else trail_color)


func _spawn_afterimage(tint: Color) -> void:
	var host := get_parent()
	if host == null or sprite.sprite_frames == null or not sprite.visible or sprite.modulate.a < 0.95:
		return
	_trail_nodes = _trail_nodes.filter(func(n): return is_instance_valid(n))
	if _trail_nodes.size() >= TRAIL_MAX:
		return
	var a := Sprite3D.new()
	a.set_meta("afterimage_of", self)
	a.name = "Afterimage"
	var ft := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	a.texture = ft
	var fm := _flat_material(ft, false)
	fm.set_shader_parameter("tint", tint)
	a.material_override = fm
	a.pixel_size = sprite.pixel_size
	a.offset = sprite.offset
	a.flip_h = sprite.flip_h
	a.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.billboard = sprite.billboard
	host.add_child(a)
	_trail_nodes.append(a)
	a.global_transform = sprite.global_transform
	var tw := a.create_tween()
	tw.tween_property(fm, "shader_parameter/tint", Color(tint.r, tint.g, tint.b, 0.0), TRAIL_LIFE)
	tw.tween_callback(a.queue_free)


## Puts every temporary visual offset back: the flash, the knock-back, the lunge and a frozen animation.
func reset_motion() -> void:
	for t in [_knock_tween, _lunge_tween]:
		if t:
			t.kill()
	_knock = Vector3.ZERO
	_lunge = Vector3.ZERO
	_trail_left = 0.0
	sprite.speed_scale = 1.0
	_flash_id += 1
	if flash_sprite != null:
		_show_flash(false)


## Shows a see-through silhouette of the unit in `color` (its alpha is the strength) wherever the ground or a wall hides it, and only
## there (the shader compares depths): a unit in plain view looks the same. Turning the battle view (Z / C) makes it matter most.
func set_ghost(color: Color) -> void:
	if ghost == null:
		ghost = Sprite3D.new()
		ghost.name = "Ghost"
		ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/unit_ghost.gdshader")
		ghost.material_override = m
		add_child(ghost)
	(ghost.material_override as ShaderMaterial).set_shader_parameter("tint", color)
	_sync_ghost()


func _sync_ghost() -> void:
	var show := sprite.visible and sprite.modulate.a > 0.95 and sprite.sprite_frames != null
	ghost.visible = show
	if not show:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex != _ghost_tex:
		_ghost_tex = tex
		ghost.texture = tex  # sizes the quad; the shader reads the same picture
		(ghost.material_override as ShaderMaterial).set_shader_parameter("tex", tex)
	ghost.pixel_size = sprite.pixel_size
	ghost.billboard = sprite.billboard
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.transform = sprite.transform


## Swaps the sprite for its white silhouette (`on`) or back. Sprite3D modulate can only darken, so the white is a
## second sprite showing the current frame with every drawn pixel white.
func _show_flash(on: bool) -> void:
	if flash_sprite == null:
		flash_sprite = Sprite3D.new()
		flash_sprite.name = "Flash"
		flash_sprite.pixel_size = sprite.pixel_size
		flash_sprite.billboard = sprite.billboard
		if _use_orient:
			flash_sprite.basis = sprite.basis
		flash_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		flash_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		flash_sprite.shaded = false
		flash_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash_sprite.material_override = _flat_material(null, true)  # flat white from the frame's own alpha (shaders/unit_flat.gdshader)
		add_child(flash_sprite)
	_flashing = on
	flash_sprite.visible = on
	sprite.visible = not on
	if on:
		_process(0.0)  # shows the silhouette at once, not a frame later


## A flat-colour material that draws `tex`'s shape (shaders/unit_flat.gdshader). `hard`: the flash's crisp white; else soft, for afterimages.
func _flat_material(tex: Texture2D, hard: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/unit_flat.gdshader")
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("hard", hard)
	m.set_shader_parameter("tint", Color.WHITE)
	m.render_priority = 1
	return m



## Knocked out: grayed and darkened (0 = normal, 1 = full gray).
func set_gray(g: float) -> void:
	_gray = g
	_refresh()


## Standing in shallow water: the feet sink below the surface.
func set_wading(on: bool) -> void:
	_wading = on
	_refresh()


func _refresh() -> void:
	var c := _base
	if _gray > 0.0:
		var l := c.get_luminance()
		c = c.lerp(Color(l, l, l), _gray) * (1.0 - _gray * 0.35)
	sprite.modulate = Color(c.r, c.g, c.b, sprite.modulate.a)
	sprite.position.y = -WADE_DEPTH if _wading else 0.0
	body.position.y = BODY_HEIGHT / 2.0 + 0.05


## Height of the top of the head above the feet (world units, with the camera stretch). Sheets are cut
## with the body from about 10 px below the top of the frame down to the feet at meta.anchor.
func head_height() -> float:
	return (_meta.anchor[1] - 10.0) * sprite.pixel_size * _stretch * _size


## Height of the drawn figure above its feet (world units, with the camera stretch): from the top drawn pixel of the first idle frame
## down to the anchor. `head_height` is the top of the frame, which is well above most figures. Measured once per sheet.
static var _figure_px := {}  ## sheet name -> drawn pixels from the top of the figure to the feet


func figure_height() -> float:
	if not _figure_px.has(char_name):
		var px := float(_meta.anchor[1]) - 10.0
		var frames := sprite.sprite_frames
		var anim := "idle_s" if frames != null and frames.has_animation("idle_s") else String(sprite.animation)
		if frames != null and frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			var tex := frames.get_frame_texture(anim, 0)
			var img := tex.get_image() if tex != null else null
			if img != null:
				if img.is_compressed():
					img.decompress()
				var used := img.get_used_rect()
				var top := float(used.position.y) + (float((tex as AtlasTexture).margin.position.y) if tex is AtlasTexture else 0.0)
				if used.size.y > 0:
					px = clampf(float(_meta.anchor[1]) - top, 8.0, float(_meta.anchor[1]))
		_figure_px[char_name] = px
	return float(_figure_px[char_name]) * sprite.pixel_size * _stretch * _size


## Shows or hides the guard shield over the head.
func set_guard(on: bool) -> void:
	if on and guard_icon == null:
		guard_icon = Sprite3D.new()
		guard_icon.texture = HudStyle.icon("defend")
		guard_icon.pixel_size = 0.43 / guard_icon.texture.get_width()  # about 0.43 units wide, any icon size
		guard_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		guard_icon.no_depth_test = true
		guard_icon.shaded = false
		guard_icon.modulate = Color.WHITE if HudStyle.custom_icon("defend") else Color(0.55, 0.92, 1.0)
		guard_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		guard_icon.render_priority = 5
		add_child(guard_icon)
	if guard_icon:
		guard_icon.visible = on
		guard_icon.position.y = head_height() + 0.35


## Fades the sprite (vessels appearing and leaving).
func set_alpha(a: float) -> void:
	sprite.modulate.a = a
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if a >= 0.999 else SpriteBase3D.ALPHA_CUT_DISABLED
	body.visible = a > 0.5


func get_alpha() -> float:
	return sprite.modulate.a
