extends SceneTree
## Builds the idle frames of a 4x-master character sheet (`alaric_v3` unless a sheet name is given) from a one-row 8-direction idle strip (eight 512x512
## cells, figure 4x its final size, feet on row 447):
##   godot --headless --path godot --script res://tools/art/build_v3_from_strip.gd -- <path to strip.png> [sheet name] [clean]
## Writes assets/characters/<sheet>/animations/idle/idle_<dir>_0.png (128x128, nearest 4x downscale, feet anchor (64, 112)); then run tools/art/wire_v3.gd,
## which builds the SpriteFrames and the meta.json entry. For alaric_v3 the portraits are copied from alaric_v2 (alaric_v2 is never changed). `clean`
## removes stray specks (tools/art/speck_clean.gd). The strip's cell order is the game's: s sw w nw n ne e se.
const DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
const ROOT := "res://assets/characters/"
const SpeckClean := preload("res://tools/art/speck_clean.gd")


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var name: String = a[1] if a.size() > 1 else "alaric_v3"
	var clean := a.size() > 2 and a[2] == "clean"
	var strip := Image.load_from_file(a[0])
	strip.convert(Image.FORMAT_RGBA8)
	var dir_out := ProjectSettings.globalize_path(ROOT + name + "/animations/idle")
	DirAccess.make_dir_recursive_absolute(dir_out)
	for i in 8:
		var cell := strip.get_region(Rect2i(i * 512, 0, 512, 512))
		cell.resize(128, 128, Image.INTERPOLATE_NEAREST)
		if clean:
			SpeckClean.clean(cell)
		cell.save_png("%s/idle_%s_0.png" % [dir_out, DIRS[i]])
	if name == "alaric_v3":
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
