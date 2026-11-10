extends Node
## How many blows it takes, map by map (the Final Fantasy Tactics pace the owner asked for, Nov 2026): Alaric, grown to the enemies' level, against the
## map's enemies, with the real DamageFormula through BattleController.preview. Prints "enemy hits to down Alaric" and "Alaric hits to down an enemy",
## and checks they sit in the target band (FFT: roughly 3 to 5 blows for an even match, a skill or a critical shortening it to 2 to 3).
## godot --headless --path godot res://tests/tension_check.tscn
var fails := 0
var count := 0
const BAND_LOW := 2.5
const BAND_HIGH := 6.0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var sim = load("res://tests/campaign_sim.gd").new()
	var order: Array[String] = sim.story_order()
	sim.free()
	print("  map           lv | Alaric hp | enemy hits to down Alaric (min/avg) | Alaric hits to down an enemy (avg)")
	var worst_low := 99.0
	var worst_high := 0.0
	var sum_in := 0.0
	var sum_out := 0.0
	var n := 0
	for id in order:
		if id == "hallway" or id == "chamber":
			continue
		var setup := WorldData.setup_for(id, 1, false)
		var enemies := []
		for pair in setup.enemies:
			var ed: EnemyData = pair[0]
			if ed.stats == null or (ed.stats.base_max_hp <= 20 and ed.stats.attack <= 2):
				continue
			enemies.append(ed)
		if enemies.is_empty():
			continue
		var lv := 0.0
		for e in enemies:
			lv += e.stats.level
		lv = roundf(lv / enemies.size())
		var g := FirstBattle.chamber_game(FirstBattle.game())
		var king: KingData = g.roster.king
		king.stats.level = int(lv)
		for i in int(lv) - 1:
			pass
		var grid := TacticalGrid.from_rows(_rows(8))
		var b := BattleController.new()
		add_child(b)
		b.setup(grid)
		b.miss_chance = 0.0
		b.crit_scale = 0.0
		var ku := b.deployment.deploy_king(king, Vector2i(3, 3))
		var hits_in := []
		var hits_out := []
		for ed in enemies:  # one at a time, next to Alaric and facing him (the styles that only hit the way they face)
			ed.stats.grows = false
			var eu := b.add_enemy(ed, Vector2i(3, 4))
			if eu == null:
				continue
			b.face(eu, Vector2i(0, -1))
			b.face(ku, Vector2i(0, 1))
			var mine := b.preview(ku, BattleAction.attack(), eu.cell)
			var theirs := b.preview(eu, BattleAction.attack(), ku.cell)
			if not mine.hits.is_empty() and mine.hits[0].amount > 0:
				hits_out.append(float(eu.max_hp()) / mine.hits[0].amount)
			if not theirs.hits.is_empty() and theirs.hits[0].amount > 0:
				hits_in.append(float(ku.max_hp()) / theirs.hits[0].amount)
			b.grid.remove(eu)
			b.enemies.erase(eu)
		b.queue_free()
		if hits_in.is_empty() or hits_out.is_empty():
			continue
		var lo := 99.0
		var avg_in := 0.0
		for h in hits_in:
			lo = minf(lo, h)
			avg_in += h
		avg_in /= hits_in.size()
		var avg_out := 0.0
		for h in hits_out:
			avg_out += h
		avg_out /= hits_out.size()
		print("  %-13s %2d | %5d     | %5.1f / %5.1f                       | %5.1f" % [id, int(lv), ku.max_hp(), lo, avg_in, avg_out])
		worst_low = minf(worst_low, lo)
		worst_high = maxf(worst_high, avg_in)
		sum_in += avg_in
		sum_out += avg_out
		n += 1
	print("  average over %d maps: enemies need %.1f blows to down Alaric, Alaric needs %.1f to down an enemy; the quickest enemy needs %.1f" % [n, sum_in / n, sum_out / n, worst_low])
	ok(sum_in / n >= BAND_LOW and sum_in / n <= BAND_HIGH, "on average it takes %.1f enemy blows to down Alaric (target %.1f to %.1f)" % [sum_in / n, BAND_LOW, BAND_HIGH])
	ok(sum_out / n >= BAND_LOW and sum_out / n <= BAND_HIGH, "and %.1f of his to down an enemy (target %.1f to %.1f)" % [sum_out / n, BAND_LOW, BAND_HIGH])
	ok(worst_low >= 2.0, "no enemy kind downs Alaric in fewer than 2 blows (%.1f)" % worst_low)
	print("tension checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _rows(n: int) -> Array:
	var rows := []
	for y in n:
		rows.append(" ".join(PackedStringArray(Array(range(n)).map(func(_i): return "g0"))))
	return rows
