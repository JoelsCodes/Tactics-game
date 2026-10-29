extends Node
## Headless checks for character animation (SpriteAnimator, UnitView3D) and the King's eight-direction
## sheet: godot --headless --path godot res://tests/anim_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	directions()
	king_sheet()
	await king_view()
	legacy_view()
	print("anim checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func directions() -> void:
	var want := {Vector2(0, 1): "s", Vector2(1, 1): "se", Vector2(1, 0): "e", Vector2(1, -1): "ne",
		Vector2(0, -1): "n", Vector2(-1, -1): "nw", Vector2(-1, 0): "w", Vector2(-1, 1): "sw"}
	for v in want:
		eq(SpriteAnimator.dir_of(v), want[v], "screen %s" % v)
	eq(SpriteAnimator.dir_of(Vector2(1, 0.3)), "e", "near-horizontal snaps to e")
	eq(SpriteAnimator.dir_of(Vector2(0.9, 0.7)), "se", "an isometric grid step reads as a diagonal")


func king_sheet() -> void:
	var m := Character.meta("king")
	ok(m.get("eight_dir", false), "the King's sheet is eight-direction")
	var frames: SpriteFrames = load("res://assets/characters/king.tres")
	for move in SpriteAnimator.MOVES:
		for d in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
			var n := "%s_%s" % [move, d]
			ok(frames.has_animation(n) and frames.get_frame_count(n) >= 3, "%s has frames" % n)
			ok(frames.get_animation_loop(n), "%s loops" % n)
	for a in ["attack", "heavy", "cast", "hit", "ko"]:
		ok(frames.has_animation(a) and not frames.get_animation_loop(a), "%s is a one-shot" % a)
	for a in ["attack", "heavy", "cast"]:
		var strike := int(m.anims[a].strike)
		ok(strike > 0 and strike < frames.get_frame_count(a), "%s strike frame %d inside the animation" % [a, strike])
	eq(frames.get_animation_speed("idle_s"), 4.0, "idle 4 fps")
	eq(frames.get_animation_speed("walk_se"), 8.0, "walk 8 fps")
	eq(frames.get_animation_speed("run_sw"), 12.0, "run 12 fps")
	eq(frames.get_animation_speed("dash_e"), 14.0, "dash 14 fps")
	eq(frames.get_animation_speed("attack"), 12.0, "melee 12 fps")
	eq(frames.get_animation_speed("heavy"), 10.0, "heavy 10 fps")
	eq(frames.get_animation_speed("cast"), 8.0, "cast 8 fps")
	eq(frames.get_animation_speed("hit"), 8.0, "hurt 8 fps")
	eq(frames.get_animation_speed("ko"), 6.0, "death 6 fps")
	var size: Vector2 = frames.get_frame_texture("idle_s", 0).get_size()
	var same := true
	for n in frames.get_animation_names():
		for i in frames.get_frame_count(n):
			same = same and frames.get_frame_texture(n, i).get_size() == size
	ok(same, "every frame is on the same canvas (one feet anchor: no jitter between animations)")
	for fx in ["slash", "eruption", "circle", "burst", "smoke"]:
		ok(m.effects.has(fx) and not m.effects[fx].frames.is_empty(), "effect %s" % fx)
	ok(UnitLook.portrait("king") != null, "portrait")


func king_view() -> void:
	var v := UnitView3D.new()
	add_child(v)
	v.setup("king")
	var s := v.sprite
	var want := {Vector2(0, 1): "s", Vector2(1, 1): "se", Vector2(1, 0): "e", Vector2(1, -1): "ne",
		Vector2(0, -1): "n", Vector2(-1, -1): "nw", Vector2(-1, 0): "w", Vector2(-1, 1): "sw"}
	v.play("walk")
	for d in want:
		v.face(d)
		eq(String(s.animation), "walk_" + want[d], "walking toward %s" % want[d])
		ok(not s.flip_h, "directional frames are never mirrored (%s)" % want[d])
	v.face(Vector2.ZERO)
	eq(String(s.animation), "walk_sw", "no direction keeps the last facing")
	v.play("idle")
	eq(String(s.animation), "idle_sw", "stopping keeps the facing")
	# no restart when asked again
	v.play("walk")
	s.frame = 3
	v.play("walk")
	eq(s.frame, 3, "asking for the playing animation does not restart it")
	# one-shots, strike frame, hurt interrupting
	var hits := []
	v.struck.connect(func(a): hits.append(a))
	v.face(Vector2(-1, 0.2))
	ok(v.act("attack"), "attack starts")
	eq(String(s.animation), "attack", "melee combo")
	ok(s.flip_h, "the attack (drawn facing right) is mirrored to face left")
	ok(not v.act("heavy"), "another action does not cut into a running one")
	s.frame = int(Character.meta("king").anims.attack.strike)
	eq(hits, ["attack"], "struck on the strike frame")
	s.frame = int(Character.meta("king").anims.attack.strike) + 1
	eq(hits.size(), 1, "struck only once")
	ok(v.act("hit"), "hurt interrupts")
	eq(String(s.animation), "hit", "hurt plays")
	s.animation_finished.emit()
	eq(String(s.animation), "walk_w", "after the hurt: back to the movement in the same direction")
	# death holds
	v.play("ko")
	eq(String(s.animation), "ko", "death plays")
	ok(not v.act("hit"), "nothing plays over a knocked-out unit")
	s.animation_finished.emit()
	eq(String(s.animation), "ko", "death holds its last frame")
	v.play("idle")
	eq(String(s.animation), "idle_w", "revived")
	ok(v.spawn_fx("eruption", Vector3.ZERO) != null, "effects play from the sheet")
	await get_tree().process_frame
	v.queue_free()


func legacy_view() -> void:
	var v := UnitView3D.new()
	add_child(v)
	v.setup("knight")
	v.play("walk")
	v.face(Vector2(-1, -1))
	eq(String(v.sprite.animation), "walk_b", "older sheets: back frames when facing up")
	v.face(Vector2(1, 1))
	eq(String(v.sprite.animation), "walk_f", "front frames when facing down")
	v.play("run")
	eq(String(v.sprite.animation), "walk_f", "no run in the sheet: walk")
	ok(v.act("heavy") and String(v.sprite.animation) == "attack", "no heavy in the sheet: the attack")
	v.queue_free()
