class_name UnitView3D
extends Node3D
## One character standing on the 3D board: an upright `AnimatedSprite3D` billboard (turns only around
## Y to face the camera, nearest filtering) playing the sheet's animations, with an invisible capsule
## that casts its shadow (a flat billboard only casts a hairline). The node's origin is the feet.
##
## Same animation rules as the 2D `Character`: a character facing down the screen uses the front (`_f`)
## frames, facing up the back (`_b`) frames, and the sprite is mirrored to face left or right using each
## animation's `native` direction. Tints (vessels, enemies), the KO gray and wading are done with
## `modulate` and the sprite's height, since a sprite's own shader is not available on Sprite3D.

const BODY_HEIGHT := 1.25
const WADE_DEPTH := 0.22  ## how far the feet sink into shallow water (units)

var char_name := ""
var anim := "idle"  ## idle, ready, walk, hit, attack, cast, victory or ko
var back := false
var face_right := false
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
	sprite.pixel_size = Character.SPRITE_SCALE * size / Board3D.PX_PER_UNIT
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
	sprite.animation_finished.connect(_on_finished)
	play("idle")
	sprite.set_frame_and_progress(randi() % 4, randf())


## Undo the camera's foreshortening: the sprite is stretched by `k` = 1 / cos(pitch) on Y, so on screen
## it has its drawn proportions while it stays vertical. The shadow body keeps its real height.
func fit(k: float) -> void:
	_stretch = k
	sprite.scale = Vector3(1, k, 1)
	_refresh()


func _anim_name() -> String:
	if anim in ["attack", "cast", "victory", "ko"]:
		return anim
	return anim + ("_b" if back else "_f")


## Plays a one-shot animation (attack, cast, hit), then returns to idle.
func act(a: String) -> void:
	play(a)
	sprite.set_frame_and_progress(0, 0.0)


func _on_finished() -> void:
	if anim in ["attack", "cast", "hit"]:
		play("idle")


func play(a: String) -> void:
	anim = a
	var n := _anim_name()
	var native: String = _meta.anims[n].native
	sprite.flip_h = (native == "left") == face_right
	if sprite.animation != n or not sprite.is_playing():
		sprite.play(n)


## Sets which way the character looks on screen: y < 0 shows its back, x > 0 faces right.
func face(screen_dir: Vector2) -> void:
	back = screen_dir.y < 0
	face_right = screen_dir.x > 0
	play(anim)


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
