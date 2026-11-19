extends SceneTree
## Cuts one animation sheet for `alaric_v3`: a grid of N frames across (columns) and the 8 directions down (rows, in the game's order s sw w nw n ne e se),
## every cell 512x512 with the figure at 4x its final size, into 128x128 frames (nearest 4x downscale):
##   godot --headless --path godot --script res://tools/art/cut_anim_v3.gd -- <anim> <sheet.png> <frames>
## Writes assets/characters/alaric_v3/animations/<anim>/<anim>_<dir>_<i>.png and records the animation in assets/characters/alaric_v3/anims.json
## (frames, fps, loop). Then run `godot --import` and tools/art/wire_v3.gd, which rebuilds alaric_v3.tres and its meta.json entry.
const DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
const ROOT := "res://assets/characters/alaric_v3/"
const DEFAULTS := {"walk": {"fps": 8, "loop": true}, "attack": {"fps": 14, "loop": false, "strike": 3}}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var anim: String = a[0]
	var frames := int(a[2])
	var sheet := Image.load_from_file(a[1])
	sheet.convert(Image.FORMAT_RGBA8)
	if sheet.get_width() != frames * 512 or sheet.get_height() != 8 * 512:
		push_error("expected %dx%d, got %dx%d" % [frames * 512, 8 * 512, sheet.get_width(), sheet.get_height()])
		quit(1)
		return
	var out := ProjectSettings.globalize_path(ROOT + "animations/" + anim)
	DirAccess.make_dir_recursive_absolute(out)
	for r in 8:
		for c in frames:
			var cell := sheet.get_region(Rect2i(c * 512, r * 512, 512, 512))
			cell.resize(128, 128, Image.INTERPOLATE_NEAREST)
			cell.save_png("%s/%s_%s_%d.png" % [out, anim, DIRS[r], c])
	var cfg_path := ProjectSettings.globalize_path(ROOT + "anims.json")
	var cfg := {}
	if FileAccess.file_exists(cfg_path):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	var e: Dictionary = DEFAULTS.get(anim, {"fps": 10, "loop": false}).duplicate()
	e["frames"] = frames
	cfg[anim] = e
	var f := FileAccess.open(cfg_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(cfg, "  "))
	f.close()
	print("cut ", anim, ": ", frames * 8, " frames")
	quit(0)
