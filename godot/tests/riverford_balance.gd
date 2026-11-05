extends Node
## Not a pass/fail check: plays each Riverford battle many times with the AI on both sides (the party is Alaric, Bram, Lyra and, from map 5, Merc, all
## summoned at once) and prints the win rate, the length and what the party has left. An AI party plays worse than a person, so a win rate of about 70% to
## 95% is "fair". Pass runs=N (default 20), party=+/-N levels relative to the enemies.
## godot --headless --path godot res://tests/riverford_balance.tscn -- runs=30
var runs := 20
var party_bonus := 0
var only := 0
var baseline := ""  ## "chamber": the tutorial fight (two squires, basic attack only) with the same party, for comparison
var hp_scale := 1.0
var atk_delta := 0
var drop := 0  ## enemies left out (from the end), to see how many the party can take


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("runs="):
			runs = a.substr(5).to_int()
		elif a.begins_with("map="):
			only = a.substr(4).to_int()
		elif a.begins_with("baseline="):
			baseline = a.substr(9)
		elif a.begins_with("hp="):
			hp_scale = a.substr(3).to_float()
		elif a.begins_with("atk="):
			atk_delta = a.substr(4).to_int()
		elif a.begins_with("drop="):
			drop = a.substr(5).to_int()
		elif a.begins_with("party="):
			party_bonus = a.substr(6).to_int()
	SaveSystem.dir = "user://test_saves_balance"
	for n in range(1, 6):
		if (only > 0 and n != only) or (baseline != "" and n != 1):
			continue
		var wins := 0
		var turns := 0
		var left := 0.0
		var downs := 0
		for i in runs:
			var t0 := Time.get_ticks_msec()
			var r := fight(n, 1000 + i)
			print("  map %d run %d: %s in %d turns, %.1f s" % [n, i, "won" if r[0] else "lost", r[1], (Time.get_ticks_msec() - t0) / 1000.0])
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
	var level: int = Riverford.ENEMY_LEVEL[n] + party_bonus
	g.roster.king.stats.level = level
	for v in g.roster.vessels():
		v.stats.level = level
	var setup := Riverford.setup(n)
	# an open field, so that the AI's greedy walking is not the thing being measured: the party on the left, the enemies in a block on the right
	var row := " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"]))
	var rows := []
	for i in 16:
		rows.append(row)
	var grid := TacticalGrid.from_rows(rows)
	setup.king_cell = Vector2i(7, 2)
	setup.relics = [[FirstBattle._stone(), Vector2i(6, 1)], [FirstBattle._stone(), Vector2i(8, 1)], [FirstBattle._stone(), Vector2i(7, 0)], [FirstBattle._stone(), Vector2i(5, 2)]]
	if baseline == "chamber":
		setup.enemies = [[FirstBattle.squire(1), Vector2i(0, 0)], [FirstBattle.squire(2), Vector2i(0, 0)]]
		setup.flee = {}
		setup.waves = []
	for i in drop:
		if setup.enemies.size() > 2:
			setup.enemies.pop_back()
	for e in setup.enemies:
		e[0].stats.base_max_hp = clampi(roundi(e[0].stats.base_max_hp * hp_scale), 25, 100)
		e[0].stats.attack = maxi(e[0].stats.attack + atk_delta, 1)
	var k := 0
	for e in setup.enemies:
		e[1] = Vector2i(5 + k % 4 * 2, 11 + k / 4 * 2)
		k += 1
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
		if bu.is_king():  # the party's vessels come out when the fight is close: one at a time, each on its own stone, as a careful player would
			var near := 99
			for f in b.enemies:
				if not f.is_down():
					near = mini(near, absi(f.cell.x - bu.cell.x) + absi(f.cell.y - bu.cell.y))
			if near <= 9 or turn > 24:
				var stones := b.deployment.props.keys()
				for v in g.roster.vessels():
					if b.deployment.is_deployed(v) or b.deployment.removed.has(v):
						continue
					for c in stones:
						if b.deployment.can_summon(v, c):
							b.summon_vessel(bu, v, c)
							break
					break  # one a turn
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
