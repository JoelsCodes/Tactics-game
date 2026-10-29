extends Node
## Screenshot: the King on the 3D board walking in all eight screen directions (top two rows, labeled),
## and his actions on their strike frames (bottom row): needs a display and Vulkan.
## xvfb-run -a godot --path godot res://tests/king_shot.tscn -- out=/tmp/k.png [anim=walk|run|idle|dash]
func _ready() -> void:
	var args := {"out": "user://king.png", "anim": "walk"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var map := Terrain.parse({"rows": ["g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0"], "haze": "light"})
	var b := Board3D.new()
	add_child(b)
	b.setup(map, -50.0, 30.0, 45.0)
	var view := Vector2(1920, 1080)
	var dirs := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
	var vecs := {"s": Vector2(0, 1), "se": Vector2(1, 1), "e": Vector2(1, 0), "ne": Vector2(1, -1), "n": Vector2(0, -1), "nw": Vector2(-1, -1), "w": Vector2(-1, 0), "sw": Vector2(-1, 1)}
	var cells := [Vector2i(0, 4), Vector2i(1, 3), Vector2i(2, 2), Vector2i(3, 1), Vector2i(4, 0), Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 2)]
	var labels := CanvasLayer.new()
	add_child(labels)
	await get_tree().process_frame
	for i in 8:
		var u := b.add_unit("king", cells[i].x + 1, cells[i].y, true, args.anim)
		u.face(vecs[dirs[i]])
		u.play(args.anim)
		_label(labels, b, u, dirs[i])
	var acts := ["attack", "heavy", "cast", "hit", "ko"]
	var cells2 := [Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4)]
	for i in acts.size():
		var u := b.add_unit("king", cells2[i].x, cells2[i].y)
		u.face(Vector2(1, 0.3))
		if acts[i] == "ko":
			u.play("ko")
		else:
			u.act(acts[i])
		var st := int(Character.meta("king").anims[acts[i]].get("strike", 1))
		u.sprite.frame = maxi(st, 1) if acts[i] != "ko" else 3
		u.sprite.pause()
		_label(labels, b, u, acts[i])
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.out)
	get_tree().quit()


func _label(layer: CanvasLayer, b: Board3D, u: UnitView3D, text: String) -> void:
	await get_tree().process_frame
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = b.cam.unproject_position(u.global_position) + Vector2(-20, 8)
	layer.add_child(l)
