class_name UnitView
extends Node2D
## One unit on the battlefield: an AnimatedSprite2D with the character's poses
## (idle, ready, attack, cast, victory), a palette from Looks, a shadow, a team ring
## and an overhead HP bar with status pips. The battle world moves it around.

const TEAMCOL := [Color(0.42, 0.72, 1.0), Color(1.0, 0.42, 0.36)]

var bu: Dictionary
var look: Dictionary
var active := false
var pose := "idle"
var _meta: Dictionary
var _clock := 0.0
var _pose_tween: Tween

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
	sprite.scale = Vector2(.5, .5) * look.scale
	sprite.material = sprite.material.duplicate()
	Looks.apply(sprite.material, look)
	ring.modulate = Color(TEAMCOL[bu.team], .9)
	overhead.position.y = -74 * look.scale
	overhead.draw.connect(_draw_overhead)
	sprite.play("idle")
	sprite.set_frame_and_progress(randi() % 2, randf())


func _process(delta: float) -> void:
	_clock += delta
	if active:
		overhead.queue_redraw()


## Poses: idle, ready, attack, cast, victory. The active unit idles in its ready stance.
func play(p: String) -> void:
	pose = p
	if bu.ko:
		return
	var anim := "ready" if p == "idle" and active else p
	if sprite.animation != anim:
		sprite.play(anim)


## Strike or cast pose for a moment, then back to idle.
func act_pose(p: String, hold := .55) -> void:
	play(p)
	z_index = 5  # wide effects draw over the tiles in front
	if _pose_tween:
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_interval(hold)
	_pose_tween.tween_callback(func():
		z_index = 0
		if pose == p:
			play("idle"))


func set_active(on: bool) -> void:
	active = on
	ring.modulate = Color(1, .86, .4, 1) if on else Color(TEAMCOL[bu.team], .9)
	play(pose if pose != "ready" else "idle")
	overhead.queue_redraw()


## Mirrors the sprite when facing screen-left.
func face(screen_dir: Vector2) -> void:
	sprite.flip_h = screen_dir.x < 0


func set_height(vh: float, hop: float, hs: float) -> void:
	body.position.y = -vh * hs - hop


## Hides the feet below the waterline when standing in water.
func set_wading(on: bool) -> void:
	var cut := 2.0
	if on and not bu.ko:
		cut = (_meta.anchor[1] - 10.0 / look.scale) / _meta.size[1]
	(sprite.material as ShaderMaterial).set_shader_parameter("cut", cut)
	sprite.position.y = 4.0 if on else 0.0
	shadow.visible = not on


func flash(col := Color.WHITE) -> void:
	var m: ShaderMaterial = sprite.material
	var tw := create_tween()
	tw.tween_method(func(a): m.set_shader_parameter("flash_color", Color(col, a)), .9, 0.0, .3)
	var shake := create_tween()
	for i in 4:
		shake.tween_property(sprite, "position:x", (3.0 if i % 2 == 0 else -3.0) * (1 - i * .2), .04)
	shake.tween_property(sprite, "position:x", 0.0, .04)


func set_ko(on: bool) -> void:
	var m: ShaderMaterial = sprite.material
	if on:
		sprite.play("idle")
		sprite.pause()
		var tw := create_tween().set_parallel()
		tw.tween_property(sprite, "rotation", -PI / 2 if not sprite.flip_h else PI / 2, .35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(sprite, "position:y", -8.0, .35)
		tw.tween_method(func(g): m.set_shader_parameter("gray", g), 0.0, .85, .5)
		tw.tween_property(sprite, "modulate:a", .75, .5)
		ring.visible = false
	else:
		sprite.rotation = 0
		sprite.position.y = 0
		sprite.modulate.a = 1
		m.set_shader_parameter("gray", 0.0)
		ring.visible = true
		sprite.play("idle")
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
