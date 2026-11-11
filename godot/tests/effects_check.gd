extends Node
## Headless: the shared effect library. Every look has what the pieces read, every piece runs on every look and frees itself, and the cap holds.
## godot --headless --path godot res://tests/effects_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var looks := EffectLibrary.looks()
	ok(looks.size() >= 4, "fire, ice, spark and holy are defined")
	for n in looks:
		var l: Dictionary = looks[n]
		for k in ["color", "glow", "core", "tex", "gravity", "speed", "count", "size", "life", "head", "projectile_speed", "ring", "beam_width"]:
			ok(l.has(k), "%s has %s" % [n, k])
		ok(["soft", "shard", "star"].has(String(l.get("tex", ""))), "%s names a known texture" % n)
	for t in ["soft", "ring", "shard", "star", "beam"]:
		ok(EffectLibrary.texture(t) != null and EffectLibrary.texture(t).get_width() > 0, "texture %s is drawn" % t)
	ok(not EffectLibrary.look("no_such_look").is_empty(), "an unknown look falls back to spark")
	var root := Node3D.new()
	add_child(root)
	await get_tree().process_frame
	for n in looks:
		EffectLibrary.burst(root, n, Vector3.ZERO)
		EffectLibrary.ring(root, n, Vector3.ZERO, 1.0)
		EffectLibrary.aura(root, n, Vector3.ZERO, 0.3)
		EffectLibrary.beam(root, n, Vector3.ZERO, Vector3(2, 0, 0), 0.2)
		await EffectLibrary.projectile(root, n, Vector3.ZERO, Vector3(2, 0, 0))
	ok(root.get_child_count() > 0, "pieces were made")
	await get_tree().create_timer(2.2).timeout
	ok(root.get_child_count() == 0, "and every piece freed itself (%d left)" % root.get_child_count())
	ok(EffectLibrary.live == 0, "the live count is back to zero (%d)" % EffectLibrary.live)
	for i in 80:
		EffectLibrary.burst(root, "fire", Vector3.ZERO)
	ok(root.get_child_count() <= EffectLibrary.MAX_LIVE * 2, "the cap holds (%d pieces for 80 requests)" % root.get_child_count())
	print("effects checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
