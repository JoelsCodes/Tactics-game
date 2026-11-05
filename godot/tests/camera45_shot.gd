extends Node
## Mock-up (not part of the game): the camera turned 45 degrees to the right (yaw -135) with four units standing on one board, each facing a
## different board direction, shown with a fixed board-direction -> sprite mapping. mapping=a|b (see the two tables in the session notes).
## xvfb-run -a godot --path godot res://tests/camera45_shot.tscn -- out=/tmp/c.png mapping=a map=demo_battlefield yaw=-135
func _ready() -> void:
	var args := {"out": "user://c45.png", "mapping": "a", "map": "demo_battlefield", "yaw": "-135", "ch": "king"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var d := Board3D.new()
	add_child(d)
	d.setup(Terrain.load_map("res://samples/%s.json" % args.map), -50.0, 28.0, float(args.yaw))
	await get_tree().process_frame
	var spots := [Vector2i(5, 5), Vector2i(8, 5), Vector2i(5, 8), Vector2i(8, 8)]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var names := ["+x", "-x", "+y", "-y"]
	for i in 4:
		var v := d.add_unit(args.ch, spots[i].x, spots[i].y)
		var sd := d.screen_dir(dirs[i], spots[i])  # where that board direction points on screen (a diagonal now)
		v.face(_sprite_dir(args.mapping, sd))
		var tag := Label3D.new()
		var pose: String = {"e": "right", "w": "left", "s": "front", "n": "back"}[SpriteAnimator.dir_of(_sprite_dir(args.mapping, sd))]
		tag.text = "board %s: %s pose" % [names[i], pose]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.pixel_size = 0.008
		tag.font_size = 40
		tag.outline_size = 14
		tag.position = d.top_point(spots[i].x, spots[i].y) + Vector3(0, 2.7, 0)
		d.add_child(tag)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()


## The sprite direction (as a screen vector the animator turns into e/s/w/n) for a board direction that points on the screen diagonal `sd`.
## Mapping a: lower-right -> right, lower-left -> down, upper-left -> left, upper-right -> up.
## Mapping b: lower-right -> down, lower-left -> left, upper-left -> up, upper-right -> right.
func _sprite_dir(mapping: String, sd: Vector2) -> Vector2:
	var right := sd.x > 0.0
	var down := sd.y > 0.0
	var e := Vector2(1, 0)
	var s := Vector2(0, 1)
	var w := Vector2(-1, 0)
	var n := Vector2(0, -1)
	if mapping == "a":
		if down:
			return e if right else s
		return n if right else w
	if down:
		return s if right else w
	return e if right else n
