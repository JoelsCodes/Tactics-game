extends Node
## A whole-campaign playtest (not a pass/fail check): one save carried from the first fight to the last, the AI playing the party (as in balance_sim),
## experience and skills earned through the real systems (BattleController.finish: XP on a win, vessels learning by use), recruits joining where the
## story's scenes give them. A lost story battle is retried; between retries the party replays its most recent cleared maps to get stronger, like a player.
##   godot --headless --path godot res://tests/campaign_sim.tscn -- [seed=7] [from=0] [to=999] [retries=4] [grind=3] [out=/tmp/campaign.json]
## Limits: the ScenarioRules special rules (carriers, clocks, drains, standards, boss summons) need the battle stage and are NOT simulated: those battles
## are played as defeat-all-enemies. Waves and fleeing/yielding are simulated.
var seed0 := 7
var from := 0
var to := 999
var retries := 4
var grind := 3
var out_path := "/tmp/campaign.json"
var bs  # balance_sim, for its summon and wave helpers
var log_rows := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"seed": seed0 = kv[1].to_int()
				"from": from = kv[1].to_int()
				"to": to = kv[1].to_int()
				"retries": retries = kv[1].to_int()
				"grind": grind = kv[1].to_int()
				"out": out_path = kv[1]
	bs = load("res://tests/balance_sim.gd").new()
	var g := FirstBattle.game()
	var order := story_order()
	var cleared: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for i in order.size():
		var id: String = order[i]
		if id == "chamber":
			g = FirstBattle.chamber_game(g)
		_gives(g, id, "pre")
		if i < from or i > to:
			cleared.append(id)
			_gives(g, id, "post")
			continue
		var tries := 0
		var grinds := 0
		var res := {}
		while true:
			tries += 1
			res = play(g, id, seed0 * 1000 + i * 17 + tries)
			if res.won or tries > retries:
				break
			for k in grind:  # get stronger on the maps already cleared
				if cleared.is_empty():
					break
				var back: String = cleared[maxi(0, cleared.size() - 1 - (k % 2))]
				var gr := play(g, back, seed0 * 7919 + i * 31 + tries * 5 + k)
				grinds += 1
		cleared.append(id)
		_gives(g, id, "post")
		var row := {"i": i, "map": id, "won": res.won, "tries": tries, "grinds": grinds, "rounds": res.rounds, "downs": res.downs, "king_down": res.king_down,
			"hp_left": snappedf(res.hp_left, 0.01), "king_level": g.roster.king.stats.level, "levels": _levels(g), "skills": _skills(g).size(), "secs": (Time.get_ticks_msec() - t0) / 1000}
		log_rows.append(row)
		print("%3d %-12s %s tries %d grinds %d rounds %3d KOs %d king %s | Alaric L%d | party %s | skills learned %d" % [i, id, "WON " if res.won else "LOST", tries, grinds, res.rounds,
			res.downs, "down" if res.king_down else "up", g.roster.king.stats.level, row.levels, row.skills])
		_write(g)
	print("CAMPAIGN DONE in %ds" % ((Time.get_ticks_msec() - t0) / 1000))
	_write(g)
	get_tree().quit(0)


## The story's battles in order, as the world map opens them.
func story_order() -> Array[String]:
	var out: Array[String] = ["hallway", "chamber"]
	for p in WorldData.PLACES:
		for m in p.maps:
			if m.get("mission", false):
				out.append(String(m.id))
	return out


## Recruits that the map's story scenes give (pre: before the fight, post: after the win), following each scene's "next" chain.
func _gives(g: SaveGame, id: String, when: String) -> void:
	var keys: Array = []
	var sc = WorldData.SCENES.get(id, {}).get(when, [])
	if sc is String:
		keys = [sc]
	else:
		keys = sc
	var seen := {}
	for k in keys:
		var key := String(k)
		while key != "" and not seen.has(key):
			seen[key] = true
			var d: Dictionary = RiverfordStory.scene(key)
			for st in d.get("steps", []):
				match String(st[0]):
					"give_merc": Riverford.add_merc(g)
					"give_lyra": Crucible.unlock_party(g, false)
					"give_ch3": Crucible.unlock_party(g)
					"give_gk": Mountain.recruit(g)
					"give_seraphine": Vespera.recruit(g)
					"give_cassian": FinalArc.recruit_cassian(g)
			key = String(d.get("next", ""))


func play(g: SaveGame, id: String, seed_value: int) -> Dictionary:
	var setup: BattleSetup
	if id == "hallway":
		setup = FirstBattle.hallway_replay()
	elif id == "chamber":
		setup = FirstBattle.chamber_replay()
	else:
		setup = WorldData.setup_for(id, 1, false)
	seed(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var grid := TacticalGrid.from_map(Terrain.load_map(setup.map_path))
	var b := BattleController.new()
	add_child(b)
	b.setup(grid)
	b.rng.seed = seed_value
	CampaignFlow.prepare_deployment(g, b.deployment, setup.max_summons)
	for v in setup.temp_vessels:
		b.deployment.owned_vessels.append(v)
	var king := b.deployment.deploy_king(g.roster.king, setup.king_cell)
	if setup.rules.has("king_hp_pct"):
		king.hp = maxi(1, king.max_hp() * int(setup.rules.king_hp_pct) / 100)
	var cap := g.roster.deployed_co_captain()
	if cap != null and setup.captain_cell != TacticalGrid.NO_CELL:
		b.deployment.deploy_co_captain(cap, setup.captain_cell)
	for r in setup.relics:
		b.deployment.place_relic(r[0], r[1])
	for e in setup.enemies:
		if not setup.fixed_styles:
			EnemyStyles.assign(e[0], rng)
		var bu := b.add_enemy(e[0], e[1])
		if setup.flee.has(e[0].display_name):
			b.fleeing[bu] = int(setup.flee[e[0].display_name])
	b.start()
	var waves: Array = setup.waves.duplicate()
	var acted := {}
	var round := 1
	var turns := 0
	while b.outcome == BattleController.Outcome.ONGOING and turns < 700:
		var bu := b.next_turn()
		if bu == null:
			break
		turns += 1
		if acted.has(bu):
			round += 1
			acted.clear()
		acted[bu] = true
		while not waves.is_empty() and round >= int(waves[0].round):
			bs._wave(b, grid, waves.pop_front(), rng)
		bu.ai_danger_scale = (bs.king_nerve if bu.is_king() else bs.party_nerve) if bu.team == 0 else 1.0
		if bu.team == 0 and bu.is_king() and setup.max_summons > 0:
			bs._summon(b, bu)
		EnemyAI.take_turn(b, bu)
		if b.current == bu:
			b.end_turn()
	var hp := 0.0
	var n := 0
	var downs := 0
	for u in b.deployment.field_units():
		n += 1
		hp += float(maxi(u.hp, 0)) / maxi(u.max_hp(), 1)
		if u.is_down():
			downs += 1
	var won := b.outcome == BattleController.Outcome.WON
	var res := {"won": won, "rounds": round, "downs": downs, "king_down": king.is_down(), "hp_left": hp / maxi(n, 1)}
	b.finish(g.roster)  # XP to the participants on a win, relics home, swords found
	b.queue_free()
	return res


func _levels(g: SaveGame) -> String:
	var parts := PackedStringArray()
	for v in g.roster.vessels():
		parts.append("%s %d" % [v.display_name.left(4), v.stats.level])
	for c in g.roster.co_captains:
		parts.append("%s %d" % [c.display_name.left(4), c.stats.level])
	return ", ".join(parts)


## Every skill learned for good (level 1+) by anyone in the party: [unit, skill, rank, proficiency].
func _skills(g: SaveGame) -> Array:
	var out := []
	var units: Array = [g.roster.king]
	units.append_array(g.roster.vessels())
	units.append_array(g.roster.co_captains)
	for u in units:
		var tree = Mentorship.tree_of(u)
		if tree == null:
			continue
		for m in tree.masteries:
			if m.is_mastered():
				out.append([u.display_name, m.skill.display_name, "EDCBAS"[m.skill.rank], Proficiency.Category.keys()[m.skill.category]])
	return out


func _write(g: SaveGame) -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"battles": log_rows, "skills": _skills(g), "levels": _levels(g), "king_level": g.roster.king.stats.level}, "\t"))
