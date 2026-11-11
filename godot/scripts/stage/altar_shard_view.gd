class_name AltarShardView
extends Node3D
## The picture of a summoning stone (an Altar Shard) on its tile: an AnimatedSprite3D over four sprite sheets (assets/sprites/altar_shard/, cut by
## tools/art/altar_shard.py: eight frames of 290 x 570 each, the stone's base on the same pixel in every frame).
##
##   idle      loops while the stone lies there (6 fps)
##   activate  once, when a summon is COMMITTED (never for a hover, a selection or a cancelled preview): the crystal charges (16 fps)
##   summon    once, right after: the burst; `burst` is emitted on its strongest frame, which is when the vessel appears (16 fps)
##   depleted  once, under a fade-out: the stone's power is spent (10 fps), then `finished`
##
## This only shows things. The summon itself (DeploymentManager.summon_vessel) has already happened when `begin_summon` is called; the stone's rule
## object (RelicProp) is gone by then. A skip, a failure or a scene change never loses a summon: `skip` jumps to the end at once (emitting `burst`
## first, so a vessel waiting for it appears), and a stone that cannot play its frames (missing sheet) ends the sequence the same way.
## Battle speed (Engine.time_scale) scales the animation like everything else.

signal burst  ## the strongest frame of the summon: the vessel materialises now (emitted exactly once per sequence)
signal finished  ## the sequence is over (or skipped): the owner can free the node

enum State { IDLE, ACTIVATING, SUMMONING, DEPLETED, GONE }

const DIR := "res://assets/sprites/altar_shard/"
const FRAME_SIZE := Vector2i(290, 570)
const FRAME_COUNT := 8
const BASE_ROW := 540  ## the row of a frame where the stone's foot is: it stands on the tile's centre
const STONE_HEIGHT_PX := 375.0  ## the stone's solid height in the art (foot to the top of its arch, glow not counted)
const FIGURE_HEIGHT := 1.87  ## world units: as tall as a character (Alaric's figure_height, a tile is 1.0), so the stone is drawn at that height (owner, Nov 2026: "the same size as a character")
const BURST_FRAME := 4  ## the summon frame with the strongest light
const FADE := 0.6  ## seconds the spent stone takes to fade away after the burst (the vessel stands where it was)
## animation -> [frames per second, loops]
const ANIMS := {"idle": [6.0, true], "activate": [16.0, false], "summon": [16.0, false], "depleted": [10.0, false]}

static var _frames: SpriteFrames
static var use_mipmaps := true  ## off only in tests/shard_sizes_shot (the before-and-after comparison)

var sprite: AnimatedSprite3D
var light: OmniLight3D  ## optional: the soft light that goes with the stone; it flares at the burst and goes out with the fade
var stretch := 1.0  ## Board3D.unit_stretch(): upright sprites are stretched by 1 / cos(pitch) on Y, as the characters are, so the stone keeps its drawn proportions
var tint := Color.WHITE  ## the stone's colour (the prize stone is gold); set before it enters the tree
var state := State.IDLE
var _burst_sent := false
var _light_energy := 0.0


## The shared SpriteFrames (built once from the four sheets); null when a sheet is missing.
static func frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for name in ANIMS:
		var tex := _with_mipmaps(load(DIR + "altar_shard_%s.png" % name) as Texture2D)
		if tex == null or tex.get_size() != Vector2(FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y):
			push_warning("AltarShardView: the %s sheet is missing or the wrong size" % name)
			return null
		sf.add_animation(name)
		sf.set_animation_speed(name, ANIMS[name][0])
		sf.set_animation_loop(name, ANIMS[name][1])
		for i in FRAME_COUNT:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
			sf.add_frame(name, at)
	_frames = sf
	return sf


## The sheet with a full mipmap chain, made here rather than in the import settings (those are not kept in git): the art is drawn at a fraction of its size
## that changes with the window and the camera, and a plain linear sample of a 570 px frame shown 70 px tall shimmers; a mip level near the shown size does not.
static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	if tex == null or not use_mipmaps:
		return tex
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.fix_alpha_edges()  # transparent pixels take their neighbours' colour, so the soft edges do not darken as they shrink
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _ready() -> void:
	var sf := frames()
	sprite = AnimatedSprite3D.new()
	if sf != null:
		sprite.sprite_frames = sf
	sprite.pixel_size = FIGURE_HEIGHT / (STONE_HEIGHT_PX * stretch)  # (FIGURE_HEIGHT is on screen, after the stretch)
	sprite.scale = Vector3(1, stretch, 1)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC  # drawn much smaller than its 570 px frames, at a size that changes with the window: mip levels (_with_mipmaps) keep it clean at any size
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.shaded = false
	sprite.modulate = tint
	sprite.centered = true
	sprite.offset = Vector2(0, BASE_ROW - FRAME_SIZE.y / 2.0)  # the foot of the stone is the node's origin
	sprite.position.y = 0.03
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	add_child(sprite)
	if sf != null:
		sprite.play("idle")
		sprite.set_frame_and_progress(randi() % FRAME_COUNT, randf())  # neighbouring stones do not pulse in step


## True while a summon sequence is playing.
func is_busy() -> bool:
	return state == State.ACTIVATING or state == State.SUMMONING or state == State.DEPLETED


## Starts the activate -> summon -> depleted sequence. Only an idle stone starts it, once: a second call (rapid input) does nothing and returns false.
func begin_summon() -> bool:
	if state != State.IDLE:
		return false
	if sprite == null or sprite.sprite_frames == null:
		state = State.SUMMONING
		_emit_burst()
		_finish()
		return true
	state = State.ACTIVATING
	sprite.play("activate")
	return true


## Ends the sequence now: the vessel that waits for the burst appears, the stone goes.
func skip() -> void:
	if state == State.GONE or state == State.IDLE:
		return
	_emit_burst()
	_finish()


func _on_animation_finished() -> void:
	match state:
		State.ACTIVATING:
			state = State.SUMMONING
			sprite.play("summon")
		State.SUMMONING:
			state = State.DEPLETED
			sprite.play("depleted")
		State.DEPLETED:
			_finish()


func _on_frame_changed() -> void:
	if state == State.SUMMONING and sprite.frame >= BURST_FRAME:
		_emit_burst()


func _emit_burst() -> void:
	if _burst_sent:
		return
	_burst_sent = true
	burst.emit()
	if light != null and is_inside_tree():
		_light_energy = light.light_energy
		var tw := create_tween()
		tw.tween_property(light, "light_energy", _light_energy * 2.2, 0.08)
		tw.tween_property(light, "light_energy", 0.0, FADE)
	if sprite != null and is_inside_tree():
		var fade := create_tween()
		fade.tween_property(sprite, "modulate:a", 0.0, FADE).set_delay(0.12)


func _finish() -> void:
	if state == State.GONE:
		return
	state = State.GONE
	if sprite != null:
		sprite.stop()
		sprite.modulate.a = 0.0
	finished.emit()
