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
	defending()
	skill_formula()
	vessels_in_battle()
	losing()
	full_battle()
	summary_and_relics()
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
	var kd := make(KingData, "King", 6, style(TacticalMath.Geometry.ROOK, 2, WeaponStyle.Stance.AXE)) as KingData  # reach 2
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
	ok(not b.has_method("set_stance"), "no way to change a stance in battle")
	for st in WeaponStyle.Stance.values():  # whatever stance the style brings, SP costs stay the same
		var other := battle(board())
		var kd2 := make(KingData, "K", 10, style(TacticalMath.Geometry.ROOK, 2, st)) as KingData
		var k2 := other.deployment.deploy_king(kd2, Vector2i(5, 5))
		eq(k2.stance(), st, "the stance comes from the style")
		eq(BattleAction.use(bolt).sp_cost(), 4, "stance %d does not change SP" % st)
		other.queue_free()
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


## A battle with a King of the given stance (Rook, reach 2) and three foes north of him.
func stance_battle(stance: WeaponStyle.Stance) -> Array:
	var b := battle(board())
	var king := b.deployment.deploy_king(make(KingData, "King", 10, style(TacticalMath.Geometry.ROOK, 2, stance)) as KingData, Vector2i(5, 5))
	var near := b.add_enemy(make(EnemyData, "Near", 1) as EnemyData, Vector2i(5, 3))
	var behind := b.add_enemy(make(EnemyData, "Behind", 1) as EnemyData, Vector2i(5, 2))
	var side := b.add_enemy(make(EnemyData, "Side", 1) as EnemyData, Vector2i(6, 3))
	b.start()
	b.next_turn()
	return [b, king, near, behind, side]


func targeting_and_damage() -> void:
	var atk := BattleAction.attack()
	# Impact: reach 2 - 1 = 1, cross splash
	var t := stance_battle(WeaponStyle.Stance.IMPACT)
	var b: BattleController = t[0]
	var king: BattleUnit = t[1]
	eq(b.highlights(king, atk).size(), 4, "impact rook reach 1")
	ok(not b.highlights(king, atk).has(Vector2i(5, 3)), "near foe out of reach in impact")
	# Pierce: reach 3, hits 1 behind
	t = stance_battle(WeaponStyle.Stance.PIERCE)
	b = t[0]
	king = t[1]
	var near: BattleUnit = t[2]
	var behind: BattleUnit = t[3]
	var side: BattleUnit = t[4]
	var hl := b.highlights(king, atk)
	ok(hl.has(Vector2i(5, 3)) and not hl.has(Vector2i(5, 2)), "pierce reaches the first foe, line stops there")
	eq(hl.size(), 3 + 3 + 3 + 2, "pierce rook reach 3 (one ray blocked at the foe)")
	var p := b.preview(king, atk, Vector2i(5, 3))
	# physical: weapon 8 + atk 6 - def 5 = 9; pierce 90% aimed -> 8, 75% behind -> 7
	eq(p.hit_on(near).amount, 8, "aimed tile 90%")
	eq(p.hit_on(behind).amount, 7, "pierced tile 75%")
	ok(p.hit_on(side) == null, "side not hit in pierce")
	# Axe: reach 2, cleaves sideways
	t = stance_battle(WeaponStyle.Stance.AXE)
	b = t[0]
	king = t[1]
	near = t[2]
	behind = t[3]
	side = t[4]
	p = b.preview(king, atk, Vector2i(5, 3))
	eq(p.hit_on(near).amount, 10, "axe 110%")
	eq(p.hit_on(side).amount, 5, "cleave 50% of 9, rounded")
	eq(p.sp_spent, 0, "attack costs no SP in any stance")
	king.data.loadout.weapon_style.stance = WeaponStyle.Stance.IMPACT  # editing the resource mid-battle...
	eq(king.stance(), WeaponStyle.Stance.AXE, "...does not change the stance of a unit already in battle")
	king.data.loadout.weapon_style.stance = WeaponStyle.Stance.AXE
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
	# knock out and win (an Impact King: the cross burst)
	t = stance_battle(WeaponStyle.Stance.IMPACT)
	b = t[0]
	king = t[1]
	near = t[2]
	behind = t[3]
	side = t[4]
	for e in [near, behind, side]:
		e.hp = 1
	b.move(king, Vector2i(5, 4))
	var ko := []
	b.unit_knocked_out.connect(func(u): ko.append(u))
	r = b.perform(king, atk, Vector2i(5, 3))
	ok(r.hit_on(near).knocked_out and near.is_down() and near.hp == 0, "knocked out at 0, never below")
	eq(ko.size(), 3, "cross burst hit all three foes")
	eq(b.outcome, BattleController.Outcome.WON, "every enemy down: won")
	ok(not GeometryResolver.targetable(b.grid, king.cell, b.footprint(king, atk)).is_empty(), "highlights still work")


## Physical skills: weapon + (rank multiplier x Attack) x (1 + 0.02 x level) x stance percent - Defense;
## the rank multiplier is rolled inside its band on each use. Basic attacks keep their own formula.
func skill_formula() -> void:
	var t := stance_battle(WeaponStyle.Stance.PIERCE)
	var b: BattleController = t[0]
	var king: BattleUnit = t[1]
	var near: BattleUnit = t[2]
	var area := TargetArea.new()
	area.aim = Vector2i(5, 3)
	area.tiles = [area.aim]
	var w: int = king.data.loadout.weapon_power()
	var atk: int = king.stat(StatModifier.Stat.ATTACK)
	var def: int = near.stat(StatModifier.Stat.DEFENSE)
	var sk := skill("Test Strike", Proficiency.Category.PHYSICAL, 3, 0)
	sk.rank = SkillData.Rank.S
	var act := BattleAction.use(sk)
	var pct := 90  # Pierce: the aimed tile takes 90%
	eq(DamageFormula.amount(king, near, act, 0, area, area.aim, 3.0), maxi(1, w + roundi(3.0 * atk * 1.0 * pct / 100.0) - def), "S (3.0) at level 0")
	eq(DamageFormula.amount(king, near, act, 10, area, area.aim, 3.0), maxi(1, w + roundi(3.0 * atk * 1.2 * pct / 100.0) - def), "level 10 adds 20% to the Attack part")
	eq(DamageFormula.amount(king, near, act, 0, area, area.aim, 1.0), maxi(1, w + roundi(1.0 * atk * 1.0 * pct / 100.0) - def), "the rolled multiplier scales only the Attack part")
	eq(DamageFormula.amount(king, near, act, 0, area, area.aim), DamageFormula.amount(king, near, act, 0, area, area.aim, sk.band_mid()), "a preview shows the band's middle")
	# the stance scales the Attack part only: the weapon part is the same at 100% (Impact) and 90% (Pierce)
	var area_impact := TargetArea.new()
	area_impact.aim = area.aim
	area_impact.tiles = [area.aim]
	var at_full := DamageFormula.skill_physical(king, near, sk, 0, 3.0, 100)
	var at_ninety := DamageFormula.skill_physical(king, near, sk, 0, 3.0, 90)
	eq(at_full - at_ninety, roundi(3.0 * atk * 1.0 * 100 / 100.0) - roundi(3.0 * atk * 1.0 * 90 / 100.0), "stance changes only the Attack part")
	# the roll stays in its band and varies
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var e := skill("Jab", Proficiency.Category.PHYSICAL, 2, 0)
	e.rank = SkillData.Rank.E
	var lo := 99.0
	var hi := 0.0
	for i in 200:
		var m := e.roll(rng)
		lo = minf(lo, m)
		hi = maxf(hi, m)
	ok(lo >= 1.0 and hi <= 1.2 and hi - lo > 0.1, "rank E rolls inside 1.00-1.20 and varies (%.3f-%.3f)" % [lo, hi])
	eq(sk.roll(rng), 3.0, "S is exactly 3")
	# a real use: the battle rolls the band and the hit uses it
	b.deployment.rng.seed = 1
	# the King learns the test skill (level 1), then uses it
	king.data.skill_tree.start_study(sk)
	king.data.skill_tree.mastery_of(sk).level = 1
	king.sp = 20
	b.current = king
	b.acted = false
	b.moved = false
	var r := b.perform(king, act, near.cell)
	ok(r.ok, "a skill use runs through the battle")
	# Pierce also reaches the foe behind; the aimed foe's hit uses the rolled multiplier (S is 3.0) at level 1
	eq(r.hit_on(near).amount, DamageFormula.amount(king, near, act, 1, area, area.aim, 3.0), "the hit uses the rolled multiplier (S is 3.0) at the King's level 1")
	# basic attacks keep their formula: weapon + Attack - Defense, scaled by the stance percent
	eq(DamageFormula.amount(king, near, BattleAction.attack(), 0, area, area.aim), StanceRules.scale_damage(maxi(1, w + atk - def), pct), "basic attack unchanged")

## Defend: half damage until the defender's next turn; ends the turn; not after acting.
func defending() -> void:
	var atk := BattleAction.attack()
	var t := stance_battle(WeaponStyle.Stance.PIERCE)
	var b: BattleController = t[0]
	var king: BattleUnit = t[1]
	var near: BattleUnit = t[2]
	eq(b.preview(king, atk, Vector2i(5, 3)).hit_on(near).amount, 8, "unguarded hit")
	near.guarding = true
	eq(b.preview(king, atk, Vector2i(5, 3)).hit_on(near).amount, 4, "a guarding unit takes half")
	near.guarding = false
	var cur := b.current
	ok(b.defend(cur), "the acting unit defends")
	ok(cur.guarding and b.current == null, "guarding, and the turn is over")
	ok(not b.defend(cur), "only on its own turn")
	var guard := 0
	while b.current != cur and guard < 20:
		b.end_turn()
		b.next_turn()
		guard += 1
	ok(b.current == cur and not cur.guarding, "the guard ends when its next turn starts")
	b.acted = true
	ok(not b.defend(cur) and not cur.guarding, "no Defend after acting")


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
	var s := b.finish(PartyRoster.new())
	eq(s.outcome, b.outcome, "summary outcome")
	eq(s.turns, turns, "summary turn count")
	var dealt := 0
	var taken := 0
	for bu in s.lines:
		dealt += s.lines[bu].damage_dealt
		taken += s.lines[bu].damage_taken
	ok(dealt > 0 and dealt == taken, "damage dealt and taken add up (%d)" % dealt)
	ok(s.line(king).knockouts == foes.filter(func(f): return f.is_down()).size() or b.outcome == BattleController.Outcome.LOST, "knockouts counted")
	ok(s.describe(king).begins_with("King: "), "summary line")


## The post-battle summary: skill levels from use, tether/sever counts, relics home or lost.
func summary_and_relics() -> void:
	var b := battle(board())
	b.rng.seed = 11
	b.deployment.rng.seed = 2
	var kd := make(KingData, "King", 10) as KingData
	var bolt := skill("Bolt", Proficiency.Category.ELEMENTAL, 1, 6)
	kd.skill_tree.start_study(bolt)
	kd.stats.set_rank(Proficiency.Category.ELEMENTAL, TacticalMath.Rank.S)
	kd.stats.will = 30  # SP 15 at level 0: enough casts to learn Bolt
	var king := b.deployment.deploy_king(kd, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Dummy", 1) as EnemyData, Vector2i(5, 7))
	foe.data.stats.base_max_hp = 100
	foe.hp = foe.max_hp()
	var roster := PartyRoster.new()
	var relics: Array[RelicItem] = []
	for i in 2:
		var r := RelicItem.new()
		r.display_name = "Relic %d" % i
		relics.append(r)
		b.deployment.place_relic(r, Vector2i(4 + i * 2, 4))
	var vd := make(VesselData, "Wisp", 10) as VesselData
	vd.fade_turns = 1
	b.start()
	ok(b.next_turn() == king, "King first")
	b.summon_vessel(king, vd, Vector2i(4, 4))
	var casts := 0
	while not kd.skill_tree.is_learned(bolt) and casts < 10:
		while b.current != king:
			b.end_turn()
			b.next_turn()
		ok(b.perform(king, BattleAction.use(bolt), Vector2i(5, 7)).ok, "cast Bolt")
		casts += 1
		b.end_turn()
		b.next_turn()
	ok(kd.skill_tree.is_learned(bolt), "S rank: Bolt learned by use (%d casts)" % casts)
	ok(not b.deployment.vessels.has(b.deployment.unit_of(vd)), "Wisp faded after 1 turn")
	var s := b.finish(roster)
	var kl := s.line(king)
	eq(kl.skill_uses[bolt], casts, "uses counted")
	eq(kl.skill_levels[bolt], 1, "one level from use")
	eq(s.skills_learned, [bolt], "Bolt learned this battle")
	eq(kl.sp_spent, casts, "SP spent counted")
	var vl: BattleSummary.UnitLine = null
	for bu in s.lines:
		if bu.data == vd:
			vl = s.lines[bu]
	ok(vl != null and vl.tethers == 1 and vl.severs == 1, "vessel line: tethered 1, severed 1")
	eq([vd.tether_count, vd.sever_count], [1, 1], "lifetime stats updated")
	eq(s.relics_secured.size() + s.relics_lost.size(), 2, "every field relic home or lost")
	ok(s.relics_lost.has(relics[1]), "untouched prop is lost at the end")
	eq(roster.relic_inventory, s.relics_secured, "secured relics went into the inventory")
	eq(s.outcome, BattleController.Outcome.ONGOING, "finished early: no outcome")
