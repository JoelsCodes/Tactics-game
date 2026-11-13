extends Node
## Renders the Last Benediction battlefield with its isometric camera and a few 2D sprite units, to look at the materials, lighting and occlusion.
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --resolution 1920x1080 res://tests/last_benediction_shot.tscn -- out=/tmp/last_benediction.png
func _ready() -> void:
	var out := "/tmp/last_benediction.png"
	var size := 17.0
	var corner := 0
	var occlusion := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("size="):
			size = float(a.substr(5))
		elif a == "occlusion":
			occlusion = true
		elif a.begins_with("corner="):
			corner = int(a.substr(7))
	var b := LastBenedictionBoard.new()
	add_child(b)
	if not b.build():
		get_tree().quit(1)
		return
	b.camera.size = size
	b.set_view(corner)
	b.place_unit("alaric_v2", b.spawns()[0])
	b.place_unit("warden", b.spawns()[1])
	b.place_unit("mira", Vector2i(5, 3))
	b.place_unit("squire", Vector2i(5, 8), 1)   # an enemy on the objective's tile, to see a sprite on the raised step
	for i in 12:
		await get_tree().process_frame
	if occlusion:
		await _occlusion(b, corner)
		get_tree().quit(0)
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit(0)


## How many floor tiles the scenery covers from this corner: render once with the scenery and once without it (no shadows, no units), and
## compare a small window around each tile's centre on screen.
func _occlusion(b: LastBenedictionBoard, corner: int) -> void:
	for u in b.find_children("*", "UnitView3D", false, false):
		u.visible = false
	b.sun.shadow_enabled = false
	for i in 6:
		await get_tree().process_frame
	var full := get_viewport().get_texture().get_image()
	for m in b.merged:
		m.visible = false
	for i in 6:
		await get_tree().process_frame
	var bare := get_viewport().get_texture().get_image()
	var covered := []
	var open := 0
	for c in b.floors:
		var p := b.camera.unproject_position(b.cell_to_world(c))
		var diff := 0.0
		var n := 0
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x < 0 or y < 0 or x >= full.get_width() or y >= full.get_height():
					continue
				var a := full.get_pixel(x, y)
				var q := bare.get_pixel(x, y)
				diff += absf(a.r - q.r) + absf(a.g - q.g) + absf(a.b - q.b)
				n += 1
		if n > 0 and diff / n > 0.08:
			covered.append(c)
		else:
			open += 1
	print("corner %d: %d of 121 floor centres are open, %d covered by scenery %s" % [corner, open, covered.size(), str(covered)])
