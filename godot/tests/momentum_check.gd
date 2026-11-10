extends Node
## Headless checks for what makes the battle rewarding: Momentum and the Chain, the Surge (a sure, critical blow), the battle's
## grade and its bonus XP, the best grade kept per map, the results show, the HP bars, the sounds and the music files.
## godot --headless --path godot res://tests/momentum_check.tscn
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
	SaveSystem.dir = "user://test_saves_momentum_check"
	gauge_rules()
	surge_rules()
	rating_rules()
	grades_saved()
	audio_files()
	await stage_flow()
	print("momentum checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func flat(n := 12) -> TacticalGrid:
	var rows := []
	for y in n:
		rows.append(" ".join(PackedStringArray(Array(range(n)).map(func(_i): return "g0"))))
	return TacticalGrid.from_rows(rows)


func make(cls, name: String, hp := 100, attack := 10) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.stats.attack = attack
	u.stats.base_max_hp = hp
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


func battle(g: TacticalGrid) -> BattleController:
	var b := BattleController.new()
	add_child(b)
	b.setup(g)
	b.miss_chance = 0.0
	b.crit_scale = 0.0
	return b


func hit(target: BattleUnit, amount: int, crit := false, ko := false, missed := false) -> ActionResult.Hit:
	var h := ActionResult.Hit.new()
	h.target = target
	h.amount = amount
	h.crit = crit
	h.knocked_out = ko
	h.missed = missed
	return h


func result(hits: Array) -> ActionResult:
	var r := ActionResult.new()
	r.ok = true
	r.action = BattleAction.attack()
	for h in hits:
		r.hits.append(h)
	return r


func gauge_rules() -> void:
	var b := battle(flat())
	var king := b.deployment.deploy_king(make(KingData, "King") as KingData, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe") as EnemyData, Vector2i(5, 6))
	var m := Momentum.new()
	var filled := [0]
	m.filled.connect(func(): filled[0] += 1)
	eq(m.value, 0.0, "the gauge starts empty")
	var half := foe.max_hp() / 2
	var g1 := m.on_action(king, result([hit(foe, half)]), true)
	ok(is_equal_approx(g1, Momentum.DAMAGE_GAIN * float(half) / foe.max_hp()), "damage fills it by the share of the target's life it took (%.1f)" % g1)
	eq(m.chain, 1, "a blow that lands starts the Chain")
	var g2 := m.on_action(king, result([hit(foe, half)]), true)
	ok(g2 > g1 and is_equal_approx(g2, g1 * (1.0 + Momentum.CHAIN_STEP)), "the second link of the Chain fills it faster (%.1f)" % g2)
	var before := m.value
	var g3 := m.on_action(king, result([hit(foe, 1, true, true)]), true)
	ok(g3 >= (Momentum.CRIT_GAIN + Momentum.KO_GAIN) * m.chain_mult() - 0.01, "a critical knockout adds its own gains (%.1f)" % g3)
	ok(m.value > before, "and the gauge rose")
	eq(m.chain, 3, "three in a row")
	m.on_action(king, result([hit(foe, 0, false, false, true)]), true)
	eq(m.chain, 0, "a miss breaks the Chain")
	eq(m.best_chain, 3, "the best Chain is remembered")
	var v := m.value
	var heal := hit(king, 5)
	heal.heal = true
	m.on_action(king, result([heal]), true)
	ok(m.value > v and m.chain == 0, "a heal adds a little and neither builds nor breaks the Chain")
	v = m.value
	m.on_action(foe, result([hit(king, 3)]), false)
	ok(is_equal_approx(m.value - v, Momentum.GRIT_GAIN), "taking a blow adds grit")
	m.chain = 2
	m.on_action(foe, result([hit(king, 3, false, true)]), false)
	eq(m.chain, 0, "an ally knocked out breaks the Chain")
	m.add(500.0)
	ok(m.is_full() and m.value == Momentum.MAX and filled[0] == 1, "it caps at MAX and says so once")
	var pin := result([hit(foe, 1)])
	var fu := ActionResult.FollowUp.new()
	fu.unit = king
	fu.hit = hit(foe, 2)
	pin.followups.append(fu)
	var m2 := Momentum.new()
	var gp := m2.on_action(king, pin, true)
	ok(gp >= Momentum.PINCER_GAIN, "a pincer follow-up adds its own gain (%.1f)" % gp)
	var surged := result([hit(foe, 50, true, true)])
	surged.surged = true
	var m3 := Momentum.new()
	eq(m3.on_action(king, surged, true), 0.0, "a surged blow fills nothing")
	ok(not m3.spend(), "an unfilled gauge cannot be spent")
	ok(m.spend() and m.value == 0.0 and m.surges == 1, "a full one is spent whole")
	m.refund()
	ok(m.is_full() and m.surges == 0, "and comes back whole when the Surge went unused")


func surge_rules() -> void:
	var b := battle(flat())
	b.miss_chance = 1.0  # every blow would miss ...
	var king := b.deployment.deploy_king(make(KingData, "King") as KingData, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe") as EnemyData, Vector2i(5, 6))
	b.start()
	b.next_turn()
	while b.current != king:
		b.end_turn()
		b.next_turn()
	var atk := BattleAction.attack()
	var plain := b.preview(king, atk, foe.cell).hits[0].amount
	b.surge_unit = king
	eq(b.crit_percent_for(king, foe, atk), 100.0, "a Surge shows a certain critical")
	eq(b.miss_chance_for(king, foe, atk), 0.0, "and cannot miss")
	eq(b.crit_percent_for(foe, king, atk), BattleController.CRIT_BASE, "only for the unit that surged")
	var r := b.perform(king, atk, foe.cell)
	ok(r.ok and r.surged and not r.hits[0].missed and r.hits[0].crit, "the surged blow lands and is critical, even with crits off and a sure miss")
	eq(r.hits[0].amount, maxi(plain + 1, plain * BattleController.CRIT_PERCENT / 100), "for 1.5x")
	ok(b.surge_unit == null, "the Surge is used up")
	b.end_turn()
	b.next_turn()
	while b.current != king:
		b.end_turn()
		b.next_turn()
	b.surge_unit = king
	b.end_turn()
	ok(b.surge_unit == null, "an unused Surge never outlasts the turn")


func rating_rules() -> void:
	eq(BattleRating.grade_for(100), "S", "100 is an S")
	eq(BattleRating.grade_for(90), "S", "90 is an S")
	eq(BattleRating.grade_for(89), "A", "89 is an A")
	eq(BattleRating.grade_for(60), "B", "60 is a B")
	eq(BattleRating.grade_for(45), "C", "45 is a C")
	eq(BattleRating.grade_for(10), "D", "10 is a D")
	ok(BattleRating.better("S", "A") and BattleRating.better("C", "D") and not BattleRating.better("B", "B") and BattleRating.better("D", ""), "grades compare")
	eq(BattleRating.par_for(4), BattleRating.PAR_BASE + 4, "par is the base plus a round per enemy")
	var b := battle(flat())
	var king := b.deployment.deploy_king(make(KingData, "King") as KingData, Vector2i(5, 5))
	var foe := b.add_enemy(make(EnemyData, "Foe") as EnemyData, Vector2i(5, 6))
	b.summary.line(king).turns = 2
	b.summary.line(king).damage_dealt = 30
	# a clean, quick win
	var clean := BattleRating.new()
	clean.on_action(king, result([hit(foe, 20, true, true)]))
	clean.finish(b.summary, 1, 3, 0)
	eq(clean.crits, 1, "it counts the critical")
	eq(clean.score, BattleRating.VICTORY_POINTS + BattleRating.TEMPO_POINTS + BattleRating.SURVIVAL_POINTS + BattleRating.UNTOUCHED_POINTS + 2, "victory + full tempo + full survival + untouched + technique")
	eq(clean.grade, "S", "a clean quick win is an S")
	eq(clean.bonus_percent, 30, "an S pays 30% bonus XP")
	eq(clean.bonus_for(200), 60, "30% of the pool")
	ok(clean.mvp == king, "the unit that did the most is the MVP")
	ok(clean.feats.any(func(f): return f.name == "Swift Victory") and clean.feats.any(func(f): return f.name == "Untouched"), "its feats are listed")
	eq(clean.biggest_hit, 20, "the biggest hit is kept")
	# a slow, costly one
	b.summary.line(king).damage_taken = 40
	king.hp = 0
	var rough := BattleRating.new()
	rough.finish(b.summary, 1, BattleRating.par_for(1) + 9, 0)
	eq(rough.score, BattleRating.VICTORY_POINTS + maxi(0, BattleRating.SURVIVAL_POINTS - BattleRating.SURVIVAL_STEP), "slow and bloody: the victory and what is left of survival")
	eq(rough.grade, "C", "a C")
	ok(rough.bonus_percent < clean.bonus_percent, "which pays less")
	# technique is capped
	var showy := BattleRating.new()
	for i in 20:
		showy.on_action(king, result([hit(foe, 5, true)]))
	king.hp = king.max_hp()
	b.summary.line(king).damage_taken = 10
	showy.finish(b.summary, 1, 2, 6)
	ok(showy.feats.any(func(f): return f.name == "Technique" and int(f.points) == BattleRating.TECHNIQUE_POINTS), "technique never gives more than its cap")
	# the enemy's blows are not the party's feats
	var none := BattleRating.new()
	none.on_action(foe, result([hit(king, 5, true)]))
	eq(none.crits, 0, "an enemy's critical is no feat")


func grades_saved() -> void:
	var c := CampaignState.new()
	ok(c.record_grade("rf1", "B"), "a first grade is a new best")
	ok(not c.record_grade("rf1", "C") and c.best_grade("rf1") == "B", "a worse one does not replace it")
	ok(c.record_grade("rf1", "S") and c.best_grade("rf1") == "S", "a better one does")
	ok(not c.record_grade("", "S") and not c.record_grade("rf2", "Z"), "no map or no real grade: nothing kept")
	var g := FirstBattle.game()
	g.campaign.record_grade("rf1", "A")
	var back := SaveCodec.decode(SaveCodec.encode(g))
	ok(back.ok and back.game.campaign.best_grade("rf1") == "A", "best grades are saved and loaded")
	var old := SaveCodec.encode(g)
	(old["campaign"] as Dictionary).erase("best_grades")
	var loaded := SaveCodec.decode(old)
	ok(loaded.ok and loaded.game.campaign.best_grades.is_empty(), "a save from before the grades loads with none")


func audio_files() -> void:
	for e in ["swing_sword", "swing_dagger", "swing_heavy", "projectile_loose", "magic_cast", "impact_blade", "impact_sharp", "impact_heavy",
			"impact_arrow", "magic_hit", "impact_crit", "block", "miss", "heal", "ko", "step", "ui_hover", "ui_click", "ui_back", "ui_confirm",
			"turn_player", "callout", "surge_ready", "surge", "summon", "sword_get", "battle_start", "xp_tick", "level_up", "grade_stamp",
			"feat_pop", "reward", "warning"]:
		ok(CombatAudio.stream(e) != null, "sound effect %s has a file" % e)
	for t in ["battle_theme", "victory_fanfare", "results_loop", "defeat_sting"]:
		ok(BattleMusic.stream(t) != null, "music %s has a file" % t)
	var d: Dictionary = HitFeedback.data()
	for name in d.profiles:
		for k in ["sfx_swing", "sfx_impact"]:
			ok(CombatAudio.stream(String(d.profiles[name][k])) != null, "profile %s: %s has a file" % [name, k])


func make_stage() -> BattleStage:
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = WorldData.setup_for("alley", 1)  # the first Riverford map, as a replay from the world map
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
	s.battle.miss_chance = 0.0
	s.battle.crit_scale = 0.0
	return s


func until_king(s: BattleStage) -> BattleUnit:
	var king := s.battle.deployment.king
	var guard := 0
	while s.battle.current != king and guard < 200:
		guard += 1
		if s.battle.current != null and s.battle.current.team == 0:
			s.end_turn()
		await get_tree().process_frame
	return king


func bring(s: BattleStage, e: BattleUnit, king: BattleUnit) -> void:
	var c := king.cell + king.facing
	var o = s.grid.occupant(c)
	if o != null and o != e:
		s.grid.remove(o)
	s.grid.move_occupant(e, c)
	e.cell = c


func stage_flow() -> void:
	var s := make_stage()
	var king: BattleUnit = await until_king(s)
	ok(s.hud.gauge != null and s.hud.bars != null and s.hud.callouts != null and s.hud.result != null, "the HUD has the gauge, the HP bars, the callouts and the results show")
	ok(s.hud.bars.views == s.views and s.hud.bars.current == king, "the HP bars follow the stage's units and mark the acting one")
	ok(s.hud.gauge.surge_button.disabled, "an empty gauge: no Surge")
	ok(not s.toggle_surge(), "and the key does nothing")
	s.momentum.add(Momentum.MAX)
	ok(not s.hud.gauge.surge_button.disabled, "a full gauge lights the Surge button")
	ok(s.toggle_surge() and s.battle.surge_unit == king and s.momentum.value == 0.0, "Surge: the gauge is spent and the acting unit is armed")
	ok(s.toggle_surge() and s.battle.surge_unit == null and s.momentum.is_full(), "pressed again: called off, the gauge is back")
	s.toggle_surge()
	s.end_turn()
	ok(s.battle.surge_unit == null and s.momentum.is_full(), "a Surge unused when the turn ends gives the gauge back")
	king = await until_king(s)
	var foes: Array[BattleUnit] = s.battle.enemies.duplicate()
	var first: BattleUnit = foes[0]
	bring(s, first, king)
	first.hp = first.max_hp()
	s.toggle_surge()
	s._on_action_chosen(BattleAction.attack())
	s.tap_cell(first.cell)
	ok(s.mode == BattleStage.Mode.CONFIRM and s.hud.forecast.visible, "the forecast is on screen while the Surge is armed")
	var hp0 := first.hp
	s.tap_cell(first.cell)
	await get_tree().process_frame
	ok(first.hp < hp0 and s.battle.surge_unit == null and s.rating.surges == 1, "the surged attack lands and is counted")
	ok(s.rating.crits >= 1, "as a critical")
	# win the battle with real blows so there is XP to hand out
	var pool := 0
	for e in foes:
		pool += (e.data as EnemyData).exp_reward
		if e.is_down():
			continue
		bring(s, e, king)
		e.hp = 1
		s.battle.acted = false
		await s._resolve(king, BattleAction.attack(), e.cell)
	eq(s.battle.outcome, BattleController.Outcome.WON, "every enemy is down")
	var lv0 := king.data.stats.level
	ok(s._check_end(), "the battle ends")
	var sm := s.summary
	ok(sm.rating != null and sm.rating.grade != "" and sm.rating.rounds >= 1, "a won battle is graded (%s, %d points)" % [sm.rating.grade, sm.rating.score])
	eq(sm.exp_bonus, sm.rating.bonus_for(pool), "the grade's bonus XP is its percent of the enemies' pool")
	eq(sm.exp_pool, pool + sm.exp_bonus, "and is inside the pool that was handed out")
	ok(sm.exp_before.has(king) and int(sm.exp_before[king][0]) == lv0, "the results know where each XP bar started")
	eq(s.game.campaign.best_grade(s.setup.map_id), sm.rating.grade, "the map's best grade is kept")
	ok(sm.new_best, "and it is a new best")
	var res: ResultScreen = s.hud.result
	ok(res.visible and res.done and s.hud.result_panel.visible and s.hud.result_title.text == "Victory", "the results are on screen, finished at once without animation")
	eq(res.feat_box.get_child_count(), sm.rating.feats.size(), "every feat is listed")
	ok(res.rows_box.get_child_count() >= 1, "there is a row for each unit that fought")
	ok(res.rewards_box.get_child_count() >= 1, "and the rewards")
	ok(not s.hud.return_button.disabled and s.hud.return_button.text == "Continue", "the button is ready")
	ok(not s.hud.gauge.visible and not s.hud.bars.visible, "the gauge and the HP bars are put away")
	ok(not res.plain.text.is_empty(), "the plain summary is still there for tools")
	s.queue_free()
	await get_tree().process_frame
	# a lost battle: no grade, the defeat screen
	var s2 := make_stage()
	await until_king(s2)
	for u in s2.battle.deployment.field_units():
		u.hp = 0
	s2.battle._check_outcome()
	ok(s2._check_end() and s2.summary.rating == null and s2.summary.exp_bonus == 0, "a lost battle is not graded and pays no bonus")
	ok(s2.hud.result.visible and s2.hud.result_title.text == "Defeat" and not s2.hud.result.rows_box.visible, "the defeat screen has no rows")
	eq(s2.game.campaign.best_grade(s2.setup.map_id), "", "and leaves no grade behind")
	s2.queue_free()
	await get_tree().process_frame
