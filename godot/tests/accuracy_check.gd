extends Node
## Headless checks for the hit chance (owner, Nov 2026: most attacks should hit, facing matters, never under 75%): the rule in BattleController.hit_percent_for,
## the angle from the target's facing, the height and speed terms, the floors, the forecast's BACK ATTACK / FLANK / FRONT chip, and a roll that follows the chance.
## godot --headless --path godot res://tests/accuracy_check.tscn
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
	angles()
	rule()
	floors()
	forecast()
	rolls()
	print("accuracy checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func flat(n := 12) -> TacticalGrid:
	var rows := []
	for y in n:
		rows.append(" ".join(PackedStringArray(Array(range(n)).map(func(_i): return "g0"))))
	return TacticalGrid.from_rows(rows)


func make(cls, name: String, speed := 6) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.speed = speed
	u.stats.base_max_hp = 100
	var w := WeaponItem.new()
	w.base_power = 8
	var st := WeaponStyle.new()
	st.geometry = TacticalMath.Geometry.KING
	st.reach = 1
	st.stance = WeaponStyle.Stance.IMPACT
	u.loadout = EquipmentLoadout.make(w, st)
	if u.is_human():
		u.skill_tree = SkillTree.new()
	return u


func duel(speed_a := 6, speed_b := 6, g: TacticalGrid = null) -> Array:
	var b := BattleController.new()
	add_child(b)
	b.setup(g if g != null else flat())
	var king := b.deployment.deploy_king(make(KingData, "King", speed_a) as KingData, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe", speed_b) as EnemyData, Vector2i(5, 6))
	return [b, king, foe]


func angles() -> void:
	var d := duel()
	var b: BattleController = d[0]
	var king: BattleUnit = d[1]
	var foe: BattleUnit = d[2]
	var A := BattleController.Angle
	foe.facing = Vector2i(0, -1)  # looking at the King (he stands at y 5, it at y 6)
	eq(BattleController.angle_of(king, foe), A.FRONT, "the target looks at the attacker: front")
	foe.facing = Vector2i(0, 1)
	eq(BattleController.angle_of(king, foe), A.BACK, "the target looks away: back")
	foe.facing = Vector2i(1, 0)
	eq(BattleController.angle_of(king, foe), A.SIDE, "the target looks across: side")
	foe.facing = Vector2i(-1, 0)
	eq(BattleController.angle_of(king, foe), A.SIDE, "and the other way: side")
	# from far down a line the dominant axis decides; a diagonal tie is the side
	king.cell = Vector2i(5, 1)
	foe.facing = Vector2i(0, -1)
	eq(BattleController.angle_of(king, foe), A.FRONT, "far away on the line it faces: front")
	king.cell = Vector2i(3, 4)
	foe.facing = Vector2i(0, -1)
	eq(BattleController.angle_of(king, foe), A.SIDE, "a diagonal tie counts as the side")
	b.queue_free()


func rule() -> void:
	var d := duel()
	var b: BattleController = d[0]
	var king: BattleUnit = d[1]
	var foe: BattleUnit = d[2]
	var atk := BattleAction.attack()
	foe.facing = Vector2i(0, -1)
	var front := b.hit_percent_for(king, foe, atk)
	foe.facing = Vector2i(1, 0)
	var side := b.hit_percent_for(king, foe, atk)
	foe.facing = Vector2i(0, 1)
	var back := b.hit_percent_for(king, foe, atk)
	eq(side, 90.0, "equal speed, level ground, from the side: the base 90%")
	eq(front, 80.0, "in front: 10 less")
	eq(back, 100.0, "from behind: 10 more (and never above 100)")
	ok(front < side and side < back, "front < side < back")
	# height: standing higher helps, lower hurts
	var tall := TacticalGrid.from_rows(["g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g2 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0"])
	var d2 := duel(6, 6, tall)
	var b2: BattleController = d2[0]
	var k2: BattleUnit = d2[1]
	var f2: BattleUnit = d2[2]
	k2.cell = Vector2i(0, 5)
	f2.cell = Vector2i(0, 6)
	f2.facing = Vector2i(1, 0)
	var high_hit := b2.hit_percent_for(k2, f2, atk)
	var low_hit := b2.hit_percent_for(f2, k2, atk)
	k2.facing = Vector2i(1, 0)
	low_hit = b2.hit_percent_for(f2, k2, atk)
	ok(high_hit > low_hit, "the unit on the higher ground hits more often (%d%% against %d%%)" % [high_hit, low_hit])
	# speed
	var d3 := duel(14, 2)
	var b3: BattleController = d3[0]
	d3[2].facing = Vector2i(1, 0)
	var gap := float(d3[1].stat(StatModifier.Stat.SPEED) - d3[2].stat(StatModifier.Stat.SPEED)) / 4.0
	eq(b3.hit_percent_for(d3[1], d3[2], atk), 90.0 + gap, "a quicker attacker gains a quarter of the Speed difference (%.1f)" % gap)
	d3[1].facing = Vector2i(1, 0)
	eq(b3.hit_percent_for(d3[2], d3[1], atk), 90.0 - gap, "a slower one loses it")
	# a marked target is easier to hit with physical attacks only
	d3[2].add_status(BattleUnit.MARKED, 2)
	eq(b3.hit_percent_for(d3[1], d3[2], atk), 100.0, "marked: +10 for a physical attack")
	b.queue_free()
	b2.queue_free()
	b3.queue_free()


func floors() -> void:
	# across every mix of facing, speed gap and height, no hit is under 75% (and none over 100)
	var lowest := 100.0
	var highest := 0.0
	for sa in [1, 6, 30]:
		for sb in [1, 6, 30]:
			for f in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var d := duel(sa, sb)
				var b: BattleController = d[0]
				d[2].facing = f
				for act in [BattleAction.attack()]:
					var h := b.hit_percent_for(d[1], d[2], act)
					lowest = minf(lowest, h)
					highest = maxf(highest, h)
				b.queue_free()
	ok(lowest >= float(BattleController.MIN_HIT), "no hit is under %d%% (the lowest is %d%%)" % [BattleController.MIN_HIT, lowest])
	ok(highest <= 100.0, "none is over 100%")
	var d := duel(1, 30)
	var b: BattleController = d[0]
	d[2].facing = Vector2i(0, -1)
	var worst := b.hit_percent_for(d[1], d[2], BattleAction.attack())
	eq(worst, 75.0, "the worst case (slow attacker, quick target, from the front) is exactly the floor")
	d[1].add_status(BattleUnit.MILD_BLIND, 2)
	var mild := b.hit_percent_for(d[1], d[2], BattleAction.attack())
	d[1].statuses.clear()
	d[1].add_status(BattleUnit.BLIND, 2)
	var full := b.hit_percent_for(d[1], d[2], BattleAction.attack())
	ok(mild < worst and full < mild and full >= float(BattleController.BLIND_FLOOR), "a blinded attacker goes below it, down to %d%% at the worst (%d, %d)" % [BattleController.BLIND_FLOOR, mild, full])
	d[1].statuses.clear()
	b.surge_unit = d[1]
	eq(b.hit_percent_for(d[1], d[2], BattleAction.attack()), 100.0, "a Surge never misses")
	b.surge_unit = null
	b.miss_chance = 0.0
	eq(b.hit_percent_for(d[1], d[2], BattleAction.attack()), 100.0, "miss_chance 0 always hits (the checks that need every hit)")
	b.miss_chance = 1.0
	eq(b.hit_percent_for(d[1], d[2], BattleAction.attack()), 0.0, "and 1 never does")
	b.queue_free()


func forecast() -> void:
	var d := duel()
	var b: BattleController = d[0]
	var king: BattleUnit = d[1]
	var foe: BattleUnit = d[2]
	b.start()
	b.next_turn()
	foe.facing = Vector2i(0, 1)
	var back := DamageForecast.make(b, king, BattleAction.attack(), foe.cell)
	eq(back.aimed.angle, BattleController.Angle.BACK, "the forecast knows the angle: back")
	eq(back.aimed.hit_percent, 100, "and shows 100%")
	foe.facing = Vector2i(0, -1)
	var front := DamageForecast.make(b, king, BattleAction.attack(), foe.cell)
	eq(front.aimed.angle, BattleController.Angle.FRONT, "in front")
	eq(front.aimed.hit_percent, 80, "80%")
	var panel := ForecastPanel.new()
	add_child(panel)
	await get_tree().process_frame
	panel.show_forecast(back)
	var chips := panel.chips.get_children().filter(func(c): return c is Control)
	var texts := []
	for c in chips:
		for l in c.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
	ok(texts.has("BACK ATTACK"), "the panel says BACK ATTACK (%s)" % [texts])
	panel.show_forecast(front)
	texts.clear()
	for c in panel.chips.get_children():
		for l in c.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
	ok(texts.has("FRONT"), "and FRONT in front (%s)" % [texts])
	b.queue_free()
	panel.queue_free()


func rolls() -> void:
	var d := duel()
	var b: BattleController = d[0]
	var king: BattleUnit = d[1]
	var foe: BattleUnit = d[2]
	b.crit_scale = 0.0
	b.rng.seed = 21
	var misses := {"back": 0, "front": 0}
	var tries := 600
	for key in ["back", "front"]:
		foe.facing = Vector2i(0, 1) if key == "back" else Vector2i(0, -1)
		for i in tries:
			b.current = king
			b.moved = false
			b.acted = false
			foe.hp = foe.max_hp()
			king.sp = king.max_sp()
			var r := b.perform(king, BattleAction.attack(), foe.cell)
			if r.ok and r.hits[0].missed:
				misses[key] += 1
	ok(misses.back == 0, "a back attack at 100%% never misses (%d)" % misses.back)
	var share := float(misses.front) / tries
	ok(share > 0.14 and share < 0.26, "a front attack at 80%% misses about a fifth of the time (%.2f)" % share)
	b.queue_free()
