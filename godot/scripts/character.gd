class_name Character
extends Node2D
## One character sprite standing on the terrain: an AnimatedSprite2D playing the sheet's animations
## (idle, ready, walk, hit with front and back versions; attack, cast, victory, ko), a soft shadow and
## the unit shader (tint, hue shift, hit flash, KO gray, waterline). Kept from the first build: this is
## how the sprite sheets are placed. See README "Characters".
##
## Every character is cut onto one shared canvas with the feet at `meta.anchor`, so animations swap
## without jumping. A character facing down the screen uses the front (`_f`) frames, facing up uses the
## back (`_b`) frames, and the sprite is mirrored to face left or right using each animation's `native`.

const SPRITE_SCALE := .5  ## sheets are cut at BODY_H 136 px and drawn at half size

var char_name := ""
var anim := "idle"  ## idle, ready, walk, hit, attack, cast, victory or ko
var back := false
var face_right := false
var _meta: Dictionary

var shadow := Sprite2D.new()
var sprite := AnimatedSprite2D.new()

static var _all_meta := {}


static func meta(ch: String) -> Dictionary:
	if _all_meta.is_empty():
		_all_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	return _all_meta[ch]


static func names() -> Array:
	meta("hero")
	return _all_meta.keys()


func setup(ch: String, tint := Color(1, 1, 1, 0), hue := 0.0) -> void:
	char_name = ch
	_meta = meta(ch)
	shadow.texture = load("res://assets/fx/shadow.png")
	shadow.modulate = Color(1, 1, 1, .85)
	shadow.scale = Vector2(.0085 * _meta.size[0], .0042 * _meta.size[0])
	add_child(shadow)
	sprite.sprite_frames = load("res://assets/characters/%s.tres" % ch)
	sprite.offset = Vector2(0, _meta.size[1] / 2.0 - _meta.anchor[1])  # feet on the node's origin
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/unit.gdshader")
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("hue_shift", hue)
	sprite.material = m
	add_child(sprite)
	play("idle")
	sprite.set_frame_and_progress(randi() % 4, randf())


func _anim_name() -> String:
	if anim in ["attack", "cast", "victory", "ko"]:
		return anim
	return anim + ("_b" if back else "_f")


func play(a: String) -> void:
	anim = a
	var name := _anim_name()
	var native: String = _meta.anims[name].native
	sprite.flip_h = (native == "left") == face_right
	if sprite.animation != name or not sprite.is_playing():
		sprite.play(name)


## Sets which way the character looks on screen: y < 0 shows its back, x > 0 faces right.
func face(screen_dir: Vector2) -> void:
	back = screen_dir.y < 0
	face_right = screen_dir.x > 0
	play(anim)


## Hides the feet below the waterline when standing in water.
func set_wading(on: bool) -> void:
	var cut := 2.0
	if on:
		cut = (_meta.anchor[1] - 10.0) / _meta.size[1]
	(sprite.material as ShaderMaterial).set_shader_parameter("cut", cut)
	sprite.position.y = 4.0 if on else 0.0
	shadow.visible = not on
