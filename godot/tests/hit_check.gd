extends Node
## Headless: a hit turns the unit white for a few frames, knocks the sprite back a little and eases it to the centre
## of its tile again; the unit's own position is never touched.
## godot --headless --path godot res://tests/hit_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	var v := UnitView3D.new()
	root.add_child(v)
	v.setup("squire")
	v.position = Vector3(3.5, 0.4, 4.5)
	var home := v.position
	var normal := v.sprite.modulate
	await get_tree().process_frame

	v.hit_react(Vector3(-1, 0.5, 0))  # the blow goes toward -x; a vertical part is ignored
	ok(v.flash_sprite.visible and not v.sprite.visible and v.flash_sprite.texture != null, "the white silhouette stands in for the sprite at once")
	var img := v.flash_sprite.texture.get_image()
	var drawn := 0
	var not_white := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				drawn += 1
				if c.r < 0.999 or c.g < 0.999 or c.b < 0.999:
					not_white += 1
	ok(drawn > 100 and not_white == 0, "every drawn pixel of it is white (%d drawn, %d not)" % [drawn, not_white])
	var frame_tex := v.sprite.sprite_frames.get_frame_texture(v.sprite.animation, v.sprite.frame)
	ok(v.flash_sprite.texture.get_size() == frame_tex.get_size(), "it is the whole frame's size, so it lines up (%s, the frame is %s)" % [v.flash_sprite.texture.get_size(), frame_tex.get_size()])
	ok(v.flash_sprite.scale == v.sprite.scale and v.flash_sprite.offset == v.sprite.offset and v.flash_sprite.pixel_size == v.sprite.pixel_size, "and it is placed exactly over the sprite")
	# frame by frame for half a second: how far the sprite is pushed back, and that the shadow body goes with it
	var peak := 0.0
	var same := true
	var steady := true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 500:
		await get_tree().process_frame
		peak = minf(peak, v.sprite.position.x)
		same = same and v.body.position.x == v.sprite.position.x
		steady = steady and v.position == home and absf(v.sprite.position.y) < 0.001 and is_zero_approx(v.sprite.position.z)
	ok(peak < -0.05 and peak >= -0.17, "knocked back along the blow, only a little (%s)" % peak)
	ok(same, "the shadow body is knocked with it")
	ok(steady, "the unit's own position is untouched, and the sprite only moves along the blow")
	ok(v.sprite.visible and not v.flash_sprite.visible and v.sprite.modulate.is_equal_approx(normal), "back to its own colours after a few frames")
	ok(is_zero_approx(v.sprite.position.x) and is_zero_approx(v.body.position.x), "eased back to the centre of its tile (%s)" % v.sprite.position)

	# a hit while grayed keeps the gray after the flash; a second hit restarts the flash
	v.set_gray(0.45)
	var gray := v.sprite.modulate
	v.hit_react(Vector3.ZERO)
	ok(v.flash_sprite.visible, "a hit without a direction only flashes")
	v.hit_react(Vector3(1, 0, 0))
	await get_tree().create_timer(0.12).timeout
	ok(v.sprite.visible and v.sprite.modulate.is_equal_approx(gray), "the gray is back after the flash (%s)" % v.sprite.modulate)

	# hits that overlap, from different sides, still end exactly on the tile
	v.hit_react(Vector3(1, 0, 0))
	await get_tree().create_timer(0.05).timeout
	v.hit_react(Vector3(0, 0, -1))
	await get_tree().create_timer(0.05).timeout
	v.hit_react(Vector3(-1, 0, 1))
	await get_tree().create_timer(0.8).timeout
	ok(v.sprite.position == Vector3.ZERO and v.body.position.x == 0.0 and v.body.position.z == 0.0 and v.position == home, "after overlapping hits it is exactly on its tile again (%s)" % v.sprite.position)

	print("hit checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails > 0 else 0)
