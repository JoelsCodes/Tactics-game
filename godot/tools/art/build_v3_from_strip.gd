extends SceneTree
## Builds the prototype character sheet `alaric_v3` from a one-row 8-direction idle strip (eight 512x512 cells, figure 4x its final size, feet on row 447):
##   godot --headless --path godot --script res://tools/art/build_v3_from_strip.gd -- <path to strip.png>
## Writes assets/characters/alaric_v3/animations/idle/idle_<dir>_0.png (128x128, nearest 4x downscale, feet anchor (64, 112)), a SpriteFrames
## (assets/characters/alaric_v3.tres) with every animation of alaric_v2 showing the idle frame of its direction (a stand-in until walk/attack
## sheets exist), and the "alaric_v3" entry in meta.json. alaric_v2 is never changed. The strip's cell order is the game's: s sw w nw n ne e se.
const DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
const ROOT := "res://assets/characters/"


func _init() -> void:
	var strip := Image.load_from_file(OS.get_cmdline_user_args()[0])
	strip.convert(Image.FORMAT_RGBA8)
	var dir_out := ProjectSettings.globalize_path(ROOT + "alaric_v3/animations/idle")
	DirAccess.make_dir_recursive_absolute(dir_out)
	var frames := {}
	for i in 8:
		var cell := strip.get_region(Rect2i(i * 512, 0, 512, 512))
		cell.resize(128, 128, Image.INTERPOLATE_NEAREST)
		cell.save_png("%s/idle_%s_0.png" % [dir_out, DIRS[i]])
		frames[DIRS[i]] = cell
	# portraits and other files the meta names are shared with alaric_v2 (copied, so the sheet is self-contained)
	for sub in ["portraits"]:
		var src := ProjectSettings.globalize_path(ROOT + "alaric_v2/" + sub)
		var dst := ProjectSettings.globalize_path(ROOT + "alaric_v3/" + sub)
		DirAccess.make_dir_recursive_absolute(dst)
		for f in DirAccess.get_files_at(src):
			if f.ends_with(".png"):
				DirAccess.copy_absolute(src + "/" + f, dst + "/" + f)
	print("frames written")
	quit(0)
