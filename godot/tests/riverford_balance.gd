extends Node
## Not a pass/fail check: plays each Riverford battle many times with the AI on both sides (the party is Alaric, Bram, Lyra and, from map 5, Merc, all
## summoned at once) and prints the win rate, the length and what the party has left. An AI party plays worse than a person, so a win rate of about 70% to
## 95% is "fair". Pass runs=N (default 20), party=+/-N levels relative to the enemies.
## godot --headless --path godot res://tests/riverford_balance.tscn -- runs=30
var runs := 20
var party_bonus := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("runs="):
			runs = a.substr(5).to_int()
		elif a.begins_with("party="):
			party_bonus = a.substr(6).to_int()
	SaveSystem.dir = "user://test_saves_balance"
	for n in range(1, 6):
		var wins := 0
		var turns := 0
		var left := 0.0
		var downs := 0
		for i in runs:
			var r := fight(n, 1000 + i)
			wins += 1 if r[0] else 0
			turns += r[1]
			left += r[2]
			downs += r[3]
		print("map %d %-18s wins %3d%%  turns %3d  party HP left %3d%%  party knocked out %.1f per fight" % [n, Riverford.NAMES[n], 100 * wins / runs, turns / runs, roundi(100.0 * left / runs), float(downs) / runs])
	get_tree().quit()


func fight(n: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var g := FirstBattle.chamber_game(FirstBattle.game())
	if n >= 5:
		Riverford.add_merc(g)
	var level := Riverford.ENEMY_LEVEL[n] + party_bonus
	g.roster.king.stats.level = level
	for v in g.roster.vessels():
		v.stats.level = level
	var setup := Riverford.setup(n)
	var map := Terrain.load_map(setup.map_path)
	var grid := TacticalGrid.from_map(map)
	var b := BattleController.new()
	add_child(b)
	b.setup(grid)
	b.rng.seed = seed_value
	CampaignFlow.prepare_deployment(g, b.deployment, 6)
	b.deployment.rng.seed = seed_value
	var king := b.deployment.deploy_king(g.roster.king, setup.king_cell)
	for r in setup.relics:
		b.deployment.place_relic(r[0], r[1])
	var foes: Array[BattleUnit] = []
	for e in setup.enemies:
		EnemyStyles.assign(e[0], rng)
		var bu := b.add_enemy(e[0], e[1])
		foes.append(bu)
		if setup.flee.has(e[0].display_name):
			b.fleeing[bu] = int(setup.flee[e[0].display_name])
	b.start()
	var waves: Array = setup.waves.duplicate()
	var summoned := false
	var turn := 0
	var max_turns := 220
	while b.outcome == BattleController.Outcome.ONGOING and turn < max_turns:
		var bu := b.next_turn()
		if bu == null:
			break
		turn += 1
		if not waves.is_empty() and turn >= int(waves[0].round) * 6:
			var w: Dictionary = waves.pop_front()
			for e in w.enemies:
				EnemyStyles.assign(e[0], rng)
				var c: Vector2i = e[1]
				var placed: BattleUnit = null
				for rr in 4:
					for dx in range(-rr, rr + 1):
						for dy in range(-rr, rr + 1):
							if placed == null and absi(dx) + absi(dy) == rr and grid.can_stand(c + Vector2i(dx, dy)) and not grid.is_occupied(c + Vector2i(dx, dy)):
								placed = b.add_enemy(e[0], c + Vector2i(dx, dy))
		if bu.is_king() and not summoned:
			summoned = true
			var stones := b.deployment.props.keys()
			var si := 0
			for v in g.roster.vessels():
				if si < stones.size() and b.deployment.can_summon(v, stones[si]):
					b.summon_vessel(bu, v, stones[si])
					si += 1
		EnemyAI.take_turn(b, bu)
		b.end_turn()
	var party := b.deployment.field_units()
	var hp := 0.0
	var downs := 0
	for u in party:
		hp += float(maxi(u.hp, 0)) / maxi(u.max_hp(), 1)
		if u.is_down():
			downs += 1
	var won := b.outcome == BattleController.Outcome.WON
	var result := [won, turn, hp / maxi(party.size(), 1), downs]
	b.queue_free()
	return result
