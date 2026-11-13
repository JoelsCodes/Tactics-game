extends Node
## The enemy AI's speed-ups must never change what it decides: on several real battles every enemy is planned twice, with `EnemyAI.fast` on
## and off, and the two plans must be identical; and the fast one must be clearly quicker (a plan used to freeze the game for up to 0.7 s).
## godot --headless --path godot res://tests/ai_speed_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_aispeed"
	var fast_total := 0.0
	var slow_total := 0.0
	var worst_fast := 0.0
	var worst_gap := 0.0  ## the longest time the sliced plan held the frame
	var sliced_frames := 0
	for spec in [["riverford", 1], ["riverford", 3], ["crucible", 1], ["crucible", 3], ["crown", 4], ["mountain", 5], ["crown", 2]]:
		var setup: BattleSetup = null
		match spec[0]:
			"riverford": setup = Riverford.setup(spec[1])
			"crucible": setup = Crucible.setup(spec[1])
			"crown": setup = Crown.setup(spec[1])
			"mountain": setup = Mountain.setup(spec[1])
		BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
		BattleStage.pending_setup = setup
		var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
		s.enemy_delay = 100000.0
		add_child(s)
		await get_tree().create_timer(0.4).timeout
		for u in s.battle.all_units():
			if u.team == 0:
				continue
			for step in 2:  # as it stands, then after it has spent some SP and lost some HP (other branches of the search)
				if step == 1:
					u.sp = maxi(u.sp / 2, 0)
					u.hp = maxi(u.hp * 2 / 3, 1)
				var trail := u.ai_trail.duplicate()
				var stuck := u.ai_stuck
				EnemyAI.fast = false
				var t0 := Time.get_ticks_usec()
				var slow := EnemyAI.plan(s.battle, u)
				slow_total += float(Time.get_ticks_usec() - t0) / 1000.0
				u.ai_trail.assign(trail)
				u.ai_stuck = stuck
				EnemyAI.fast = true
				t0 = Time.get_ticks_usec()
				var quick := EnemyAI.plan(s.battle, u)
				var ms := float(Time.get_ticks_usec() - t0) / 1000.0
				fast_total += ms
				worst_fast = maxf(worst_fast, ms)
				u.ai_trail.assign(trail)
				u.ai_stuck = stuck
				# the time-sliced plan (what the battle uses) is the same plan, and it hands frames back while it thinks
				var frames_before := Engine.get_process_frames()
				var longest_gap := 0.0
				var last := Time.get_ticks_usec()
				var box := []  # a lambda copies the variables it uses, so the result goes into a shared array
				var runner := func():
					box.append(await EnemyAI.plan_async(s.battle, u))
				runner.call()
				while box.is_empty():
					await get_tree().process_frame
					var now := Time.get_ticks_usec()
					longest_gap = maxf(longest_gap, float(now - last) / 1000.0)
					last = now
				var sliced: EnemyAI.Plan = box[0]
				worst_gap = maxf(worst_gap, longest_gap)
				sliced_frames += Engine.get_process_frames() - frames_before
				u.ai_trail.assign(trail)
				u.ai_stuck = stuck
				var name := "%s %d %s (step %d)" % [spec[0], spec[1], u.data.display_name, step]
				var a_slow := slow.action.display_name() if slow.action != null else "-"
				var a_fast := quick.action.display_name() if quick.action != null else "-"
				var a_sl := sliced.action.display_name() if sliced.action != null else "-"
				ok(a_sl == a_fast and sliced.aim == quick.aim and sliced.move_to == quick.move_to and sliced.face == quick.face and sliced.defend == quick.defend and absf(sliced.score - quick.score) < 0.0001, "%s: the time-sliced plan equals the one-go plan" % name)
				ok(a_slow == a_fast and slow.aim == quick.aim and slow.move_to == quick.move_to and slow.face == quick.face and slow.defend == quick.defend and absf(slow.score - quick.score) < 0.0001, "%s: the fast plan equals the plain plan (%s %s %s / %s %s %s)" % [name, a_slow, slow.aim, slow.move_to, a_fast, quick.aim, quick.move_to])
		s.queue_free()
		await get_tree().process_frame
	print("ai plans: plain %.0f ms in all, fast %.0f ms (%.1fx), slowest fast plan %.0f ms" % [slow_total, fast_total, slow_total / maxf(fast_total, 0.001), worst_fast])
	ok(slow_total / maxf(fast_total, 0.001) >= 1.8, "the fast plans are at least 1.8 times quicker (%.1fx)" % (slow_total / maxf(fast_total, 0.001)))
	ok(worst_fast < 450.0, "no plan takes longer than 450 ms (%.0f ms)" % worst_fast)
	print("sliced plans held a frame for at most %.0f ms, over %d frames" % [worst_gap, sliced_frames])
	ok(worst_gap < 60.0, "a time-sliced plan never holds a frame for long (%.0f ms; one whole plan is up to %.0f ms)" % [worst_gap, worst_fast])
	print("ai speed checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)
