extends Node
## First-use hitch probe: godot --path godot res://tests/first_use_probe.tscn
## Times the frames around the first use of each effect in a battle (shader and pipeline compilation, first texture uploads). Software renderer: relative.
func _ready():
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = Riverford.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 100000.0
	add_child(s)
	await get_tree().create_timer(1.5).timeout
	var king: BattleUnit = s.battle.deployment.king
	var v: UnitView3D = s.views[king]
	var fx: Node3D = s.fx
	var steps := {
		"idle (baseline)": func(): pass,
		"burst fire": func(): EffectLibrary.burst(fx, "fire", v.global_position + Vector3(0, 0.7, 0), 1.0),
		"ring ice": func(): EffectLibrary.ring(fx, "ice", v.global_position, 1.0),
		"aura holy": func(): EffectLibrary.aura(fx, "holy", v.global_position, 1.0),
		"projectile spark": func(): EffectLibrary.projectile(fx, "spark", v.global_position + Vector3(0, 0.9, 0), v.global_position + Vector3(3, 0.9, 0)),
		"status marks": func(): s.battle.deployment.king.add_status("sleep", 2),
		"afterimages": func(): v.afterimages(0.3),
		"damage number": func(): s.feedback.number(king, "12", "damage"),
		"hit flash": func(): v.hit_react(Vector3(1, 0, 0), 0.1, 0.1),
	}
	var out := []
	for name in steps:
		var worst := 0.0
		var t_prev := Time.get_ticks_usec()
		steps[name].call()
		for i in 6:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, float(now - t_prev) / 1000.0)
			t_prev = now
		out.append("%s: worst frame %.0f ms" % [name, worst])
		for i in 20:
			await get_tree().process_frame
	for l in out: print("FIRSTUSE ", l)
	get_tree().quit()
