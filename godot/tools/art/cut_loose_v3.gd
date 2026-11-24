extends SceneTree
## Cuts a loose 8 x 8 concept sheet (8 frames across, the 8 directions down in the game's order s sw w nw n ne e se) onto a 128 px-frame character sheet,
## for sheets that are not 4x masters: the owner's Shieldbearer (Bram, Nov 2026) came as 1254 x 1254 images, a 1024 native drawing resampled up, so the
## figure drifts a pixel or two from cell to cell. The whole image goes back to 1024 x 1024 (nearest: 128 px cells, the figure about 100 px tall, near
## Rex's and Alaric's 96), every frame is cleaned of specks (tools/art/speck_clean.gd), stood with its lowest pixel on the feet line (y 112, the sheets'
## anchor) and the sheet shifted as one so its figures centre on x 64 (a lunge keeps its lean):
##   godot --headless --path godot --script res://tools/art/cut_loose_v3.gd -- <anim> <sheet.png> <sheet name> [strike]
## Writes assets/characters/<sheet>/animations/<anim>/<anim>_<dir>_<i>.png and its anims.json entry; `walk` also writes the idle pose (frame 0 of each
## direction) and an 8x portrait of the south idle's head. Then `godot --import` and tools/art/wire_v3.gd <sheet name>.
const DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
const DEFAULTS := {"walk": {"fps": 8, "loop": true}, "attack": {"fps": 14, "loop": false, "strike": 3}}
const FEET := 112
const SpeckClean := preload("res://tools/art/speck_clean.gd")


static func bbox(img: Image) -> Rect2i:
	var x0 := 9999
	var y0 := 9999
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1) if x1 >= 0 else Rect2i()


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var anim: String = a[0]
	var root := "res://assets/characters/%s/" % a[2]
	var sheet := Image.load_from_file(a[1])
	sheet.convert(Image.FORMAT_RGBA8)
	if sheet.get_width() != sheet.get_height():
		push_error("expected a square 8 x 8 sheet, got %s" % sheet.get_size())
		quit(1)
		return
	sheet.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
	var cells := []
	var sum_cx := 0.0
	var n := 0
	var cleared := 0
	for r in 8:
		var row := []
		for c in 8:
			var cell := sheet.get_region(Rect2i(c * 128, r * 128, 128, 128))
			for y in 128:  # the resample's half-clear edge pixels: fully clear or fully opaque, as pixel art
				for x in 128:
					var px := cell.get_pixel(x, y)
					if px.a < 1.0:
						cell.set_pixel(x, y, Color(px.r, px.g, px.b, 1.0 if px.a >= 0.5 else 0.0))
			cleared += SpeckClean.clean(cell)
			var b := bbox(cell)
			if b.size.x > 0:
				sum_cx += b.get_center().x
				n += 1
			row.append([cell, b])
		cells.append(row)
	var dx := int(round(64.0 - sum_cx / maxf(n, 1)))
	var out := ProjectSettings.globalize_path(root + "animations/" + anim)
	DirAccess.make_dir_recursive_absolute(out)
	if anim == "walk":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + "animations/idle"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + "portraits"))
	for r in 8:
		for c in 8:
			var cell: Image = cells[r][c][0]
			var b: Rect2i = cells[r][c][1]
			var f := Image.create(128, 128, false, Image.FORMAT_RGBA8)
			if b.size.x > 0:
				f.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i(dx, FEET - b.end.y))
			f.save_png("%s/%s_%s_%d.png" % [out, anim, DIRS[r], c])
			if anim == "walk" and c == 0:
				f.save_png(ProjectSettings.globalize_path(root + "animations/idle/idle_%s_0.png" % DIRS[r]))
				if r == 0:  # the portrait: the head and shoulders (the top 60% of a chibi figure, whose head is half its height), 8x
					var fb := bbox(f)
					var side := int(fb.size.y * 0.6)
					var head := f.get_region(Rect2i(int(fb.get_center().x) - side / 2, fb.position.y - 1, side, side))
					head.resize(side * 8, side * 8, Image.INTERPOLATE_NEAREST)
					head.save_png(ProjectSettings.globalize_path(root + "portraits/portrait_01.png"))
	var cfg_path := ProjectSettings.globalize_path(root + "anims.json")
	var cfg := {}
	if FileAccess.file_exists(cfg_path):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	var e: Dictionary = DEFAULTS.get(anim, {"fps": 10, "loop": false}).duplicate()
	e["frames"] = 8
	if a.size() > 3:
		e["strike"] = int(a[3])
	cfg[anim] = e
	var fl := FileAccess.open(cfg_path, FileAccess.WRITE)
	fl.store_string(JSON.stringify(cfg, "  "))
	fl.close()
	print("cut ", anim, ": 64 frames, shifted ", dx, " px, ", cleared, " speck pixels cleared")
	quit(0)
