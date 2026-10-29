extends Node
## Headless: the intro plays to its end. The King goes into the cave (faded out), two knights come out of
## the clearing, and the scene ends faded to black. godot --headless --path godot res://tests/intro_check.tscn
var fails := 0
var count := 0
var done := false


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var s: IntroCutscene = load("res://scenes/intro.tscn").instantiate()
	add_child(s)
	s.finished.connect(func(): done = true)
	var waited := 0.0
	while not done and waited < 90.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	ok(done, "the intro reaches its end (%.1fs)" % waited)
	ok(s.king.modulate.a < 0.01, "the King has gone into the cave")
	ok(s.knights.size() == 2, "two knights came out of the clearing")
	ok(s.fade.modulate.a > 0.99, "the scene fades to black")
	print("intro checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
