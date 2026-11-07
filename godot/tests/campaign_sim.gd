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
var debug := false
var boost := 0


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
				"debug": debug = true
				"boost": boost = kv[1].to_int()
	bs = load("res://tests/balance_sim.gd").new()
	bs.early_summon = true
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
		if boost > 0:
			for v in [g.roster.king] + g.roster.vessels():
				if v.stats.level < boost:
					v.stats.add_exp(ExperienceCurve.total_to_reach(boost) - v.stats.total_exp, v.loadout)
		_prepare(g)
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
				var back: String = cleared[maxi(0, cleared.size() - 1 - (k % 3))]
				var gr := play(g, back, seed0 * 7919 + i * 31 + tries * 5 + k)
				grinds += 1
		if res.won:
			cleared.append(id)  # only a won map can be replayed for experience
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


## What a player does in the barracks between battles: every relic goes onto a vessel (relics carrying a human's study first, then skills
## nobody has learned, higher rank first), and Alaric and each Co-Captain study a new skill from the vessels' relics once the last one is learned.
func _prepare(g: SaveGame) -> void:
	var r := g.roster
	var vessels := r.vessels()
	for v in vessels:
		for slot in [EquipmentLoadout.Slot.RELIC_SLOT_1, EquipmentLoadout.Slot.RELIC_SLOT_2]:
			RosterManager.equip_relic(r, v, slot, null)
	var humans := r.humans()
	var studying := {}
	for h in humans:
		var act := Mentorship.tree_of(h).active_study()
		if act != null and not act.is_mastered():
			studying[act.skill] = true
	var learned_by_all := func(sk: SkillData) -> bool:
		for h in humans:
			if not Mentorship.tree_of(h).is_learned(sk):
				return false
		return true
	var relics: Array = r.relic_inventory.filter(func(x): return x.skill != null)
	relics.sort_custom(func(x, y):
		var kx := (2000 if studying.has(x.skill) else 0) + (0 if learned_by_all.call(x.skill) else 1000) + int(x.skill.rank)
		var ky := (2000 if studying.has(y.skill) else 0) + (0 if learned_by_all.call(y.skill) else 1000) + int(y.skill.rank)
		return kx > ky)
	var i := 0
	for slot in [EquipmentLoadout.Slot.RELIC_SLOT_1, EquipmentLoadout.Slot.RELIC_SLOT_2]:
		for v in vessels:
			while i < relics.size() and not v.loadout.can_equip(slot, relics[i]):
				i += 1
			if i >= relics.size():
				break
			RosterManager.equip_relic(r, v, slot, relics[i])
			i += 1
	for h in humans:
		var act := Mentorship.tree_of(h).active_study()
		if act != null and not act.is_mastered():
			continue
		var best: SkillData = null
		var from: VesselData = null
		for v in vessels:
			for o in Mentorship.offers(v):
				var st := Mentorship.status(h, o.skill)
				if (st == Mentorship.Status.AVAILABLE or st == Mentorship.Status.PAUSED) and (best == null or o.skill.rank > best.rank):
					best = o.skill
					from = v
		if best != null:
			Mentorship.start_study(h, from, best)


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
	if debug:
		var ff := {}
		print("DEBUG %s won=%s rounds=%d" % [id, won, round])
		for u in b.summary.lines:
			print("   ", b.summary.describe(u), " | lv ", u.data.stats.level, " hp ", u.max_hp(), " team ", u.team, " turns ", b.summary.lines[u].turns, " atk ", u.stat(StatModifier.Stat.ATTACK), " def ", u.stat(StatModifier.Stat.DEFENSE), " mag ", u.stat(StatModifier.Stat.MAGIC), " res ", u.stat(StatModifier.Stat.RESISTANCE), " uses ", b.summary.lines[u].skill_uses.values())
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
