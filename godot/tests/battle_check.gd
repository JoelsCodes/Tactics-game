extends Node
## Headless checks for the combat loop (scripts/battle): godot --headless --path godot res://tests/battle_check.tscn

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
	turn_order()
	sp_and_actions()
	targeting_and_damage()
	vessels_in_battle()
	losing()
	full_battle()
	print("battle checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func board(n := 12) -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(n)
	row.fill("g0")
	for y in n:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func style(geo: TacticalMath.Geometry, reach := 2, stance := WeaponStyle.Stance.IMPACT) -> WeaponStyle:
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
	var w := WeaponItem.new()
	w.base_power = 8
	u.loadout = EquipmentLoadout.make(w, st if st else style(TacticalMath.Geometry.ROOK))
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


func skill(name: String, cat: Proficiency.Category, sp: int, power: int) -> SkillData:
	var s := SkillData.new()
	s.display_name = name
	s.category = cat
	s.sp_cost = sp
	s.base_power = power
	return s


func battle(g: TacticalGrid) -> BattleController:
	var b := BattleController.new()
	add_child(b)
	b.setup(g)
	return b


func turn_order() -> void:
	var b := battle(board())
	var king := b.deployment.deploy_king(make(KingData, "King", 10) as KingData, Vector2i(1, 1))
	var cap := b.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 5) as CoCaptainData, Vector2i(2, 1))
	var foe := b.add_enemy(make(EnemyData, "Foe", 10) as EnemyData, Vector2i(8, 8))
	ok(b.next_turn() == null, "no turns before start")
	ok(b.start(), "start with a King")
	eq(TurnManager.group_of(king), TurnManager.Group.LEADER, "King is a leader")
	eq(TurnManager.group_of(cap), TurnManager.Group.LEADER, "Co-Captain is a leader")
	eq(TurnManager.group_of(foe), TurnManager.Group.ENEMY, "enemy group")
	var order := b.turns.upcoming(6)
	eq(order.slice(0, 3), [king, foe, king], "speed 10 goes twice as often as 5; leaders win ties")
	ok(order.count(cap) >= 1, "slower unit still gets turns")
	ok(b.next_turn() == king, "King first")
	b.end_turn()  # waited: costs 60 only
	eq(king.ct, 40, "waiting costs 60 CT")
	ok(b.next_turn() == foe, "then the enemy")
	b.move(foe, Vector2i(8, 7))
	b.end_turn()
	eq(foe.ct, 20, "moving only costs 80")
	ok(b.next_turn() == king, "waiting brought the King back sooner")
	b.end_turn()
	foe.hp = 0
	ok(not b.turns.upcoming(10).has(foe), "knocked-out units get no turns")


func sp_and_actions() -> void:
	var b := battle(board())
	var kd := make(KingData, "King") as KingData
	var bolt := skill("Bolt", Proficiency.Category.ELEMENTAL, 4, 6)
	kd.skill_tree.start_study(bolt)
	var king := b.deployment.deploy_king(kd, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe", 1) as EnemyData, Vector2i(5, 7))
	b.start()
	b.next_turn()
	eq(king.sp, 9, "SP pool from stats")
	var acts := b.actions(king)
	eq(acts.size(), 2, "attack + studied skill")
	ok(acts[0].is_attack() and acts[0].sp_cost() == 0, "attacks are free")
	var cast := acts[1]
	eq(cast.sp_cost(), 4, "skill costs its SP")
	for s in WeaponStyle.Stance.values():
		b.set_stance(king, s)
		eq(cast.sp_cost(), 4, "stance %d does not change SP" % s)
	var r := b.perform(king, cast, Vector2i(5, 7))
	ok(r.ok and r.sp_spent == 4, "cast")
	eq(king.sp, 5, "SP spent")
	eq(b.perform(king, BattleAction.attack(), Vector2i(5, 7)).error, "already acted this turn", "one action per turn")
	b.end_turn()
	for i in 2:
		while b.next_turn() != king:
			b.end_turn()
		ok(b.perform(king, cast, Vector2i(5, 7)).ok or i == 1, "second cast")
		b.end_turn()
	eq(king.sp, 1, "no SP refill")
	while b.next_turn() != king:
		b.end_turn()
	eq(b.action_error(king, cast, Vector2i(5, 7)), "not enough SP", "cannot cast without SP")
	ok(b.perform(king, BattleAction.attack(), Vector2i(5, 7)).ok, "can still attack")
	var pr := kd.skill_tree.mastery_of(bolt).progress
	ok(pr >= 14 and pr <= 20, "two casts at C: 14-20 points toward level 1 (got %d)" % pr)
	ok(foe.hp < foe.max_hp(), "foe took damage")


func targeting_and_damage() -> void:
	var b := battle(board())
	var king := b.deployment.deploy_king(make(KingData, "King", 10, style(TacticalMath.Geometry.ROOK, 2)) as KingData, Vector2i(5, 5))
	var near := b.add_enemy(make(EnemyData, "Near", 1) as EnemyData, Vector2i(5, 3))
	var behind := b.add_enemy(make(EnemyData, "Behind", 1) as EnemyData, Vector2i(5, 2))
	var side := b.add_enemy(make(EnemyData, "Side", 1) as EnemyData, Vector2i(6, 3))
	b.start()
	b.next_turn()
	var atk := BattleAction.attack()
	# Impact: reach 2 - 1 = 1, cross splash
	b.set_stance(king, WeaponStyle.Stance.IMPACT)
	eq(b.highlights(king, atk).size(), 4, "impact rook reach 1")
	ok(not b.highlights(king, atk).has(Vector2i(5, 3)), "near foe out of reach in impact")
	# Pierce: reach 3, hits 1 behind
	b.set_stance(king, WeaponStyle.Stance.PIERCE)
	var hl := b.highlights(king, atk)
	ok(hl.has(Vector2i(5, 3)) and not hl.has(Vector2i(5, 2)), "pierce reaches the first foe, line stops there")
	eq(hl.size(), 3 + 3 + 3 + 2, "pierce rook reach 3 (one ray blocked at the foe)")
	var p := b.preview(king, atk, Vector2i(5, 3))
	# physical: weapon 8 + atk 6 - def 5 = 9; pierce 90% aimed -> 8, 75% behind -> 7
	eq(p.hit_on(near).amount, 8, "aimed tile 90%")
	eq(p.hit_on(behind).amount, 7, "pierced tile 75%")
	ok(p.hit_on(side) == null, "side not hit in pierce")
	# Axe: reach 2, cleaves sideways
	b.set_stance(king, WeaponStyle.Stance.AXE)
	p = b.preview(king, atk, Vector2i(5, 3))
	eq(p.hit_on(near).amount, 10, "axe 110%")
	eq(p.hit_on(side).amount, 5, "cleave 50% of 9, rounded")
	eq(p.sp_spent, 0, "attack costs no SP in any stance")
	var r := b.perform(king, atk, Vector2i(5, 3))
	eq(near.hp, near.max_hp() - 10, "damage applied")
	eq(side.hp, side.max_hp() - 5, "splash applied")
	eq(king.facing, Vector2i(0, -1), "faces the target")
	eq(b.action_error(king, atk, Vector2i(0, 0)), "already acted this turn", "acted")
	# other proficiencies: bare footprint, no stance damage
	var heal := skill("Mend", Proficiency.Category.HEALING, 3, 6)
	var voidb := skill("Unmake", Proficiency.Category.VOID, 6, 5)
	var ele := skill("Bolt", Proficiency.Category.ELEMENTAL, 4, 6)
	var tac := skill("Plan", Proficiency.Category.TACTICAL, 2, 0)
	eq(b.footprint(king, BattleAction.use(heal)).splash, GeometryPattern.Splash.NONE, "heal ignores stance")
	eq(b.footprint(king, BattleAction.use(heal)).reach, 2, "heal uses bare reach")
	eq(b.preview(king, BattleAction.use(ele), Vector2i(5, 3)).hit_on(near).amount, 6, "elemental: 6 + mag 5 - res 5")
	eq(b.preview(king, BattleAction.use(voidb), Vector2i(5, 3)).hit_on(near).amount, 10, "void ignores resistance")
	eq(b.preview(king, BattleAction.use(heal), Vector2i(5, 3)).hit_on(near).amount, 8, "heal: 6 + mag 5 / 2")
	ok(b.preview(king, BattleAction.use(heal), Vector2i(5, 3)).hit_on(near).heal, "heal flag")
	eq(b.preview(king, BattleAction.use(tac), Vector2i(5, 3)).hits.size(), 0, "tactical: no HP change yet")
	# knock out and win
	b.end_turn()
	while b.next_turn() != king:
		b.end_turn()
	for e in [near, behind, side]:
		e.hp = 1
	b.set_stance(king, WeaponStyle.Stance.IMPACT)
	b.move(king, Vector2i(5, 4))
	var ko := []
	b.unit_knocked_out.connect(func(u): ko.append(u))
	r = b.perform(king, atk, Vector2i(5, 3))
	ok(r.hit_on(near).knocked_out and near.is_down() and near.hp == 0, "knocked out at 0, never below")
	eq(ko.size(), 3, "cross burst hit all three foes")
	eq(b.outcome, BattleController.Outcome.WON, "every enemy down: won")
	ok(not GeometryResolver.targetable(b.grid, king.cell, b.footprint(king, atk)).is_empty(), "highlights still work")


func vessels_in_battle() -> void:
	var b := battle(board())
	b.deployment.rng.seed = 3
	var kd := make(KingData, "King", 10) as KingData
	var king := b.deployment.deploy_king(kd, Vector2i(5, 5))
	b.add_enemy(make(EnemyData, "Foe", 1) as EnemyData, Vector2i(0, 11))
	var relic := RelicItem.new()
	relic.display_name = "Banner"
	relic.skill = skill("Rally", Proficiency.Category.TACTICAL, 2, 0)
	relic.sp_drain_per_turn = 1
	b.deployment.place_relic(relic, Vector2i(6, 5))
	b.start()
	var vd := make(VesselData, "Wisp", 8) as VesselData
	vd.fade_turns = 2
	ok(b.next_turn() == king, "King's turn")
	ok(b.summon_vessel(king, vd, Vector2i(6, 5)) != null, "King summons onto the relic")
	ok(not b.acted and not b.moved, "summoning is free: the King keeps his move and action")
	eq(vd.tether_count, 1, "tether count +1")
	var v := b.deployment.unit_of(vd)
	ok(b.turns.units.has(v), "vessel joins the turn order")
	eq(TurnManager.group_of(v), TurnManager.Group.VESSEL, "vessel group")
	ok(b.skills_of(v).has(relic.skill), "Temp-Relic skill usable by the vessel")
	b.end_turn()
	while b.next_turn() != v:
		b.end_turn()
	eq(v.sp, v.max_sp() - 1, "relic SP drain at turn start")
	b.move(v, Vector2i(7, 5))
	b.end_turn()
	eq(v.fade_clock.turns_left, 1, "fade clock -1 at the end of its turn")
	while b.next_turn() != v:
		b.end_turn()
	v.hp = 0
	b.end_turn()  # its own turn should not even come while down; force-check pause
	eq(v.fade_clock.turns_left, 1, "knocked out: clock paused")
	v.hp = 5
	while b.next_turn() != v:
		b.end_turn()
	b.end_turn()
	ok(not v.on_field and not b.turns.units.has(v), "untethered at 0, out of the turn order")
	eq(vd.sever_count, 1, "sever count +1")
	var home := b.deployment.secured.has(relic)
	ok(home or b.deployment.prop_at(Vector2i(7, 5)).relic == relic, "relic home (25%) or dropped on its tile")
	eq(b.deployment.summon_error(vd, Vector2i(7, 5)) if not home else "removed this battle", "removed this battle", "no re-summon this battle")


## Lose only when every player unit on the field is down; a downed King just cannot summon.
func losing() -> void:
	var b := battle(board())
	var king := b.deployment.deploy_king(make(KingData, "King", 1) as KingData, Vector2i(5, 5))
	var cap := b.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 1) as CoCaptainData, Vector2i(5, 7))
	var foe := b.add_enemy(make(EnemyData, "Foe", 20, style(TacticalMath.Geometry.QUEEN, 3)) as EnemyData, Vector2i(5, 3))
	b.deployment.place_relic(RelicItem.new(), Vector2i(4, 5))
	b.start()
	king.hp = 1
	ok(b.next_turn() == foe, "fast foe first")
	ok(b.perform(foe, BattleAction.attack(), Vector2i(5, 5)).hit_on(king).knocked_out, "King knocked out")
	eq(b.outcome, BattleController.Outcome.ONGOING, "King down is not a loss while others stand")
	eq(b.deployment.summon_error(VesselData.new(), Vector2i(4, 5)), "the King must be on the field to summon", "a downed King cannot summon")
	b.end_turn()
	var lost := []
	b.battle_ended.connect(func(o): lost.append(o))
	cap.hp = 1
	while b.next_turn() != foe:
		b.end_turn()
	ok(not b.move_range(foe).can_reach(Vector2i(5, 5)), "cannot stop on the King's body")
	ok(b.move(foe, Vector2i(5, 6)), "walks through the King's body")
	ok(b.perform(foe, BattleAction.attack(), Vector2i(5, 7)).hit_on(cap).knocked_out, "Co-Captain knocked out")
	eq(b.outcome, BattleController.Outcome.LOST, "everyone on the field down: lost")
	eq(lost, [BattleController.Outcome.LOST], "battle_ended(LOST)")


func full_battle() -> void:
	var b := battle(board(8))
	var kd := make(KingData, "King", 8, style(TacticalMath.Geometry.QUEEN, 3, WeaponStyle.Stance.AXE)) as KingData
	var king := b.deployment.deploy_king(kd, Vector2i(0, 0))
	var foes: Array[BattleUnit] = []
	for c in [Vector2i(6, 6), Vector2i(7, 6)]:
		foes.append(b.add_enemy(make(EnemyData, "Grunt", 4, style(TacticalMath.Geometry.KING, 1)) as EnemyData, c))
	var ended := []
	b.battle_ended.connect(func(o): ended.append(o))
	b.start()
	var turns := 0
	while b.outcome == BattleController.Outcome.ONGOING and turns < 300:
		var u := b.next_turn()
		turns += 1
		var atk := BattleAction.attack()
		# simple scripted play: attack anything in reach, otherwise step toward the nearest foe
		var targets := b.highlights(u, atk).filter(func(c): return b.grid.is_occupied(c) and b.grid.team_at(c) != u.team and not b.grid.occupant(c).is_down())
		if targets.is_empty():
			var others := b.all_units().filter(func(o): return o.team != u.team and not o.is_down())
			if not others.is_empty():
				var goal: Vector2i = others[0].cell
				var best := u.cell
				for c in b.move_range(u).cells():
					if (c - goal).length_squared() < (best - goal).length_squared():
						best = c
				b.move(u, best)
				targets = b.highlights(u, atk).filter(func(c): return b.grid.is_occupied(c) and b.grid.team_at(c) != u.team and not b.grid.occupant(c).is_down())
		if not targets.is_empty():
			ok(b.perform(u, atk, targets[0]).ok, "scripted attack")
		b.end_turn()
	ok(b.outcome != BattleController.Outcome.ONGOING, "battle reaches an outcome (%d turns)" % turns)
	eq(ended.size(), 1, "battle_ended once")
	ok(b.next_turn() == null, "no turns after the end")
	eq(b.finish(PartyRoster.new()).size(), 0, "finish hands back the haul")
