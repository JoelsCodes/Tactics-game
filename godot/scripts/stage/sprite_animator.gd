class_name SpriteAnimator
extends RefCounted
## The animation state machine for one character sprite (AnimatedSprite2D or AnimatedSprite3D), driven
## by the character's entry in assets/characters/meta.json. Reusable for every character:
##
##   eight-direction sheets (meta.eight_dir): movement animations exist per screen direction
##     (`walk_s`, `walk_se`, ... `walk_sw`: s = straight down the screen, clockwise); the facing picks the
##     one whose direction is nearest (never a rotated or mirrored sprite). Actions (attack, heavy, cast,
##     hit, ko) are drawn facing one way (`native`) and are mirrored to face the other.
##   front/back sheets (the older characters): `<anim>_f` / `<anim>_b` by whether the unit faces up the
##     screen, mirrored left/right by `native`.
##
## States:
##   MOVE    idle / walk / run / dash, looping in the current direction. Asking for the animation that
##           is already playing changes nothing (no restart every frame).
##   ACTION  a one-shot (attack, heavy, cast, hit). `struck` fires on the animation's strike frame
##           (meta `strike`, the visible impact) so damage can be shown in sync; `finished` at the end,
##           then the unit goes back to its movement animation. Hurt interrupts any action; another
##           action does not interrupt a running one.
##   POSE    victory, looping.
##   DEAD    ko plays once and holds its last frame; nothing else plays until revive().
## Playback runs on the sprite's own clock (animation fps x delta), independent of the frame rate.

signal struck(action: String)
signal finished(action: String)

enum State { MOVE, ACTION, POSE, DEAD }

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]  ## by screen angle, 0 = right, clockwise
const MOVES := ["idle", "walk", "run", "dash"]

var sprite: Node  ## AnimatedSprite2D or AnimatedSprite3D
var meta: Dictionary
var state := State.MOVE
var move := "idle"  ## the movement animation to return to
var action := ""  ## the action playing (ACTION state)
var dir := "s"  ## eight-way screen direction
var back := false  ## facing up the screen (front/back sheets)
var face_right := false
var _struck_sent := false


func _init(s: Node, character_meta: Dictionary) -> void:
	sprite = s
	meta = character_meta
	sprite.animation_finished.connect(_on_finished)
	sprite.frame_changed.connect(_on_frame)


func eight_dir() -> bool:
	return bool(meta.get("eight_dir", false))


func has_anim(n: String) -> bool:
	return meta.anims.has(n)


## The eight-way direction of a screen vector (x right, y down).
static func dir_of(v: Vector2) -> String:
	var a := fposmod(rad_to_deg(v.angle()) + 22.5, 360.0)
	return DIRS[int(a / 45.0) % 8]


## Sets the facing from a screen direction (y < 0 = away from the viewer, x > 0 = to the right).
func face(screen_dir: Vector2) -> void:
	if screen_dir.length_squared() < 1e-6:
		return  # no direction: keep the last facing
	dir = dir_of(screen_dir)
	back = screen_dir.y < 0
	if absf(screen_dir.x) > 1e-3:
		face_right = screen_dir.x > 0
	_apply()


## Movement: idle, walk, run or dash. Ignored while an action plays (it resumes this afterwards) and
## while dead.
func set_move(m: String) -> void:
	move = m
	if state == State.MOVE or state == State.POSE:
		state = State.MOVE
		_apply()


## A one-shot action. Returns false when it cannot play now (dead, or busy with another action).
func play_action(a: String) -> bool:
	if state == State.DEAD:
		return false
	if state == State.ACTION and a != "hit":
		return false
	state = State.ACTION
	action = a
	_struck_sent = false
	_apply(true)
	return true


func die() -> void:
	state = State.DEAD
	action = "ko"
	_apply(true)


func revive() -> void:
	state = State.MOVE
	_apply(true)


func pose(a := "victory") -> void:
	if state == State.DEAD:
		return
	state = State.POSE
	action = a
	_apply()


## The animation name and mirroring for the current state and facing.
func resolve() -> Array:
	var base := move
	match state:
		State.ACTION, State.DEAD, State.POSE:
			base = action
	if state == State.ACTION and not has_anim(base) and not has_anim(base + "_f"):
		base = "attack" if base == "heavy" else base  # older sheets have no heavy attack
	if eight_dir() and has_anim("%s_%s" % [base, dir]):
		return ["%s_%s" % [base, dir], false]
	if not eight_dir() and base in ["run", "dash"]:
		base = "walk"
	var n := base
	if eight_dir() and has_anim(base):
		pass  # its own action name (the _f / _b names are only aliases for older code)
	elif has_anim(base + ("_b" if back else "_f")):
		n = base + ("_b" if back else "_f")
	elif not has_anim(base):
		n = "idle_f" if has_anim("idle_f") else meta.anims.keys()[0]
	var native: String = meta.anims[n].get("native", "left")
	var flip := false
	if native == "left":
		flip = face_right
	elif native == "right":
		flip = not face_right
	return [n, flip]


func current() -> String:
	return String(sprite.animation)


func _apply(restart := false) -> void:
	var r := resolve()
	sprite.flip_h = r[1]
	if restart or sprite.animation != r[0] or not sprite.is_playing():
		sprite.play(r[0])
		if restart:
			sprite.set_frame_and_progress(0, 0.0)


func _on_frame() -> void:
	if state != State.ACTION or _struck_sent:
		return
	var strike := int(meta.anims.get(current(), {}).get("strike", -1))
	if strike >= 0 and sprite.frame >= strike:
		_struck_sent = true
		struck.emit(action)


func _on_finished() -> void:
	if state != State.ACTION:
		return  # ko holds its last frame; loops never finish
	var a := action
	if not _struck_sent:
		_struck_sent = true
		struck.emit(a)  # no strike frame given: the end of the animation is the impact
	state = State.MOVE
	action = ""
	_apply(true)
	finished.emit(a)
