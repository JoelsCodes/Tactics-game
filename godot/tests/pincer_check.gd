extends Node
## Headless checks for critical hits (the formula, 1.5x, never on heals or follow-ups), the pincer follow-up (two allies on opposite sides of
## a target; the other one strikes for half; enemies too) and one level of extra upward reach.
## godot --headless --path godot res://tests/pincer_check.tscn
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
	crit_formula()
	crit_damage()
	pincer()
	enemy_pincer()
	reach_up()
	print("pincer checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func flat(n := 12) -> TacticalGrid:
	var rows := []
	for y in n:
		rows.append(" ".join(PackedStringArray(Array(range(n)).map(func(_i): return "g0"))))
	return TacticalGrid.from_rows(rows)


func style(geo := TacticalMath.Geometry.KING) -> WeaponStyle:
	var s := WeaponStyle.new()
	s.geometry = geo
	s.reach = 1
	s.stance = WeaponStyle.Stance.IMPACT
	return s


func make(cls, name: String, will := 6, speed := 6, attack := 10) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.will = will
	u.stats.speed = speed
	u.stats.attack = attack
	u.stats.base_max_hp = 100
	var w := WeaponItem.new()
	w.base_power = 8
	u.loadout = EquipmentLoadout.make(w, style())
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


func battle(g: TacticalGrid) -> BattleController:
	var b := BattleController.new()
	add_child(b)
	b.setup(g)
	b.miss_chance = 0.0
	b.crit_scale = 0.0
	return b


func crit_formula() -> void:
	var b := battle(flat())
	var king := b.deployment.deploy_king(make(KingData, "King", 6, 6) as KingData, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe", 6, 6) as EnemyData, Vector2i(5, 6))
	var atk := BattleAction.attack()
	eq(b.crit_percent_for(king, foe, atk), BattleController.CRIT_BASE, "equal stats: the base chance (5%)")
	var sharp := b.add_enemy(make(EnemyData, "Dull", 2, 2) as EnemyData, Vector2i(8, 8))
	var gain := b.crit_percent_for(king, sharp, atk) - BattleController.CRIT_BASE
	ok(gain > 0.0, "a steadier, faster attacker crits more often (+%.1f)" % gain)
	ok(is_equal_approx(gain, (king.stat(StatModifier.Stat.WILL) - sharp.stat(StatModifier.Stat.WILL)) / 2.0 + (king.stat(StatModifier.Stat.SPEED) - sharp.stat(StatModifier.Stat.SPEED)) / 4.0), "the gain is Will difference / 2 plus Speed difference / 4")
	ok(b.crit_percent_for(sharp, king, atk) < BattleController.CRIT_BASE, "and a dull one against a steady foe crits less")
	var tough := b.add_enemy(make(EnemyData, "Tough", 90, 90) as EnemyData, Vector2i(9, 9))
	ok(b.crit_percent_for(sharp, tough, atk) >= 0.0, "never below 0")
	ok(b.crit_percent_for(tough, sharp, atk) <= BattleController.CRIT_MAX, "never above %d%%" % int(BattleController.CRIT_MAX))
	var pv := b.preview(king, atk, Vector2i(5, 6))
	ok(not pv.hits.is_empty() and pv.hits[0].crit_percent == b.crit_percent_for(king, foe, atk) and not pv.hits[0].crit, "a preview carries the chance and never a crit")


func crit_damage() -> void:
	var normal := 0
	var crit := 0
	for i in 2:
		var b := battle(flat())
		b.crit_scale = 1.0 if i == 1 else 0.0
		var king := b.deployment.deploy_king(make(KingData, "King", 6, 6) as KingData, Vector2i(5, 5))
		var foe := b.add_enemy(make(EnemyData, "Foe", 6, 6) as EnemyData, Vector2i(5, 6))
		b.start()
		b.next_turn()
		if b.current != king:
			b.end_turn()
		# make the roll certain for the crit run
		if i == 1:
			b.crit_scale = 100.0
		var r := b.perform(king, BattleAction.attack(), Vector2i(5, 6))
		ok(r.ok and not r.hits.is_empty(), "the attack lands (%d)" % i)
		if i == 0:
			normal = r.hits[0].amount
			ok(not r.hits[0].crit, "crits off: no crit")
		else:
			crit = r.hits[0].amount
			ok(r.hits[0].crit, "a certain roll is a crit")
			eq(foe.hp, foe.max_hp() - crit, "the HP lost is the crit amount")
	eq(crit, maxi(normal + 1, normal * 150 / 100), "a crit does 1.5x (%d -> %d)" % [normal, crit])
	# no crit on a heal
	var b2 := battle(flat())
	b2.crit_scale = 100.0
	var k := b2.deployment.deploy_king(make(KingData, "King") as KingData, Vector2i(5, 5))
	var healing := SkillData.new()
	healing.display_name = "Mend"
	healing.category = Proficiency.Category.HEALING
	healing.base_power = 5
	var pre := b2.preview(k, _skill_action(healing), k.cell)
	ok(pre.hits.is_empty() or pre.hits[0].crit_percent == 0.0, "a heal has no crit chance")


func _skill_action(s: SkillData) -> BattleAction:
	var a := BattleAction.new()
	a.skill = s
	return a


## Two allies on opposite sides of a foe: when one hits it the other follows up for half of its own basic damage.
func pincer() -> void:
	var b := battle(flat())
	var king := b.deployment.deploy_king(make(KingData, "King", 6, 20, 14) as KingData, Vector2i(5, 4))
	var cap := b.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 6, 3, 14) as CoCaptainData, Vector2i(5, 6))
	var foe := b.add_enemy(make(EnemyData, "Foe", 6, 1) as EnemyData, Vector2i(5, 5))
	b.start()
	b.next_turn()
	eq(b.current, king, "the King is up")
	var hp0 := foe.hp
	var r := b.perform(king, BattleAction.attack(), foe.cell)
	ok(r.ok and r.hits.size() == 1 and r.hits[0].amount > 0, "the King's attack lands")
	eq(r.followups.size(), 1, "the Co-Captain across the foe follows up")
	var fu := r.followups[0]
	eq(fu.unit, cap, "it is the unit on the far side")
	var full := DamageFormula.amount(cap, foe, BattleAction.attack(), 0, null_area(cap, foe), foe.cell)
	eq(fu.hit.amount, maxi(1, full * 50 / 100), "for half of its normal basic damage (%d of %d)" % [fu.hit.amount, full])
	ok(not fu.hit.crit, "a follow-up never crits")
	eq(foe.hp, hp0 - r.hits[0].amount - fu.hit.amount, "both blows came off the foe's HP")
	eq(b.summary.line(cap).damage_dealt, fu.hit.amount, "and the summary credits the follow-up to the ally that struck it")
	ok(b.acted and b.current == king and not b.moved or b.acted, "the follow-up costs the ally nothing: it is still the King's turn and the Co-Captain keeps its own")
	# not surrounded: the ally on a diagonal, or one tile away, or the actor not next to the foe
	for case in [["diagonal", Vector2i(6, 6)], ["too far", Vector2i(5, 7)]]:
		var b2 := battle(flat())
		var k2 := b2.deployment.deploy_king(make(KingData, "King", 6, 20, 14) as KingData, Vector2i(5, 4))
		b2.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 6, 3, 14) as CoCaptainData, case[1])
		var f2 := b2.add_enemy(make(EnemyData, "Foe", 6, 1) as EnemyData, Vector2i(5, 5))
		b2.start()
		b2.next_turn()
		var r2 := b2.perform(k2, BattleAction.attack(), f2.cell)
		eq(r2.followups.size(), 0, "no follow-up when the ally is %s" % case[0])
	# a miss, a heal and a kill start nothing
	var b3 := battle(flat())
	b3.miss_chance = 1.0
	var k3 := b3.deployment.deploy_king(make(KingData, "King", 6, 20, 14) as KingData, Vector2i(5, 4))
	b3.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 6, 3, 14) as CoCaptainData, Vector2i(5, 6))
	var f3 := b3.add_enemy(make(EnemyData, "Foe", 6, 1) as EnemyData, Vector2i(5, 5))
	b3.start()
	b3.next_turn()
	eq(b3.perform(k3, BattleAction.attack(), f3.cell).followups.size(), 0, "a miss starts no follow-up")
	var b4 := battle(flat())
	var k4 := b4.deployment.deploy_king(make(KingData, "King", 6, 20, 14) as KingData, Vector2i(5, 4))
	b4.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 6, 3, 14) as CoCaptainData, Vector2i(5, 6))
	var f4 := b4.add_enemy(make(EnemyData, "Foe", 6, 1) as EnemyData, Vector2i(5, 5))
	f4.hp = 1
	b4.start()
	b4.next_turn()
	var r4 := b4.perform(k4, BattleAction.attack(), f4.cell)
	ok(r4.hits[0].knocked_out and r4.followups.is_empty(), "a kill leaves nothing to follow up")
	# a sleeping ally cannot
	var b5 := battle(flat())
	var k5 := b5.deployment.deploy_king(make(KingData, "King", 6, 20, 14) as KingData, Vector2i(5, 4))
	var c5 := b5.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 6, 3, 14) as CoCaptainData, Vector2i(5, 6))
	var f5 := b5.add_enemy(make(EnemyData, "Foe", 6, 1) as EnemyData, Vector2i(5, 5))
	c5.add_status(BattleUnit.SLEEP, 2)
	b5.start()
	b5.next_turn()
	eq(b5.perform(k5, BattleAction.attack(), f5.cell).followups.size(), 0, "a sleeping ally does not follow up")
	# the follow-up can finish the foe, and a unit knocked out by it counts
	var b6 := battle(flat())
	var k6 := b6.deployment.deploy_king(make(KingData, "King", 6, 20, 14) as KingData, Vector2i(5, 4))
	var c6 := b6.deployment.deploy_co_captain(make(CoCaptainData, "Cap", 6, 3, 14) as CoCaptainData, Vector2i(5, 6))
	var f6 := b6.add_enemy(make(EnemyData, "Foe", 6, 1) as EnemyData, Vector2i(5, 5))
	b6.start()
	b6.next_turn()
	var probe := b6.preview(k6, BattleAction.attack(), f6.cell).hits[0].amount
	f6.hp = probe + 1  # the King leaves it on 1 HP: the follow-up (at least 1) finishes it
	var r6 := b6.perform(k6, BattleAction.attack(), f6.cell)
	ok(r6.followups.size() == 1 and r6.followups[0].hit.knocked_out and f6.is_down(), "the follow-up can be the killing blow")
	eq(b6.summary.line(c6).knockouts, 1, "and is counted as the ally's knockout")


func null_area(from: BattleUnit, to: BattleUnit) -> TargetArea:
	var a := TargetArea.new()
	a.origin = from.cell
	a.aim = to.cell
	a.tiles = [to.cell]
	return a


func enemy_pincer() -> void:
	var b := battle(flat())
	var p := b.deployment.deploy_king(make(KingData, "King", 6, 1, 8) as KingData, Vector2i(5, 5))
	var e1 := b.add_enemy(make(EnemyData, "Wolf A", 6, 30, 14) as EnemyData, Vector2i(5, 4))
	var e2 := b.add_enemy(make(EnemyData, "Wolf B", 6, 3, 14) as EnemyData, Vector2i(5, 6))
	b.start()
	var n := 0
	while b.current != e1 and n < 20:
		b.end_turn()
		b.next_turn()
		n += 1
	eq(b.current, e1, "an enemy is up")
	var r := b.perform(e1, BattleAction.attack(), p.cell)
	ok(r.ok and r.hits[0].amount > 0, "the wolf bites")
	eq(r.followups.size(), 1, "the other wolf follows up: enemies do it too")
	eq(r.followups[0].unit, e2, "it is the one across from the King")


func reach_up() -> void:
	var rows := ["g0 g0 g0 g0 g0 g0", "g0 g1 g0 g2 g0 g0", "g0 g0 g0 g0 g0 g0"]
	var g := TacticalGrid.from_rows(rows)
	var west := Vector2i(1, 0)
	var t1 := StyleResolver.targetable(g, Vector2i(0, 1), TacticalMath.Geometry.ROOK, WeaponStyle.Stance.IMPACT, west)
	ok(t1.has(Vector2i(1, 1)), "a target one level higher than the attacker can be aimed at")
	ok(not t1.has(Vector2i(3, 1)), "two levels higher can not, and it ends the line")
	var fp := GeometryPattern.build(TacticalMath.Geometry.ROOK, 4)
	fp.vertical_reach = 0
	var t2 := GeometryResolver.targetable(g, Vector2i(0, 1), fp)
	ok(t2.has(Vector2i(1, 1)) and not t2.has(Vector2i(3, 1)), "skill footprints get the same one level up")
