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
var _wading := false
var guard_icon: Sprite3D  ## a shield over the head while the unit guards (Defend)


func setup(ch: String, tint := Color(1, 1, 1, 0), size := Board3D.UNIT_SCALE) -> void:
	char_name = ch
	_meta = Character.meta(ch)
	sprite.name = "Sprite"
	sprite.sprite_frames = load("res://assets/characters/%s.tres" % ch)
	sprite.pixel_size = Character.SPRITE_SCALE * size * float(_meta.get("scale", 1.0)) / Board3D.PX_PER_UNIT
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # crisp pixels: no mipmaps, no blending
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset = Vector2(0, _meta.anchor[1] - _meta.size[1] / 2.0)  # feet on the origin
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
func fit(k: float) -> void:
	_stretch = k
	sprite.scale = Vector3(1, k, 1)
	_refresh()


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
		frames.add_frame("fx", load("res://assets/characters/%s/%s" % [char_name, f]))
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
	return (_meta.anchor[1] - 10.0) * sprite.pixel_size * _stretch


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
