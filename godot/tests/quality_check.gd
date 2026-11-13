extends Node
## Graphics quality levels (F8): what each level switches on, and that High is the original look. godot --headless --path godot res://tests/quality_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var saved := Board3D.quality
	Board3D._quality_loaded = true  # tests do not read or write the player's settings
	var b := Board3D.new()
	add_child(b)
	b.setup(Terrain.load_map("res://samples/riverford_1.json"))
	await get_tree().process_frame
	var fills := []
	for c in b.get_children():
		if c is OmniLight3D and c.has_meta("fill"):
			fills.append(c)
	ok(fills.size() == 2, "the two fill lights are marked (%d)" % fills.size())
	var at := b.cam.attributes as CameraAttributesPractical
	Board3D.quality = Board3D.Quality.HIGH
	b.apply_quality()
	ok(fills.all(func(l): return l.shadow_enabled) and b.env.ssao_enabled and b.env.glow_enabled and b.env.volumetric_fog_enabled and at.dof_blur_far_enabled and at.dof_blur_near_enabled, "High: the full look, fill shadows, SSAO, glow, haze and blur on")
	ok(b.sun.shadow_enabled, "High: the sun casts shadows")
	Board3D.quality = Board3D.Quality.MEDIUM
	b.apply_quality()
	ok(fills.all(func(l): return not l.shadow_enabled), "Medium: the fill lights stop casting shadows")
	ok(b.env.ssao_enabled and b.env.glow_enabled and b.env.volumetric_fog_enabled and at.dof_blur_far_enabled, "Medium: everything else stays")
	Board3D.quality = Board3D.Quality.LOW
	b.apply_quality()
	ok(not b.env.ssao_enabled and not b.env.glow_enabled and not b.env.volumetric_fog_enabled and not at.dof_blur_far_enabled and not at.dof_blur_near_enabled, "Low: occlusion, bloom, haze and blur are off")
	ok(b.sun.shadow_enabled, "Low: the sun still casts shadows")
	Board3D.quality = Board3D.Quality.HIGH
	b.apply_quality()
	ok(fills.all(func(l): return l.shadow_enabled) and b.env.ssao_enabled, "back to High restores everything")
	Board3D.quality = saved
	print("quality checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
