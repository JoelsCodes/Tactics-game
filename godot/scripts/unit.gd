class_name UnitView
extends Node2D
## One unit on the battlefield: an AnimatedSprite2D playing the character's animations
## (idle, ready, walk, hit with front and back versions; attack, cast, victory, ko), a
## tint from Looks, a shadow, a team ring and an overhead HP bar with status pips.
##
## The sheets have a front and a back view. A unit facing down the screen uses the front
## frames, facing up uses the back frames, and the sprite is mirrored to face left or right.

const TEAMCOL := [Color(0.42, 0.72, 1.0), Color(1.0, 0.42, 0.36)]
const SPRITE_SCALE := .5

var bu: Dictionary
var look: Dictionary
var active := false
var base := "idle"  ## idle, ready, walk or victory
var action := ""  ## attack, cast or hit while one plays
var back := false
var face_right := false
var _meta: Dictionary
var _clock := 0.0
var _top := 60.0

@onready var body: Node2D = $Body
@onready var sprite: AnimatedSprite2D = $Body/Sprite
@onready var ring: Sprite2D = $Body/Ring
@onready var shadow: Sprite2D = $Body/Shadow
@onready var overhead: Node2D = $Body/Overhead


func setup(b: Dictionary) -> void:
	bu = b
	look = Looks.of(b)
	_meta = Looks.meta(look.char)
	sprite.sprite_frames = load("res://assets/characters/%s.tres" % look.char)
	sprite.offset = Vector2(0, _meta.size[1] / 2.0 - _meta.anchor[1])
	sprite.scale = Vector2.ONE * SPRITE_SCALE * look.scale
	sprite.material = sprite.material.duplicate()
	Looks.apply(sprite.material, look)
	ring.modulate = Color(TEAMCOL[bu.team], .9)
	var s: float = look.scale
	shadow.scale = Vector2(.0085 * _meta.size[0] * s, .0042 * _meta.size[0] * s)
	var idle: Image = sprite.sprite_frames.get_frame_texture("idle_f", 0).get_image()
	_top = (_meta.anchor[1] - idle.get_used_rect().position.y) * SPRITE_SCALE * s
	overhead.position.y = -_top - 12
	overhead.draw.connect(_draw_overhead)
	sprite.animation_finished.connect(_on_finished)
	sprite.play("idle_f")
	sprite.set_frame_and_progress(randi() % 4, randf())
	_refresh()


func _process(delta: float) -> void:
	_clock += delta
	if active:
		overhead.queue_redraw()


func _anim_name() -> String:
	if bu.ko:
		return "ko"
	var sfx := "_b" if back else "_f"
	if action != "":
		return action + sfx if action == "hit" else action
	return base if base == "victory" else base + sfx


func _refresh() -> void:
	var name := _anim_name()
	var native: String = _meta.anims[name].native
	sprite.flip_h = (native == "left") == face_right
	if sprite.animation != name:
		sprite.play(name)
	elif not sprite.is_playing() and not bu.ko:
		sprite.play(name)


func _on_finished() -> void:
	if action != "" and not bu.ko:
		action = ""
		z_index = 0
		_refresh()


## Base state: idle, ready, walk or victory. The active unit idles in its ready stance.
func play(p: String) -> void:
	base = "ready" if p == "idle" and active else p
	_refresh()


## A one-shot action: attack, cast or hit. Falls back to the base state when it ends.
func act(p: String) -> void:
	if bu.ko:
		return
	action = p
	z_index = 5  # wide effects draw over the tiles in front
	sprite.stop()
	sprite.play(_anim_name())
	var native: String = _meta.anims[_anim_name()].native
	sprite.flip_h = (native == "left") == face_right


func is_acting() -> bool:
	return action != ""


func set_active(on: bool) -> void:
	active = on
	ring.modulate = Color(1, .86, .4, 1) if on else Color(TEAMCOL[bu.team], .9)
	if base in ["idle", "ready"]:
		base = "ready" if on else "idle"
	_refresh()
	overhead.queue_redraw()


## Sets which way the unit looks on screen (see BattleWorld.screen_dir).
func face(screen_dir: Vector2) -> void:
	var b := screen_dir.y < 0
	var r := screen_dir.x > 0
	if b != back or r != face_right:
		back = b
		face_right = r
		if not bu.ko:
			_refresh()


func set_height(vh: float, hop: float, hs: float) -> void:
	body.position.y = -vh * hs - hop


## Hides the feet below the waterline when standing in water.
func set_wading(on: bool) -> void:
	var cut := 2.0
	if on and not bu.ko:
		cut = (_meta.anchor[1] - 10.0 / (SPRITE_SCALE * look.scale) * SPRITE_SCALE) / _meta.size[1]
	(sprite.material as ShaderMaterial).set_shader_parameter("cut", cut)
	sprite.position.y = 4.0 if on else 0.0
	shadow.visible = not on


func flash(col := Color.WHITE) -> void:
	var m: ShaderMaterial = sprite.material
	var tw := create_tween()
	tw.tween_method(func(a): m.set_shader_parameter("flash_color", Color(col, a)), .85, 0.0, .28)
	var shake := create_tween()
	for i in 4:
		shake.tween_property(sprite, "position:x", (3.0 if i % 2 == 0 else -3.0) * (1 - i * .2), .04)
	shake.tween_property(sprite, "position:x", 0.0, .04)


func set_ko(on: bool) -> void:
	var m: ShaderMaterial = sprite.material
	if on:
		action = ""
		z_index = 0
		sprite.play("ko")
		var tw := create_tween().set_parallel()
		tw.tween_method(func(g): m.set_shader_parameter("gray", g), 0.0, .4, .5)
		ring.visible = false
	else:
		m.set_shader_parameter("gray", 0.0)
		ring.visible = true
		_refresh()
		sprite.play(_anim_name())
	overhead.queue_redraw()


func refresh() -> void:
	overhead.queue_redraw()


func _draw_overhead() -> void:
	if bu.ko:
		return
	var w := 26.0
	var pct: float = clampf(float(bu.hp) / bu.s.mhp, 0, 1)
	overhead.draw_rect(Rect2(-w / 2 - 1, -1, w + 2, 6), Color(0.05, 0.06, 0.1, .85))
	var col := Color("#5fd36a") if pct > .5 else Color("#e8c050") if pct > .25 else Color("#e8574a")
	overhead.draw_rect(Rect2(-w / 2, 0, w * pct, 4), col)
	overhead.draw_rect(Rect2(-w / 2, 0, w * pct, 1), Color(1, 1, 1, .35))
	var i := 0
	for k in bu.st:
		overhead.draw_circle(Vector2(-w / 2 + 3 + i * 6, -5), 2.4, Color(Data.STATUS[k].col))
		i += 1
		if i >= 5:
			break
	if bu.cards:
		overhead.draw_rect(Rect2(w / 2 + 3, -3, 5, 7), Color("#f0d040"))
	if active:
		var y := -14 + sin(_clock * 6) * 2.5
		overhead.draw_colored_polygon(PackedVector2Array([Vector2(-6, y - 7), Vector2(6, y - 7), Vector2(0, y)]), Color("#ffd36a"))
		overhead.draw_polyline(PackedVector2Array([Vector2(-6, y - 7), Vector2(6, y - 7), Vector2(0, y), Vector2(-6, y - 7)]), Color(0.3, 0.2, 0.05), 1)
