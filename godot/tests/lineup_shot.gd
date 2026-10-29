extends Node
## Screenshot: every full-sheet character on the 3D board, top row walking toward the viewer, bottom
## row on its heavy attack's impact frame (needs a display and Vulkan).
## xvfb-run -a godot --path godot res://tests/lineup_shot.tscn -- out=/tmp/l.png
func _ready() -> void:
	var out := "user://lineup.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var map := Terrain.parse({"rows": ["g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0"]})
	var b := Board3D.new()
	add_child(b)
	b.setup(map, -50.0, 30.0, 0.0)
	var chars := ["king", "vesper", "mira", "squire", "choir", "wraith"]
	for i in chars.size():
		var u := b.add_unit(chars[i], i, 1)
		u.face(Vector2(0, 1))
		u.play("walk")
		var h := b.add_unit(chars[i], i, 3)
		h.face(Vector2(1, 0.2))
		h.act("heavy")
		h.sprite.frame = maxi(int(Character.meta(chars[i]).anims.heavy.get("strike", 2)), 1)
		h.sprite.pause()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
