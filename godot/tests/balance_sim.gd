extends Node
## The difficulty and balance simulator (not a pass/fail check). It plays the story battles over and over with the real maps, the real stats and the real
## rules, the AI playing BOTH sides (EnemyAI): the party summons its vessels as the fight gets close, the enemies bring their waves and Vesper flees at her
## percent. It reports how often the party wins, how long it takes, what is left of the party, who falls, and which enemy kinds do the damage.
##
##   godot --headless --path godot res://tests/balance_sim.tscn -- maps=r1,r2,c3 runs=20 [seed=1000] [party=0] [hp=1.0] [atk=0] [drop=0] [out=/tmp/x.json]
##
##   maps    r1..r5 (Riverford), c1..c3 (the Crucible), t (the two-squire tutorial fight, the yardstick); default every map
##   runs    fights per map (each with its own seed)
##   party   levels the party is above (+) or below (-) the enemies (default 0: even)
##   hp, atk, mag the enemies' HP multiplier and Attack added (to try a change before editing Riverford.KINDS / Crucible.KINDS)
##   drop    enemies left out, from the end of each list (a map's initial enemies; waves untouched)
##   quiet=1 only the table
##
## READ THE RESULT WITH CARE: the AI party plays worse than a person (it has no plan for terrain, no patience, it summons by a rule), so "fair" here means
## the fight is not hopeless for a competent player: the win rate bands are  >90% easy,  60-90% fair,  30-60% hard,  <30% brutal  for the AI party, and a
## person should do better. Compare maps against each other and against the tutorial fight (t) more than against the number itself.
## tools/balance/run.sh runs one process per map in parallel and merges the tables.
var runs := 20
var seed0 := 1000
var party_offset := 0
var hp_scale := 1.0
var atk_delta := 0
var drop := 0
var mag_delta := 0
var quiet := false
var trace := false
var trace_from := 0
var king_nerve := 1.6  ## the King's danger scale: a person keeps the King out of harm's way (when the King falls the vessels are cut loose: the battle is as good as lost)
var party_nerve := 0.25  ## the party's danger scale (EnemyAI): people trade blows, the AI's own caution would make a stalemate of it
var out_path := ""
var maps: Array[String] = []

const ALL := ["t", "r1", "r2", "r3", "r4", "r5", "c1", "c2", "c3"]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"runs": runs = kv[1].to_int()
			"seed": seed0 = kv[1].to_int()
			"party": party_offset = kv[1].to_int()
			"hp": hp_scale = kv[1].to_float()
			"atk": atk_delta = kv[1].to_int()
			"drop": drop = kv[1].to_int()
			"mag": mag_delta = kv[1].to_int()
			"quiet": quiet = kv[1] == "1"
			"trace":
				trace = kv[1] != "0"
				trace_from = maxi(kv[1].to_int() - 1, 0) if kv[1] != "1" else 0
			"nerve": party_nerve = kv[1].to_float()
			"kingnerve": king_nerve = kv[1].to_float()
			"out": out_path = kv[1]
			"maps":
				for m in kv[1].split(",", false):
					maps.append(m)
	if maps.is_empty():
		maps.assign(ALL)
	SaveSystem.dir = "user://test_saves_balance"
	var report := {}
	for m in maps:
		report[m] = run_map(m)
	print_table(report)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	get_tree().quit()


func run_map(id: String) -> Dictionary:
	var rows: Array = []
	for i in runs:
		var t0 := Time.get_ticks_msec()
		var r := fight(id, seed0 + i)
		r["secs"] = (Time.get_ticks_msec() - t0) / 1000.0
		rows.append(r)
		if not quiet:
			print("  %s #%d: %s, %d rounds, party %d%% left, %d down, %.1fs" % [id, i, "WON " if r.won else "LOST", r.rounds, roundi(100.0 * r.hp_left), r.downs, r.secs])
	return summarize(rows)


func summarize(rows: Array) -> Dictionary:
	var n := rows.size()
	var wins := 0
	var rounds := 0.0
	var hp_win := 0.0
	var wins_hp := 0
	var downs := 0.0
	var king_down := 0
	var timeouts := 0
	var dmg_by_kind := {}
	var dmg_to_kind := {}
	var by_party := {}
	var summons := 0.0
	var friendly := 0.0
	var secs := 0.0
	for r in rows:
		wins += 1 if r.won else 0
		rounds += r.rounds
		downs += r.downs
		king_down += 1 if r.king_down else 0
		timeouts += 1 if r.timeout else 0
		secs += r.secs
		if r.won:
			hp_win += r.hp_left
			wins_hp += 1
		for k in r.dealt_by:
			dmg_by_kind[k] = dmg_by_kind.get(k, 0.0) + r.dealt_by[k]
		for k in r.taken_by:
			dmg_to_kind[k] = dmg_to_kind.get(k, 0.0) + r.taken_by[k]
		for k in r.by_party:
			by_party[k] = by_party.get(k, 0.0) + r.by_party[k]
		summons += r.summons
		friendly += r.friendly
	var rate := float(wins) / maxi(n, 1)
	var ci := 1.96 * sqrt(rate * (1.0 - rate) / maxi(n, 1))
	for k in dmg_by_kind:
		dmg_by_kind[k] = snappedf(dmg_by_kind[k] / n, 0.1)
	for k in dmg_to_kind:
		dmg_to_kind[k] = snappedf(dmg_to_kind[k] / n, 0.1)
	for k in by_party:
		by_party[k] = snappedf(by_party[k] / n, 0.1)
	return {"runs": n, "win_rate": rate, "ci": ci, "rounds": rounds / n, "hp_left_in_wins": hp_win / maxi(wins_hp, 1), "party_down": downs / n,
		"king_down_rate": float(king_down) / n, "timeouts": timeouts, "damage_by_enemy_kind": dmg_by_kind, "damage_to_enemy_kind": dmg_to_kind, "damage_by_party_unit": by_party, "summons": summons / n, "friendly_fire": friendly / n, "secs_per_fight": secs / n, "verdict": verdict(rate)}


static func verdict(rate: float) -> String:
	if rate > 0.9:
		return "easy"
	if rate >= 0.6:
		return "fair"
	if rate >= 0.3:
		return "hard"
	return "brutal"


func print_table(report: Dictionary) -> void:
	print("")
	print("| map | runs | win rate | verdict | rounds | party HP left (wins) | party KOs | King KO'd | stalled | s/fight |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for id in report:
		var s: Dictionary = report[id]
		print("| %s %s | %d | %d%% +-%d | %s | %.1f | %d%% | %.1f | %d%% | %d | %.1f |" % [id, name_of(id), s.runs, roundi(100.0 * s.win_rate), roundi(100.0 * s.ci), s.verdict, s.rounds,
			roundi(100.0 * s.hp_left_in_wins), s.party_down, roundi(100.0 * s.king_down_rate), s.timeouts, s.secs_per_fight])
	print("")
	for id in report:
		var s: Dictionary = report[id]
		print("%s damage dealt per fight by enemy kind: %s" % [id, s.damage_by_enemy_kind])
		print("%s damage taken per fight by enemy kind: %s" % [id, s.damage_to_enemy_kind])
		print("%s damage dealt per fight by party unit: %s   (summons used: %.1f, friendly fire per fight: %.1f)" % [id, s.damage_by_party_unit, s.summons, s.friendly_fire])


func name_of(id: String) -> String:
	if id == "t":
		return "tutorial (2 squires)"
	var n := int(id.substr(1))
	return Riverford.NAMES[n] if id.begins_with("r") else Crucible.NAMES[n]


## The setup, the party's game and the enemy level for a map id.
func build(id: String) -> Array:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var setup: BattleSetup
	var level := 2
	if id == "t":
		setup = FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, ChamberCutscene.SQUIRES_TO)
		level = 1
	elif id.begins_with("r"):
		var n := int(id.substr(1))
		setup = Riverford.setup(n)
		level = Riverford.ENEMY_LEVEL[n]
		if n >= 5:
			Riverford.add_merc(g)
	else:
		var n := int(id.substr(1))
		Riverford.add_merc(g)
		if n == 3:
			Crucible.unlock_party(g)  # Lyra is the Co-Captain, Gideon and Kaelen are there
		setup = Crucible.setup(n)
		level = Crucible.ENEMY_LEVEL[n]
	return [g, setup, level]


func fight(id: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	seed(seed_value)  # the AI's random picks (confusion) and the stones
	var built := build(id)
	var g: SaveGame = built[0]
	var setup: BattleSetup = built[1]
	var level: int = built[2] + party_offset
	g.roster.king.stats.level = level
	for v in g.roster.vessels():
		v.stats.level = maxi(1, level)
	for c in g.roster.co_captains:
		c.stats.level = maxi(c.stats.level, level)
	var map := Terrain.load_map(setup.map_path)
	var grid := TacticalGrid.from_map(map)
	var b := BattleController.new()
	add_child(b)
	b.setup(grid)
	b.rng.seed = seed_value
	CampaignFlow.prepare_deployment(g, b.deployment, 6)
	b.deployment.rng.seed = seed_value
	var king := b.deployment.deploy_king(g.roster.king, setup.king_cell)
	var captain_data := g.roster.deployed_co_captain()
	if captain_data != null and setup.captain_cell != TacticalGrid.NO_CELL:
		b.deployment.deploy_co_captain(captain_data, setup.captain_cell)
	for r in setup.relics:
		b.deployment.place_relic(r[0], r[1])
	# the enemies, with the knobs
	for i in drop:
		if setup.enemies.size() > 2:
			setup.enemies.pop_back()
	var foes: Array[BattleUnit] = []
	for e in setup.enemies:
		_tune(e[0])
		if not setup.fixed_styles:
			EnemyStyles.assign(e[0], rng)
		var bu := b.add_enemy(e[0], e[1])
		foes.append(bu)
		if setup.flee.has(e[0].display_name):
			b.fleeing[bu] = int(setup.flee[e[0].display_name])
	b.start()
	var waves: Array = setup.waves.duplicate()
	var dealt_by := {}  ## enemy kind name -> damage it did to the party
	var taken_by := {}  ## enemy kind name -> damage the party did to it
	var by_party := {}  ## party unit name -> damage it did
	var friendly := 0.0  ## damage the party did to itself
	var acted := {}
	var round := 1
	var turns := 0
	var guard := 900
	while b.outcome == BattleController.Outcome.ONGOING and turns < guard:
		var bu := b.next_turn()
		if bu == null:
			break
		turns += 1
		if acted.has(bu):
			round += 1
			acted.clear()
		acted[bu] = true
		while not waves.is_empty() and round >= int(waves[0].round):
			_wave(b, grid, waves.pop_front(), rng)
		bu.ai_danger_scale = (king_nerve if bu.is_king() else party_nerve) if bu.team == 0 else 1.0
		if bu.team == 0 and bu.is_king():
			_summon(b, bu)
		var before := {}
		for u in b.all_units():
			before[u] = u.hp
		var plan := EnemyAI.take_turn(b, bu)
		if trace and turns >= trace_from and turns < trace_from + 40:
			print("    r%d %s (%s) at %s: %s%s%s%s%s" % [round, bu.data.display_name, "party" if bu.team == 0 else "foe", bu.cell, "walk " + str(plan.move_to) if plan.moves() else "", " act " + plan.action.display_name() + "->" + str(plan.aim) if plan.acts() else "", " DEFEND" if plan.defend else "", " acted=%s" % b.acted, " [face %s style %s hp %d]" % [bu.facing, bu.style().geometry if bu.style() else -1, bu.hp]])
		if b.current == bu:
			b.end_turn()
		for u in before:
			var lost: int = before[u] - u.hp
			if lost > 0 and u != bu:
				if bu.team == 0 and u.team == 0:
					friendly += lost
				if bu.team != 0 and u.team == 0:
					dealt_by[bu.data.display_name] = dealt_by.get(bu.data.display_name, 0.0) + lost
				elif bu.team == 0 and u.team != 0:
					taken_by[u.data.display_name] = taken_by.get(u.data.display_name, 0.0) + lost
					by_party[bu.data.display_name] = by_party.get(bu.data.display_name, 0.0) + lost
	var hp := 0.0
	var count := 0
	var downs := 0
	var king_down := king.is_down()
	for u in b.deployment.field_units():
		count += 1
		hp += float(maxi(u.hp, 0)) / maxi(u.max_hp(), 1)
		if u.is_down():
			downs += 1
	var timeout := b.outcome == BattleController.Outcome.ONGOING
	var result := {"timeout": timeout, "won": b.outcome == BattleController.Outcome.WON, "rounds": round, "turns": turns, "hp_left": hp / maxi(count, 1), "downs": downs,
		"king_down": king_down, "summons": b.deployment.summons_made, "by_party": by_party, "friendly": friendly, "dealt_by": dealt_by, "taken_by": taken_by}
	b.queue_free()
	return result


func _tune(e: EnemyData) -> void:
	e.stats.base_max_hp = clampi(roundi(e.stats.base_max_hp * hp_scale), 20, 300)
	e.stats.attack = maxi(e.stats.attack + atk_delta, 1)
	e.stats.magic = maxi(e.stats.magic + mag_delta, 0) if e.stats.magic > 0 else 0


## The party's vessels step out as the fight gets close, one a turn, each onto the stone nearest the enemy that can take it (the King summons: free).
func _summon(b: BattleController, king: BattleUnit) -> void:
	var near := 99
	for f in b.enemies:
		if not f.is_down():
			near = mini(near, absi(f.cell.x - king.cell.x) + absi(f.cell.y - king.cell.y))
	if near > 12 and b.summary.turns < 30:
		return
	for v in b.deployment.owned_vessels:
		if b.deployment.is_deployed(v) or b.deployment.removed.has(v):
			continue
		var best := TacticalGrid.NO_CELL
		var best_d := 999
		for c in b.deployment.props.keys():
			if b.deployment.can_summon(v, c):
				var d := 999
				for f in b.enemies:
					if not f.is_down():
						d = mini(d, absi(f.cell.x - c.x) + absi(f.cell.y - c.y))
				if d < best_d:
					best_d = d
					best = c
		if best != TacticalGrid.NO_CELL:
			b.summon_vessel(king, v, best)
			return


func _wave(b: BattleController, grid: TacticalGrid, w: Dictionary, rng: RandomNumberGenerator) -> void:
	for e in w.enemies:
		_tune(e[0])
		EnemyStyles.assign(e[0], rng)
		var c: Vector2i = e[1]
		var placed := false
		for r in 5:
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					var n := c + Vector2i(dx, dy)
					if not placed and absi(dx) + absi(dy) == r and grid.in_bounds(n) and grid.can_stand(n) and not grid.is_occupied(n):
						b.add_enemy(e[0], n)
						placed = true
