extends Node
## Headless checks for EnemyAI: godot --headless --path godot res://tests/ai_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	in_reach()
	priorities()
	friendly_fire()
	walking()
	skills()
	await whole_battles()
	print("ai checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func board(n := 12) -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(n)
	row.fill("g0")
	for y in n:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func style(geo: TacticalMath.Geometry, reach := 1, stance := WeaponStyle.Stance.AXE) -> WeaponStyle:
	var s := WeaponStyle.new()
	s.geometry = geo
	s.reach = reach
	s.stance = stance
	return s


func make(cls, name: String, speed := 6, st: WeaponStyle = null) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.speed = speed
	u.loadout = EquipmentLoadout.make(WeaponItem.new(), st if st else style(TacticalMath.Geometry.KING))
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


## A battle on an open board with the enemy (fast, so it acts first) and the given player units.
func setup(enemy_cell: Vector2i, players: Array, enemy_style: WeaponStyle = null, extra_enemies := []) -> Array:
	var b := BattleController.new()
	add_child(b)
	b.setup(board())
	var units := []
	for p in players:  # [UnitData, cell]
		var bu: BattleUnit
		if p[0] is KingData:
			bu = b.deployment.deploy_king(p[0], p[1])
		elif p[0] is CoCaptainData:
			bu = b.deployment.deploy_co_captain(p[0], p[1])
		units.append(bu)
	var ed := make(EnemyData, "Foe", 30, enemy_style) as EnemyData
	var foe := b.add_enemy(ed, enemy_cell)
	for e in extra_enemies:
		b.add_enemy(make(EnemyData, "Ally", 1) as EnemyData, e)
	b.start()
	var first := b.next_turn()
	ok(first == foe, "the fast enemy acts first")
	return [b, foe, units]


func in_reach() -> void:
	var t := setup(Vector2i(5, 5), [[make(KingData, "King"), Vector2i(5, 6)]])
	var b: BattleController = t[0]
	var foe: BattleUnit = t[1]
	var king: BattleUnit = t[2][0]
	var cell_before := foe.cell
	var p := EnemyAI.plan(b, foe)
	ok(p.acts() and p.action.is_attack(), "attacks a unit in reach")
	eq(p.aim, king.cell, "aims at it")
	eq(foe.cell, cell_before, "planning moves nothing")
	ok(b.grid.occupant(cell_before) == foe and not b.moved and not b.acted, "the board is untouched")
	var hp := king.hp
	EnemyAI.take_turn(b, foe)
	ok(king.hp < hp and b.acted, "take_turn strikes through the BattleController")


func priorities() -> void:
	# two humans side by side: an Axe cleave that hits both beats hitting one
	var t0 := setup(Vector2i(5, 5), [[make(KingData, "King"), Vector2i(5, 6)], [make(CoCaptainData, "Cap"), Vector2i(4, 5)]])
	var p0 := EnemyAI.plan(t0[0], t0[1])
	var both := 0
	var c0: BattleController = t0[0]
	var f0: BattleUnit = t0[1]
	var o0 := f0.cell
	if p0.moves():
		c0.grid.move_occupant(f0, p0.move_to)
		f0.cell = p0.move_to
	both = c0.preview(f0, p0.action, p0.aim).hits.size()
	eq(both, 2, "finds the swing that hits both")
	# two humans on opposite sides, one wounded: finish the wounded one
	var t := setup(Vector2i(5, 5), [[make(KingData, "King"), Vector2i(5, 6)], [make(CoCaptainData, "Cap"), Vector2i(5, 3)]])
	var b: BattleController = t[0]
	var foe: BattleUnit = t[1]
	var king: BattleUnit = t[2][0]
	var cap: BattleUnit = t[2][1]
	cap.hp = 20
	eq(EnemyAI.plan(b, foe).aim, cap.cell, "goes for the wounded unit")
	# a knockout beats more damage elsewhere
	cap.hp = cap.max_hp()
	king.hp = 3
	eq(EnemyAI.plan(b, foe).aim, king.cell, "takes the knockout")
	# a vessel on the field beats a healthy human at the same distance
	king.hp = king.max_hp()
	var relic := RelicItem.new()
	b.deployment.place_relic(relic, Vector2i(6, 5))
	var vd := make(VesselData, "Wisp") as VesselData
	var cur := b.current
	b.current = king  # summon during the King's turn
	var v := b.summon_vessel(king, vd, Vector2i(6, 5))
	b.current = cur
	ok(v != null, "a vessel on the field")
	var pv := EnemyAI.plan(b, foe)
	var o := foe.cell
	if pv.moves():
		b.grid.move_occupant(foe, pv.move_to)
		foe.cell = pv.move_to
	ok(b.preview(foe, pv.action, pv.aim).hit_on(v) != null, "the vessel is among the units it hits")
	if pv.moves():
		b.grid.move_occupant(foe, o)
		foe.cell = o
	# a straight choice between a lone vessel and a lone King at full HP: the vessel
	var lone_v := ActionResult.new()
	var hv := ActionResult.Hit.new()
	hv.target = v
	hv.amount = 9
	lone_v.hits.append(hv)
	var lone_k := ActionResult.new()
	var hk := ActionResult.Hit.new()
	hk.target = king
	hk.amount = 9
	lone_k.hits.append(hk)
	ok(EnemyAI.score_hits(foe, lone_v) > EnemyAI.score_hits(foe, lone_k), "a vessel outweighs the King")
	eq(EnemyAI.pick_target(foe, [king, cap, v] as Array[BattleUnit]), v, "and wants to reach it most")


func friendly_fire() -> void:
	# an Impact (cross burst) enemy with an ally beside the player: it picks the aim that spares the ally
	var t := setup(Vector2i(5, 5), [[make(KingData, "King"), Vector2i(5, 7)]], style(TacticalMath.Geometry.ROOK, 3, WeaponStyle.Stance.IMPACT), [Vector2i(4, 7)])
	var b: BattleController = t[0]
	var foe: BattleUnit = t[1]
	var p := EnemyAI.plan(b, foe)
	ok(p.acts(), "attacks")
	var area := b.preview(foe, p.action, p.aim) if not p.moves() else null
	# score check: whatever it picked does not knock out or hurt its own side more than it gains
	b.grid.move_occupant(foe, p.move_to if p.moves() else foe.cell)
	var origin := foe.cell
	if p.moves():
		foe.cell = p.move_to
	var r := b.preview(foe, p.action, p.aim)
	ok(not r.hits.any(func(h): return h.target.team == foe.team), "no hit on its own side")
	if p.moves():
		b.grid.move_occupant(foe, origin)
		foe.cell = origin
	ok(EnemyAI.score_hits(foe, r) > 0, "a positive plan")


func walking() -> void:
	# a player 4 tiles away: walk next to it and strike in the same turn
	var t := setup(Vector2i(2, 5), [[make(KingData, "King"), Vector2i(6, 5)]])
	var b: BattleController = t[0]
	var foe: BattleUnit = t[1]
	var king: BattleUnit = t[2][0]
	var p := EnemyAI.plan(b, foe)
	ok(p.moves() and p.acts(), "walks and strikes")
	ok(Vector2(p.move_to - king.cell).length() < 1.5, "ends next to the target")
	EnemyAI.take_turn(b, foe)
	ok(b.moved and b.acted and king.hp < king.max_hp(), "done through the BattleController")
	# far away: advance toward it without acting
	t = setup(Vector2i(0, 0), [[make(KingData, "King"), Vector2i(11, 11)]])
	b = t[0]
	foe = t[1]
	king = t[2][0]
	p = EnemyAI.plan(b, foe)
	ok(p.moves() and not p.acts(), "out of reach: only walks")
	eq(p.target, king, "toward the King")
	var before := Vector2(foe.cell - king.cell).length()
	EnemyAI.take_turn(b, foe)
	ok(Vector2(foe.cell - king.cell).length() < before - 2.0, "much closer (%.1f -> %.1f)" % [before, Vector2(foe.cell - king.cell).length()])
	ok(not b.acted, "no action")
	# already moved this turn: it does not plan another walk
	b.end_turn()


func skills() -> void:
	var heal := SkillData.new()
	heal.display_name = "Mend"
	heal.category = Proficiency.Category.HEALING
	heal.sp_cost = 3
	heal.base_power = 10
	var plan_skill := SkillData.new()
	plan_skill.display_name = "Plan"
	plan_skill.category = Proficiency.Category.TACTICAL
	plan_skill.sp_cost = 1
	var blast := SkillData.new()
	blast.display_name = "Blast"
	blast.category = Proficiency.Category.VOID
	blast.sp_cost = 40  # more than anyone has
	blast.base_power = 50
	# a wounded ally next to it and no player in reach: it heals
	var t := setup(Vector2i(5, 5), [[make(KingData, "King"), Vector2i(11, 11)]], null, [Vector2i(5, 6)])
	var b: BattleController = t[0]
	var foe: BattleUnit = t[1]
	(foe.data as EnemyData).skills.append_array([heal, plan_skill, blast])
	var ally: BattleUnit = b.enemies[1]
	ally.hp = 10
	var p := EnemyAI.plan(b, foe)
	ok(p.acts() and p.action.skill == heal and p.aim == ally.cell, "heals the wounded ally")
	ally.hp = ally.max_hp()
	p = EnemyAI.plan(b, foe)
	ok(not p.acts(), "nobody to heal or hit: no action")
	ok(p.action == null or p.action.skill != plan_skill, "never a skill with no effect yet")
	# a player in reach: the free attack, never the unaffordable skill
	t = setup(Vector2i(5, 5), [[make(KingData, "King"), Vector2i(5, 6)]])
	b = t[0]
	foe = t[1]
	(foe.data as EnemyData).skills.append_array([blast, plan_skill])
	p = EnemyAI.plan(b, foe)
	ok(p.acts() and p.action.is_attack(), "cannot afford Blast: attacks")


## Whole battles with EnemyAI playing both sides: legal plans only, and they end.
func whole_battles() -> void:
	for seed in 3:
		var b := BattleController.new()
		add_child(b)
		b.setup(board(10))
		b.rng.seed = seed
		var party := SampleParty.make()
		b.deployment.deploy_king(party.king, Vector2i(1, 1 + seed))
		b.deployment.deploy_co_captain(party.co_captains[0], Vector2i(2, 2))
		for i in 3:
			var e := make(EnemyData, "Grunt %d" % i, 4 + i, style([TacticalMath.Geometry.KING, TacticalMath.Geometry.KNIGHT, TacticalMath.Geometry.BISHOP][i], 2)) as EnemyData
			e.stats.base_max_hp = 40
			b.add_enemy(e, Vector2i(8, 5 + i - seed % 2))
		b.start()
		var turns := 0
		var illegal := 0
		while b.outcome == BattleController.Outcome.ONGOING and turns < 400:
			var u := b.next_turn()
			if u == null:
				break
			turns += 1
			var p := EnemyAI.plan(b, u)
			if p.moves() and not b.move(u, p.move_to):
				illegal += 1
			if p.acts() and not b.perform(u, p.action, p.aim).ok:
				illegal += 1
			b.end_turn()
		eq(illegal, 0, "battle %d: every planned move and action was legal" % seed)
		ok(b.outcome != BattleController.Outcome.ONGOING, "battle %d ends (%d turns, %s)" % [seed, turns, BattleController.Outcome.keys()[b.outcome]])
		b.queue_free()
	await get_tree().process_frame
