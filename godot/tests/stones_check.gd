extends Node
## Headless: which ranks the summon stones carry as the story goes on (owner, Nov 2026): rank B from chapter seven, rank A from chapter nine, rank S a rare variety from chapter ten, every
## rank E to S in rotation by chapter eleven; every skill a stone carries is physical and the stones never carry a rank the chapter has not reached.
## godot --headless --path godot res://tests/stones_check.tscn
var fails := 0
var count := 0
const N := 3000


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	placement()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# [name, d, c, b, a, s]
	var chapters := [
		["five", Bellwether.STONE_D_CHANCE, Bellwether.STONE_C_CHANCE, 0.0, 0.0, 0.0],
		["six", Expanse.STONE_D_CHANCE, Expanse.STONE_C_CHANCE, 0.0, 0.0, 0.0],
		["seven", Vespera.STONE_D_CHANCE, Vespera.STONE_C_CHANCE, Vespera.STONE_B_CHANCE, 0.0, 0.0],
		["eight", Crown.STONE_D_CHANCE, Crown.STONE_C_CHANCE, Crown.STONE_B_CHANCE, 0.0, 0.0],
		["nine", Finale.STONE_D_CHANCE, Finale.STONE_C_CHANCE, Finale.STONE_B_CHANCE, Finale.STONE_A_CHANCE, 0.0],
		["ten", Ashes.STONE_D_CHANCE, Ashes.STONE_C_CHANCE, Ashes.STONE_B_CHANCE, Ashes.STONE_A_CHANCE, Ashes.STONE_S_CHANCE],
		["eleven", Falcon.STONE_D_CHANCE, Falcon.STONE_C_CHANCE, Falcon.STONE_B_CHANCE, Falcon.STONE_A_CHANCE, Falcon.STONE_S_CHANCE],
	]
	var seen := {}
	var cats := {}
	for ch in chapters:
		var counts := {}
		for i in N:
			var sk := SummonStone.make(rng, ch[1], ch[2], ch[3], ch[4], ch[5]).skill
			cats[sk.category] = true
			counts[sk.rank] = int(counts.get(sk.rank, 0)) + 1
		seen[ch[0]] = counts
	var R = SkillData.Rank
	ok(not seen.six.has(R.B) and not seen.six.has(R.A) and not seen.six.has(R.S), "chapters five and six: no rank B, A or S stones")
	ok(seen.seven.get(R.B, 0) > N / 10 and not seen.seven.has(R.A) and not seen.seven.has(R.S), "chapter seven: rank B stones begin, nothing above")
	ok(seen.eight.get(R.B, 0) > N / 8 and not seen.eight.has(R.A), "chapter eight: rank B stones, still no rank A")
	ok(seen.nine.get(R.A, 0) > N / 20 and seen.nine.get(R.B, 0) > N / 6 and not seen.nine.has(R.S), "chapter nine: rank A stones begin, still no rank S")
	ok(seen.ten.get(R.S, 0) > 0 and seen.ten.get(R.S, 0) < N / 10, "chapter ten: rank S is a rare variety (%d of %d)" % [seen.ten.get(R.S, 0), N])
	for r in [R.E, R.D, R.C, R.B, R.A, R.S]:
		ok(seen.eleven.get(r, 0) > 0, "chapter eleven: rank %d is in rotation" % r)
	ok(seen.eleven.get(R.S, 0) >= seen.ten.get(R.S, 0) * 0.5, "rank S stays rare but present from chapter eleven on")
	ok(cats.size() == 6, "ranked stones come from all six proficiencies (%d seen)" % cats.size())
	# the chances never add up to more than one, and rank E is always left over
	for ch in chapters:
		ok(ch[1] + ch[2] + ch[3] + ch[4] + ch[5] < 1.0, "%s: rank E stones remain" % ch[0])
	# the battles really use them: a chapter eleven battle's stones can carry the higher ranks
	var ranks := {}
	for i in 60:
		for st in Falcon.setup(1).relics:
			ranks[st[0].skill.rank] = true
	ok(ranks.size() >= 3, "a chapter eleven battle's stones carry a spread of ranks (%d distinct in 60 battles)" % ranks.size())
	# every rank B, A and S physical skill can actually be used in a battle
	var grid := TacticalGrid.from_map(Terrain.load_map(Falcon.MAPS[5]))
	for sk in SkillLibrary.all():
		if sk.rank < SkillData.Rank.B:
			continue
		var b := BattleController.new()
		add_child(b)
		b.setup(grid.duplicate() if grid.has_method("duplicate") else TacticalGrid.from_map(Terrain.load_map(Falcon.MAPS[5])))
		b.miss_chance = 0.0
		b.crit_scale = 0.0  # exact damage: no random critical hits
		var kd := FirstBattle.game().roster.king.duplicate(true) as KingData
		b.deployment.deploy_king(kd, Vector2i(1, 1))
		var k: Dictionary = Falcon.KINDS.fsword.duplicate()
		k.skills = [sk.display_name]
		k.boss = true
		var foe := b.add_enemy(Crucible.build(k, &"stone_rank_test", 40, {}), Vector2i(1, 2))
		var mate := b.add_enemy(Crucible.build(Falcon.KINDS.fsword, &"stone_rank_mate", 40, {}), Vector2i(2, 2))
		mate.hp = mate.max_hp() / 2  # a hurt ally for the heals and boons to land on
		foe.facing = Vector2i(0, -1)
		b.start()
		b.current = foe
		b.moved = false
		b.acted = false
		var act := BattleAction.use(sk)
		var aims := b.highlights(foe, act)
		var used := false
		for aim in aims:  # a support skill needs a target in its area: try each aimed tile
			if b.perform(foe, act, aim).ok:
				used = true
				break
		ok(used, "%s (rank %d, %s) can be used in a battle" % [sk.display_name, sk.rank, Proficiency.Category.keys()[sk.category]])
		b.queue_free()
	# enemies use every proficiency too: across the chapters' foes all six appear, and every kind uses at least three
	var used := {}
	for mod in [[Crucible, 3], [Mountain, 3], [Bellwether, 3], [Expanse, 3], [Vespera, 3], [Crown, 3], [Finale, 3], [Ashes, 3], [Falcon, 3]]:
		for kind in mod[0].KINDS:
			if String(mod[0].KINDS[kind].get("behavior", "")) != "":
				continue
			var e: EnemyData = mod[0].enemy(kind, mod[1], 1)
			var cs := {}
			for sk in e.skills:
				cs[sk.category] = true
				used[sk.category] = true
			ok(cs.size() >= 3, "%s uses %d proficiencies" % [e.display_name, cs.size()])
			ok(e.skills.all(func(sk): return sk.rank <= Crucible.enemy_top_rank(Crucible.chapter_of(String(e.id)), mod[0].KINDS[kind].get("boss", false)) or sk.rank <= int(mod[0].KINDS[kind].get("rank_cap", 0)) or mod[0].KINDS[kind].get("boss", false) and sk.rank <= SkillData.Rank.A), "%s stays within its chapter's ranks" % e.display_name)
			var ch := Crucible.chapter_of(String(e.id))
			if ch >= 7:
				ok(e.skills.any(func(sk): return sk.rank == SkillData.Rank.B), "%s (chapter %d) carries a rank B skill like the player's stones" % [e.display_name, ch])
	ok(used.size() == 6, "the enemies use all six proficiencies (%d)" % used.size())
	# bosses one rank up: a chapter nine boss may reach S, a chapter seven boss A, never more
	for pair in [[Vespera, 7], [Finale, 9], [Falcon, 11]]:
		for kind in pair[0].KINDS:
			if pair[0].KINDS[kind].get("boss", false):
				var be: EnemyData = pair[0].enemy(kind, 5, 1)
				ok(be.skills.any(func(sk): return sk.rank == Crucible.enemy_top_rank(pair[1], true)), "%s (chapter %d boss) carries a skill one rank above the player's best" % [be.display_name, pair[1]])
	# a new vessel joins one level below Alaric, with grown stats
	var g := FirstBattle.chamber_game(FirstBattle.game())
	g.roster.king.stats.add_exp(ExperienceCurve.total_to_reach(9) - g.roster.king.stats.total_exp)
	var hp1 := Riverford.merc().stats.max_hp()
	Riverford.add_merc(g)
	var merc: VesselData = g.roster.vessels().filter(func(v): return v.display_name == "Merc").front()
	ok(g.roster.king.stats.level == 9 and merc.stats.level == 8, "Merc joins at level 8 when Alaric is 9 (%d, %d)" % [g.roster.king.stats.level, merc.stats.level])
	ok(merc.stats.max_hp() > hp1, "...with the stats of a level 8 vessel")
	Mountain.recruit(g)
	ok(g.roster.vessels().filter(func(v): return v.display_name in ["Gideon", "Kaelen"]).all(func(v): return v.stats.level == 8), "Gideon and Kaelen too")
	print("stones checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


## Stones lie where they add strategy (StonePlacement): two on the edge of Alaric's summon range, two out in the field on the flanks, and a prize
## stone deep on the enemy's side with the best rank on the map. None next to him, none an enemy can pounce on the first turn.
func placement() -> void:
	var sim = load("res://tests/campaign_sim.gd").new()
	var order: Array[String] = sim.story_order()
	sim.free()
	var maps := 0
	var deep := 0
	var fields_out := 0
	for id in order:
		var st := WorldData.setup_for(id, 1, false)
		if st == null or st.relics.is_empty() or id == "hallway" or id == "chamber":
			continue
		maps += 1
		var grid := TacticalGrid.from_map(Terrain.load_map(st.map_path))
		var r := DeploymentManager.SUMMON_RANGE_SHARE * maxi(grid.width, grid.depth)
		eq(st.relics.size(), StonePlacement.REACH + StonePlacement.FIELD + StonePlacement.PRIZE, "%s: five stones" % id)
		var seen := {}
		var skills := {}
		var kinds := {"reach": 0, "field": 0, "prize": 0}
		var top := SkillData.Rank.E
		for p in st.relics:
			top = maxi(top, p[0].skill.rank)
		for p in st.relics:
			var relic: RelicItem = p[0]
			var c: Vector2i = p[1]
			var d := Vector2(c - st.king_cell).length()
			var gap := 999
			for e in st.enemies:
				gap = mini(gap, absi(e[1].x - c.x) + absi(e[1].y - c.y))
			var kind := StonePlacement.kind_of(relic)
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			ok(grid.can_stand(c) and not seen.has(c), "%s: a stone at %s stands on open ground, one per tile" % [id, c])
			seen[c] = true
			ok(d >= r - StonePlacement.BAND - 0.001, "%s: no stone next to Alaric (%.1f tiles, range %.1f)" % [id, d, r])
			ok(gap >= StonePlacement.PRIZE_GAP, "%s: no stone right beside an enemy's start (%d steps)" % [id, gap])
			ok(gap > StonePlacement.SAFE_GAP or d > r + StonePlacement.KING_STEP, "%s: a stone Alaric can use on the first turn is out of the enemy's first-turn reach (%s: %d steps, %.1f tiles)" % [id, c, gap, d])
			if kind == "reach":
				ok(d <= r + 0.001, "%s: a reach stone is inside the summon range (%.1f, range %.1f)" % [id, d, r])
			elif kind == "field" and d > r + 0.001:
				fields_out += 1
			elif kind == "prize":
				eq(relic.skill.rank, top, "%s: the prize stone carries the best rank on the map" % id)
				if d > r + StonePlacement.KING_STEP:
					deep += 1
			skills[relic.skill] = true
		eq(kinds.reach, StonePlacement.REACH, "%s: two stones within reach" % id)
		eq(kinds.prize, StonePlacement.PRIZE, "%s: one prize stone" % id)
		ok(skills.size() >= st.relics.size() - 1, "%s: the stones carry different skills (%d of %d)" % [id, skills.size(), st.relics.size()])
		var again := WorldData.setup_for(id, 1, false)
		ok(range(st.relics.size()).all(func(i): return again.relics[i][1] == st.relics[i][1]), "%s: the layout is the same every time" % id)
	print("  stones: %d maps, %d with the prize beyond first-turn range, %d field stones beyond the starting range" % [maps, deep, fields_out])
	ok(deep * 10 >= maps * 8, "on most maps the prize stone cannot be used on the first turn (%d of %d)" % [deep, maps])
	ok(fields_out >= maps, "the field stones mostly lie beyond the starting range (%d on %d maps)" % [fields_out, maps])
