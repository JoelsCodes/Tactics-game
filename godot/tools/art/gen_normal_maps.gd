extends SceneTree
## Generates a normal map for every frame of a character sheet, beside (not over) the artwork:
##   godot --headless --path godot --script res://tools/art/gen_normal_maps.gd -- alaric_v2
## assets/characters/<sheet>/animations/<anim>/<frame>.png  ->  assets/characters/<sheet>/normals/<anim>/<frame>.png  (same size, same pixel grid)
## The height field is a soft dome from the silhouette (so the body reads round) plus the drawing's own local brightness detail (folds, straps, hair
## read as relief and dark linework as grooves). Tangent space, +Y up (OpenGL), RGB; transparent pixels are flat. UnitView3D loads them
## (`_normal_for`) and the hybrid shader (shaders/unit_hybrid.gdshader) lights with them. Hand-painted maps can replace any of these files.
const DOME := 9.0  ## height of the silhouette dome, in sprite pixels
const DETAIL := 6.0  ## height of the brightness detail
const DOME_RADIUS := 4
const DETAIL_RADIUS := 3
const STRENGTH := 1.0


func _init() -> void:
	var sheet := "alaric_v2"
	for a in OS.get_cmdline_user_args():
		sheet = a
	var root := "res://assets/characters/%s/animations" % sheet
	var n := 0
	for anim in DirAccess.get_directories_at(root):
		DirAccess.make_dir_recursive_absolute("res://assets/characters/%s/normals/%s" % [sheet, anim])
		for f in DirAccess.get_files_at("%s/%s" % [root, anim]):
			if not f.ends_with(".png"):
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s/%s" % [root, anim, f]))
			if img == null:
				push_error("cannot read " + f)
				continue
			_normal(img).save_png(ProjectSettings.globalize_path("res://assets/characters/%s/normals/%s/%s" % [sheet, anim, f]))
			n += 1
	print("normal maps written: ", n)
	quit(0)


func _normal(src: Image) -> Image:
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var a := PackedFloat32Array()
	var l := PackedFloat32Array()
	a.resize(w * h)
	l.resize(w * h)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			a[y * w + x] = 1.0 if c.a > 0.5 else 0.0
			l[y * w + x] = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * a[y * w + x]
	var dome := _blur(_blur(_blur(a, w, h, DOME_RADIUS), w, h, DOME_RADIUS), w, h, DOME_RADIUS)
	var low := _blur(l, w, h, DETAIL_RADIUS)
	var ht := PackedFloat32Array()
	ht.resize(w * h)
	for i in w * h:
		ht[i] = dome[i] * DOME + (l[i] - low[i]) * DETAIL * 2.0 * a[i]
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if a[y * w + x] < 0.5:
				out.set_pixel(x, y, Color(0.5, 0.5, 1.0, 1.0))
				continue
			var dx := (ht[y * w + mini(x + 1, w - 1)] - ht[y * w + maxi(x - 1, 0)]) * 0.5
			var dy := (ht[mini(y + 1, h - 1) * w + x] - ht[maxi(y - 1, 0) * w + x]) * 0.5
			var n := Vector3(-dx * STRENGTH, dy * STRENGTH, 1.0).normalized()  # image y points down; up on screen is -y, so the slope toward up is -dy: n.y = +dy
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return out


func _blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var dst := PackedFloat32Array()
	dst.resize(w * h)
	var inv := 1.0 / float(2 * r + 1)
	for y in h:
		for x in w:
			var s := 0.0
			for k in range(-r, r + 1):
				s += src[y * w + clampi(x + k, 0, w - 1)]
			tmp[y * w + x] = s * inv
	for y in h:
		for x in w:
			var s := 0.0
			for k in range(-r, r + 1):
				s += tmp[clampi(y + k, 0, h - 1) * w + x]
			dst[y * w + x] = s * inv
	return dst
