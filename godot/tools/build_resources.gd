extends SceneTree
## Generates the editor resources from the built art:
##   assets/characters/<name>.tres   SpriteFrames (idle, ready, walk, hit, attack, cast, victory, ko)
## Run after tools/art/build_art.py and an import:
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/build_resources.gd


func _init() -> void:
	build_frames()
	quit()


func build_frames() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/meta.json"))
	for ch in meta:
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		var anims: Dictionary = meta[ch].anims
		for a in anims:
			var def: Dictionary = anims[a]
			sf.add_animation(a)
			sf.set_animation_speed(a, float(def.fps))
			sf.set_animation_loop(a, bool(def.loop))
			for f in def.frames:
				sf.add_frame(a, load("res://assets/characters/%s/%s" % [ch, f]))
		var err := ResourceSaver.save(sf, "res://assets/characters/%s.tres" % ch)
		print("frames ", ch, " ", error_string(err))
