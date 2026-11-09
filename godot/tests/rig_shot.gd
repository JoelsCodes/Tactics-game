extends Node
## Screenshot: the rigged Alaric (alaric_rig) next to the King and the Ashen Squire on the 3D board, four directions, idle poses on the
## top rows and the strike frame of the attack in the bottom row (needs a display and Vulkan).
## xvfb-run -a godot --path godot res://tests/rig_shot.tscn -- out=/tmp/r.png
func _ready() -> void:
	var out := "user://rig.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var map := Terrain.parse({"rows": ["g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0"]})
	var b := Board3D.new()
	add_child(b)
	b.setup(map, -50.0, 30.0, 0.0)
	var chars := ["king", "alaric_rig", "squire"]
	var dirs := [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]
	for i in chars.size():
		for d in 4:
			var u := b.add_unit(chars[i], d * 2, i * 2)
			u.face(dirs[d])
		var h := b.add_unit(chars[i], 8 if false else 0, i * 2 + 1)
		h.face(Vector2(1, 0))
		h.act("attack")
		h.sprite.frame = 2
		h.sprite.pause()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
