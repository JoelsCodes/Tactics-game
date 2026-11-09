extends Node
## Screenshot: characters side by side on the 3D board, one row each, the four directions standing and (in a bottom row) the blow frame of
## the attack. CHARS=king,alaric_v2 picks them (default: king, alaric_v2, squire). Needs a display and Vulkan.
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
	var chars: Array = OS.get_environment("CHARS").split(",") if OS.get_environment("CHARS") != "" else ["king", "alaric_v2", "squire"]
	var dirs := [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]
	for i in chars.size():
		for d in 4:
			var u := b.add_unit(chars[i], i * 2, d)
			u.face(dirs[d])
			u.play("walk")
		for d in 4:
			var h := b.add_unit(chars[i], i * 2 + 1, d)
			h.face(dirs[d])
			h.act("attack")
			h.sprite.frame = clampi(int(Character.meta(chars[i]).anims["attack_s"].get("strike", 2)), 0, h.sprite.sprite_frames.get_frame_count(h.sprite.animation) - 1)
			h.sprite.pause()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
