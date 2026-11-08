extends Node
## Headless: the healing proficiency's seven rank E skills (data/skills/healing.json, SupportRules). Each one's rule is checked on its own
## (the rolls over many tries), the targeting (allies only, enemies only), the SP Finisher's scale, Chance!'s buff and its end, poison's
## damage each turn (never below 1 HP), and that the skills load as rank E healing skills.
## godot --headless --path godot res://tests/healing_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	var list := SkillLibrary.healing().slice(0, 7)  # the owner's seven; build_skills.py adds more after them
	ok(list.size() == 7, "seven healing skills (%d)" % list.size())
	ok(list.all(func(s): return s.rank == SkillData.Rank.E and s.category == Proficiency.Category.HEALING and s.sp_cost == 3), "all rank E, healing, 3 SP")
	var names := list.map(func(s): return s.display_name)
	ok(names == ["Pray", "Heal", "HP Roulette", "Poison Spit", "Venom Removal", "Chance!", "SP Finisher"], "the seven, in the owner's order (%s)" % [names])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pray := _skill("pray")
	var heal := _skill("heal")
	var roulette := _skill("roulette")
	var spit := _skill("poison_spit")
	var venom := _skill("venom_removal")
	var chance := _skill("chance")
	var finisher := _skill("sp_finisher")

	# targeting
	var king := _unit(true, 1)
	var ally := _unit(true, 1)
	var foe := _unit(false, 2)
	ok(SupportRules.may_target(king, ally, heal) and not SupportRules.may_target(king, foe, heal), "Heal: teammates only")
	ok(SupportRules.may_target(king, ally, roulette) and not SupportRules.may_target(king, foe, roulette), "HP Roulette: teammates only, never an enemy")
	ok(not SupportRules.may_target(king, ally, spit) and SupportRules.may_target(king, foe, spit), "Poison Spit: enemies only")
	ok(not SupportRules.may_target(king, ally, finisher) and SupportRules.may_target(king, foe, finisher), "SP Finisher: enemies only")

	# Heal: 30, plus or minus 10%
	var lo := 999
	var hi := 0
	for i in 300:
		var r := _result(king, ally, heal, rng)
		lo = mini(lo, r.hits[0].amount)
		hi = maxi(hi, r.hits[0].amount)
	ok(lo >= 27 and hi <= 33 and lo < 30 and hi > 30, "Heal restores 27 to 33 (%d to %d)" % [lo, hi])

	# Pray: about half the time, and then every ailment goes
	var cured := 0
	for i in 400:
		var u := _unit(true, 1)
		u.add_status(BattleUnit.MARKED, 3)
		u.add_status(BattleUnit.POISON, 3)
		var r := _result(king, u, pray, rng)
		if not u.has_status(BattleUnit.MARKED) and not u.has_status(BattleUnit.POISON):
			cured += 1
	ok(cured > 150 and cured < 250, "Pray cures about half the time (%d of 400)" % cured)

	# Venom Removal: poison only
	var v := _unit(true, 1)
	v.add_status(BattleUnit.POISON, 3)
	v.add_status(BattleUnit.MARKED, 3)
	_result(king, v, venom, rng)
	ok(not v.has_status(BattleUnit.POISON) and v.has_status(BattleUnit.MARKED), "Venom Removal cures poison and nothing else")

	# HP Roulette: a full heal or half of the HP taken away, never a KO
	var full := 0
	var half := 0
	var never_ko := true
	for i in 300:
		var u := _unit(true, 1)
		u.hp = 60
		var r := _result(king, u, roulette, rng)
		if u.hp == u.max_hp():
			full += 1
		elif u.hp == 60 - maxi(1, 60 / 2) or u.hp == 30:
			half += 1
		never_ko = never_ko and not u.is_down()
	ok(full > 100 and half > 100 and never_ko, "HP Roulette: full heal or half taken (%d full, %d half, never down %s)" % [full, half, never_ko])
	var low := _unit(true, 1)
	low.hp = 1
	_result(king, low, roulette, rng)
	ok(low.hp >= 1, "HP Roulette never takes a unit to 0 HP")

	# Poison Spit: about half the foes are poisoned, for 3 to 5 of its turns
	var poisoned := 0
	var turns_ok := true
	for i in 300:
		var f := _unit(false, 2)
		_result(king, f, spit, rng)
		if f.has_status(BattleUnit.POISON):
			poisoned += 1
			turns_ok = turns_ok and f.statuses[BattleUnit.POISON] >= 3 and f.statuses[BattleUnit.POISON] <= 5
	ok(poisoned > 110 and poisoned < 190 and turns_ok, "Poison Spit poisons about half, for 3 to 5 turns (%d of 300)" % poisoned)
	var p := _unit(false, 2)
	p.hp = p.max_hp()
	p.add_status(BattleUnit.POISON, 3)
	var dmg := SupportRules.poison_tick(p)
	ok(dmg == maxi(1, p.max_hp() * 5 / 100) and p.hp == p.max_hp() - dmg, "poison takes 5%% of max HP (%d)" % dmg)
	p.hp = 1
	SupportRules.poison_tick(p)
	ok(p.hp == 1 and not p.is_down(), "poison never takes the last point of HP")

	# Chance!: a random stat up 10% for 5 turns, named on screen
	var c := _unit(true, 1)
	var base_attack := c.stat(StatModifier.Stat.ATTACK)
	var named := false
	var raised := false
	for i in 40:
		var t := _unit(true, 1)
		var before := t.stat(StatModifier.Stat.ATTACK)
		var r := _result(king, t, chance, rng)
		if r.hits[0].notes.size() == 1 and r.hits[0].notes[0].contains("+10%"):
			named = true
		raised = raised or t.buffs.size() == 1
		if i == 0:
			ok(t.buffs.size() == 1 and t.buffs.values()[0][0] == 10 and t.buffs.values()[0][1] == 5, "Chance! gives +10% for 5 turns")
			var key: int = t.buffs.keys()[0]
			var base := t.data.stats.final_stat(key, t.data.loadout)
			ok(t.stat(key) == base * 110 / 100, "that stat goes up 10%% (%d -> %d)" % [base, t.stat(key)])
	ok(named and raised, "Chance! names the stat it raised")
	c.add_buff(StatModifier.Stat.ATTACK, 10, 2)
	ok(c.stat(StatModifier.Stat.ATTACK) == base_attack * 110 / 100, "a buffed stat shows the rise (%d -> %d)" % [base_attack, c.stat(StatModifier.Stat.ATTACK)])
	c.tick_statuses()
	c.tick_statuses()
	ok(c.buffs.is_empty() and c.stat(StatModifier.Stat.ATTACK) == base_attack, "the buff ends after its turns")

	# SP Finisher: 110% at no SP, +5% per 10% of SP left, all of it spent
	var f := _unit(true, 1)
	f.sp = 0
	var at_zero := SupportRules.finisher_percent(f)
	f.sp = f.max_sp()
	var at_full := SupportRules.finisher_percent(f)
	f.sp = f.max_sp() * 35 / 100
	var at_35 := SupportRules.finisher_percent(f)
	ok(at_zero == 110 and at_full == 160 and at_35 == 125, "SP Finisher: 110 at none, 160 at full, 125 at 35%% (%d, %d, %d)" % [at_zero, at_full, at_35])
	var full_sp := _unit(true, 1)
	var empty_sp := _unit(true, 1)
	full_sp.sp = full_sp.max_sp()
	empty_sp.sp = 1
	var foe_a := _unit(false, 2)
	var foe_b := _unit(false, 2)
	foe_a.hp = foe_a.max_hp()
	foe_b.hp = foe_b.max_hp()
	var pa := SupportRules.preview(full_sp, foe_a, finisher, ActionResult.Hit.new(), _area(), Vector2i.ZERO, 0)
	var pb := SupportRules.preview(empty_sp, foe_b, finisher, ActionResult.Hit.new(), _area(), Vector2i.ZERO, 0)
	ok(pa.amount > pb.amount and pb.amount >= 1, "the finisher hits harder with more SP (%d at full, %d at 1 SP)" % [pa.amount, pb.amount])
	# performed on a real board: an enemy with the finisher (its only skill) strikes the King, spends all its SP and hurts him
	var b := BattleController.new()
	add_child(b)
	b.setup(_board())
	b.miss_chance = 0.0
	b.crit_scale = 0.0  # exact damage: no random critical hits
	var king_unit := b.deployment.deploy_king(FirstBattle.game().roster.king, Vector2i(2, 2))
	king_unit.data.stats.speed = 1
	var ed := FirstBattle.squire(3)
	ed.basic_attack_only = false
	ed.skills_only = true
	ed.skills = [finisher]
	ed.stats.speed = 30
	var performer := b.add_enemy(ed, Vector2i(4, 2))
	b.start()
	var acted_first := b.next_turn() == performer
	performer.sp = performer.max_sp()
	var king_hp := king_unit.hp
	var res := b.perform(performer, BattleAction.use(finisher), Vector2i(2, 2))
	ok(acted_first and res.ok, "the finisher performs on the King in reach (%s)" % res.error)
	ok(performer.sp == 0 and res.sp_spent == performer.max_sp(), "it spends all the SP")
	ok(king_unit.hp < king_hp, "and hurts him (%d -> %d)" % [king_hp, king_unit.hp])
	b.queue_free()

	print("healing checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _area() -> TargetArea:
	var a := TargetArea.new()
	a.tiles = [Vector2i.ZERO]
	return a


func _board() -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(8)
	row.fill("g0")
	for y in 8:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func _skill(support: String) -> SkillData:
	for s in SkillLibrary.healing():
		if s.support == support:
			return s
	return null


func _unit(is_player: bool, team: int) -> BattleUnit:
	var d: UnitData = FirstBattle.game().roster.king.duplicate(true) if is_player else FirstBattle.squire(1)
	return BattleUnit.new(d, team)


## Runs `s` from `user` onto `target`, as a performed action would (no miss rolls: the hit is taken as it lands).
func _result(user: BattleUnit, target: BattleUnit, s: SkillData, rng: RandomNumberGenerator) -> ActionResult:
	var r := ActionResult.new()
	var h := ActionResult.Hit.new()
	h.target = target
	h.tile = Vector2i.ZERO
	var area := TargetArea.new()
	area.tiles = [Vector2i.ZERO]
	SupportRules.preview(user, target, s, h, area, Vector2i.ZERO, 0)
	r.hits = [h]
	SupportRules.roll(user, r, s, rng)
	if not h.heal and h.amount > 0:
		target.hp = maxi(1, target.hp - h.amount)
	elif h.heal:
		target.hp = mini(target.max_hp(), target.hp + h.amount)
	return r
