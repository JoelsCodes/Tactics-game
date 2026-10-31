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
var _flash_id := 0  ## a flash ends only if no newer hit restarted it
var _knock := Vector3.ZERO  ## how far a hit has pushed the sprite from the tile's centre (world units)
var _knock_tween: Tween
static var _white_cache := {}  ## frame texture -> its all-white silhouette


func setup(ch: String, tint := Color(1, 1, 1, 0), size := Board3D.UNIT_SCALE) -> void:
	char_name = ch
	_meta = Character.meta(ch)
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/characters/%s.tres" % ch)
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
	sprite.scale = Vector3(m, m * k, m)
	_refresh()


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
	sprite.offset.x = -_shift_x if sprite.flip_h else _shift_x  # a mirrored frame has its feet on the other side
	sprite.position.x = _knock.x  # a hit's knock-back moves the sprite and its shadow body, never the unit's own position
	sprite.position.z = _knock.z
	body.position.x = _knock.x
	body.position.z = _knock.z
	_t += delta * BREATH_SPEED
	var idle := animator != null and animator.state == SpriteAnimator.State.MOVE and animator.move == "idle"
	sprite.scale.y = _stretch * _size * (1.0 + (BREATH * sin(_t) if idle else 0.0))
	if _flashing:  # the white silhouette of the frame on show, placed exactly over the hidden sprite
		flash_sprite.texture = _white(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
		flash_sprite.offset = sprite.offset
		flash_sprite.flip_h = sprite.flip_h
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
			if animator.state == SpriteAnimator.State.DEAD:
				animator.revive()
			animator.set_move(a)


## Sets which way the character looks on screen (x right, y down; y < 0 = away from the viewer).
## A zero vector keeps the last facing.
func face(screen_dir: Vector2) -> void:
	animator.face(screen_dir)


## True when the character's melee frames already draw the slash arc (the Squire's), so no slash effect is added on top.
func slash_in_frames() -> bool:
	return bool(_meta.get("slash_in_frames", false))


## True when this character's sheet has the animation (e.g. "run_se", "heavy").
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
		frames.add_frame("fx", load("res://assets/characters/%s/%s" % [_meta.get("effects_from", char_name), f]))
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


## A blow lands: the sprite flashes white for a few frames and the unit is knocked back a little along `dir` (world,
## horizontal: from the attacker toward this unit), then eased back to the centre of its tile. Only the sprite moves, so a walk or a slide in progress is not disturbed. A zero `dir`
## flashes only.
func hit_react(dir: Vector3) -> void:
	if not is_inside_tree():
		return
	dir.y = 0.0
	_flash_id += 1
	var id := _flash_id
	_show_flash(true)
	if dir.length() > 0.001:
		dir = dir.normalized()
		if _knock_tween:
			_knock_tween.kill()
		_knock_tween = create_tween()
		_knock_tween.tween_property(self, "_knock", dir * KNOCK_DISTANCE, KNOCK_OUT).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_knock_tween.tween_property(self, "_knock", Vector3.ZERO, KNOCK_BACK).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_knock_tween.tween_callback(func(): _knock = Vector3.ZERO)  # exactly on the tile again, whatever the easing left
	await get_tree().create_timer(FLASH_TIME).timeout
	if id == _flash_id:
		_show_flash(false)


## Swaps the sprite for its white silhouette (`on`) or back. Sprite3D modulate can only darken, so the white is a
## second sprite showing the current frame with every drawn pixel white.
func _show_flash(on: bool) -> void:
	if flash_sprite == null:
		flash_sprite = Sprite3D.new()
		flash_sprite.name = "Flash"
		flash_sprite.pixel_size = sprite.pixel_size
		flash_sprite.billboard = sprite.billboard
		flash_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		flash_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		flash_sprite.shaded = false
		flash_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flash_sprite)
	_flashing = on
	flash_sprite.visible = on
	sprite.visible = not on
	if on:
		_process(0.0)  # shows the silhouette at once, not a frame later


static func _white(tex: Texture2D) -> Texture2D:
	if not _white_cache.has(tex):
		var size := Vector2i(tex.get_size())  # the whole frame: an atlas frame's trimmed margin counts
		var drawn := tex.get_image()  # (an atlas frame gives only its region, without the margin)
		if drawn.is_compressed():
			drawn.decompress()
		drawn.convert(Image.FORMAT_RGBA8)
		var frame := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		frame.blit_rect(drawn, Rect2i(Vector2i.ZERO, drawn.get_size()), Vector2i((tex as AtlasTexture).margin.position) if tex is AtlasTexture else Vector2i.ZERO)
		var px := frame.get_data()  # every pixel white, keeping its own alpha, so the alpha cut hides what the sprite hides
		for i in range(0, px.size(), 4):
			px[i] = 255
			px[i + 1] = 255
			px[i + 2] = 255
		_white_cache[tex] = ImageTexture.create_from_image(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, px))
	return _white_cache[tex]


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
