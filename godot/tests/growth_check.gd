extends Node
## Headless: the level-up system (owner, Nov 2026: "levels everything up like a normal tactics game"). The party grows on every level
## (CharacterStats.GROWTH); enemies keep the stats written for their level and get tougher chapter by chapter; at each story battle's enemy level
## Alaric stays in a fair band against that battle's enemies. Prints the table.
## godot --headless --path godot res://tests/growth_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _ready() -> void:
	party()
	versus()
	print("growth checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func party() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var king := g.roster.king
	var s := king.stats
	var at1 := {}
	for st in CharacterStats.GROWN:
		at1[st] = s.final_stat(st, king.loadout)
	var ups := s.add_exp(ExperienceCurve.total_to_reach(20) - s.total_exp, king.loadout)
	eq_ok(s.level, 20, "Alaric reaches level 20")
	for st in CharacterStats.GROWN:
		ok(s.final_stat(st, king.loadout) > at1[st] or at1[st] == 0, "Alaric's %s grows from level 1 to 20 (%d -> %d)" % [StatModifier.stat_name(st), at1[st], s.final_stat(st, king.loadout)])
	ok(s.final_stat(StatModifier.Stat.MOVE, king.loadout) == s.move and s.final_stat(StatModifier.Stat.JUMP, king.loadout) == s.jump, "Move and Jump do not grow")
	ok(ups.size() == 19 and ups.any(func(u): return u.gains.has(StatModifier.Stat.ATTACK)), "level-ups report the stats they raised")
	print("  ", ups[ups.size() - 1].describe())
	# every party member grows, and its strengths grow fastest
	for v in g.roster.vessels():
		var a1 := v.stats.final_stat(StatModifier.Stat.ATTACK, v.loadout)
		v.stats.add_exp(ExperienceCurve.total_to_reach(30) - v.stats.total_exp, v.loadout)
		ok(v.stats.final_stat(StatModifier.Stat.ATTACK, v.loadout) > a1, "%s grows" % v.display_name)
	var e := EnemyData.new()
	e.stats = CharacterStats.new()
	e.stats.attack = 10
	e.stats.level = 30
	e.stats.grows = false
	ok(e.stats.final_stat(StatModifier.Stat.ATTACK) == 10, "an enemy's attack is the one written for its level")
	var sv := SaveCodec.decode(SaveCodec.encode(g))
	ok(sv.game.roster.king.stats.final_stat(StatModifier.Stat.ATTACK, sv.game.roster.king.loadout) == s.final_stat(StatModifier.Stat.ATTACK, king.loadout), "growth survives a save and a load")


func eq_ok(a, b, what: String) -> void:
	ok(a == b, "%s (%s vs %s)" % [what, a, b])


## Each story battle's enemies against Alaric at their level.
func versus() -> void:
	var sim = load("res://tests/campaign_sim.gd").new()
	var order: Array[String] = sim.story_order()
	sim.free()
	var prev_atk := 0.0
	var rows := []
	var first_atk := 0.0
	print("  map           lv | enemy atk def  mag  hp  | Alaric atk def hp | Alaric hit / enemy hit")
	for id in order:
		if id == "hallway" or id == "chamber":
			continue
		var setup := WorldData.setup_for(id, 1, false)
		var n := 0
		var lv := 0.0
		var atk := 0.0
		var dfn := 0.0
		var mag := 0.0
		var hp := 0.0
		for pair in setup.enemies:
			var ed: EnemyData = pair[0]
			if ed.stats == null or ed.stats.base_max_hp <= 20 and ed.stats.attack <= 2:
				continue  # devices, standards and memorials
			ed.stats.grows = false
			n += 1
			lv += ed.stats.level
			atk += maxf(ed.stats.final_stat(StatModifier.Stat.ATTACK), ed.stats.final_stat(StatModifier.Stat.MAGIC))
			dfn += ed.stats.final_stat(StatModifier.Stat.DEFENSE)
			mag += ed.stats.final_stat(StatModifier.Stat.MAGIC)
			hp += ed.stats.max_hp()
		if n == 0:
			continue
		lv /= n
		atk /= n
		dfn /= n
		mag /= n
		hp /= n
		var k := CharacterStats.new()
		k.base_max_hp = 70
		k.attack = 6
		k.defense = 5
		k.level = roundi(lv)
		var ka := k.final_stat(StatModifier.Stat.ATTACK)
		var kd := k.final_stat(StatModifier.Stat.DEFENSE)
		var mine := maxf(1.0, ka * 1.5 - dfn * 0.5)  # rough: a rank-C physical hit against their defense
		var theirs := maxf(1.0, atk * 1.5 - kd * 0.5)
		print("  %-13s %2d | %5.1f %5.1f %4.1f %5.0f | %4d %3d %4d | %5.1f / %5.1f" % [id, roundi(lv), atk, dfn, mag, hp, ka, kd, k.max_hp(), mine, theirs])
		if first_atk == 0.0:
			first_atk = atk
		rows.append([atk, dfn, Crucible.chapter_of(String((setup.enemies[0][0] as EnemyData).id))])
		prev_atk = maxf(prev_atk, atk)
		ok(ka >= dfn * 0.5, "%s: Alaric at the enemies' level can still hurt them (attack %d vs defense %.0f)" % [id, ka, dfn])
		ok(kd >= atk * 0.3, "%s: and is not helpless against them (defense %d vs their attack %.0f)" % [id, kd, atk])
	# chapter by chapter (Crucible.chapter_of) the enemies' average attack and defense never drop more than 10%
	var by := {}
	for r in rows:
		if not by.has(r[2]):
			by[r[2]] = []
		by[r[2]].append(r)
	var chs := by.keys()
	chs.sort()
	var last := Vector2.ZERO
	for c in chs:
		var sum := Vector2.ZERO
		for r in by[c]:
			sum += Vector2(r[0], r[1])
		var avg: Vector2 = sum / by[c].size()
		print("  chapter %2d: enemy attack %.1f, defense %.1f" % [c, avg.x, avg.y])
		ok(avg.x >= last.x * 0.9 and avg.y >= last.y * 0.9, "chapter %d: enemies are as tough as the chapter before (attack %.1f, defense %.1f; before %.1f, %.1f)" % [c, avg.x, avg.y, last.x, last.y])
		last = Vector2(maxf(last.x, avg.x), maxf(last.y, avg.y))
	ok(prev_atk > first_atk * 2.0, "enemies grow over the campaign (%.0f -> %.0f)" % [first_atk, prev_atk])
