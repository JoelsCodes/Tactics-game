extends Node
## Headless: the damage prediction view. DamageForecast (chance to hit, damage as a range, HP after, knockout, effects, other targets) and the
## ForecastPanel on the battle HUD: it slides out when a tile is aimed with the attack or a skill, shows the numbers, and goes away when
## the aim ends (cancel or perform).
## godot --headless --path godot res://tests/forecast_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func _ready() -> void:
	DamageFormula.legacy_numbers()  # this check reads exact numbers from before the FFT-pace tuning (tests/tension_check measures the new ones)
	SaveSystem.dir = "user://test_saves_forecast"
	await logic()
	await stage()
	print("forecast checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _board() -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(8)
	row.fill("g0")
	for y in 8:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func _battle() -> Array:  # [controller, king unit, foe unit]
	var b := BattleController.new()
	add_child(b)
	b.setup(_board())
	var k := b.deployment.deploy_king(FirstBattle.game().roster.king, Vector2i(2, 2))
	k.data.stats.speed = 30
	k.data.stats.attack = 60  # enough that a 33% hit still shows a spread when a skill rolls its band
	var ed := FirstBattle.squire(3)
	ed.stats.speed = 1
	var foe := b.add_enemy(ed, Vector2i(3, 2))
	b.start()
	b.next_turn()
	return [b, k, foe]


func logic() -> void:
	var t := _battle()
	var b: BattleController = t[0]
	var king: BattleUnit = t[1]
	var foe: BattleUnit = t[2]
	# the basic attack: one fixed number, 75% to hit
	var f := DamageForecast.make(b, king, BattleAction.attack(), foe.cell)
	ok(not f.is_empty() and f.aimed.target == foe, "the attack on a foe: one line, on the foe")
	ok(f.aimed.hit_percent >= BattleController.MIN_HIT and f.aimed.hit_percent <= 100 and not f.aimed.heal, "a hit is never under %d%% (%d%%)" % [BattleController.MIN_HIT, f.aimed.hit_percent])
	ok(f.aimed.low == f.aimed.high and f.aimed.low > 0 and f.aimed.headline == str(f.aimed.low), "a fixed damage shows as one number (%s)" % f.aimed.headline)
	ok(f.aimed.hp_before == foe.hp and f.aimed.hp_low == maxi(0, foe.hp - f.aimed.low), "the foe's HP after: %d -> %d" % [f.aimed.hp_before, f.aimed.hp_low])
	var before_hp := foe.hp
	DamageForecast.make(b, king, BattleAction.attack(), foe.cell)
	ok(foe.hp == before_hp and king.sp == king.max_sp(), "a forecast changes nothing")
	# marked and blind change the chance
	var plain_hit := DamageForecast.make(b, king, BattleAction.use(_skill("Quick Jab")), foe.cell).aimed.hit_percent
	foe.add_status(BattleUnit.MARKED, 2)
	var fm := DamageForecast.make(b, king, BattleAction.use(_skill("Quick Jab")), foe.cell)
	ok(fm.aimed.hit_percent >= plain_hit and fm.aimed.hit_percent <= 100, "a marked foe is hit at least as often by a physical skill (%d%% against %d%%)" % [fm.aimed.hit_percent, plain_hit])
	king.add_status(BattleUnit.MILD_BLIND, 2)
	var fb := DamageForecast.make(b, king, BattleAction.attack(), foe.cell)
	ok(fb.aimed.hit_percent < fm.aimed.hit_percent and fb.aimed.hit_percent >= BattleController.BLIND_FLOOR, "a blinded attacker lands less often (%d%%)" % fb.aimed.hit_percent)
	king.statuses.clear()
	foe.statuses.clear()
	# a physical skill rolls its band: a range
	var jab := DamageForecast.make(b, king, BattleAction.use(_skill("Quick Jab")), foe.cell)
	ok(jab.aimed.low < jab.aimed.high and jab.aimed.headline.contains("-"), "a skill that rolls shows a range (%s)" % jab.aimed.headline)
	var prod := DamageForecast.make(b, king, BattleAction.use(_skill("Shield Prod")), foe.cell)
	ok(prod.aimed.low == prod.aimed.high and prod.aimed.notes.has("Pushes 1"), "Shield Prod has a fixed multiplier and says it pushes (%s)" % [prod.aimed.notes])
	var kick := DamageForecast.make(b, king, BattleAction.use(_skill("Dirty Sand Kick")), foe.cell)
	ok(kick.aimed.notes.has("Mild Blind"), "a skill that gives a status names it (%s)" % [kick.aimed.notes])
	ok(jab.sp_cost == 3 and jab.action_name == "Quick Jab" and f.sp_cost == 0, "the SP cost and the action's name")
	# a knockout
	foe.hp = 1
	var ko := DamageForecast.make(b, king, BattleAction.attack(), foe.cell)
	ok(ko.aimed.may_ko and ko.aimed.ko and ko.aimed.hp_low == 0, "a hit that kills says so")
	foe.hp = foe.max_hp()
	# healing skills: a heal is 27 to 33 and never misses; the others say what they do instead of a number
	var cap := SampleParty.make().co_captains[0]
	var mate := b.deployment.deploy_co_captain(cap, Vector2i(2, 3))
	mate.hp = 10
	var heal := DamageForecast.make(b, king, BattleAction.use(_healing("heal")), mate.cell)
	ok(not heal.is_empty() and heal.aimed.target == mate and heal.aimed.heal, "Heal forecasts a heal on the teammate")
	ok(heal.aimed.hit_percent == 100 and heal.aimed.low == 27 and heal.aimed.high == 33 and heal.aimed.headline == "+27-33", "Heal: always lands, +27-33 (%s)" % heal.aimed.headline)
	ok(heal.aimed.hp_before == 10 and heal.aimed.hp_low == 37 and heal.aimed.hp_high == 43, "and the HP after is 37 to 43 (%d to %d)" % [heal.aimed.hp_low, heal.aimed.hp_high])
	var roulette := DamageForecast.make(b, king, BattleAction.use(_healing("roulette")), mate.cell)
	ok(roulette.aimed.headline == "50 / 50" and roulette.aimed.notes.has("Never KOs"), "HP Roulette says 50 / 50 and never KOs")
	var no_roulette := DamageForecast.make(b, king, BattleAction.use(_healing("roulette")), foe.cell)
	ok(no_roulette.is_empty(), "HP Roulette on an enemy forecasts nothing (teammates only)")
	var spit := DamageForecast.make(b, king, BattleAction.use(_healing("poison_spit")), foe.cell)
	ok(spit.aimed.headline == "50%" and spit.aimed.caption == "Poison", "Poison Spit shows its 50%% poison chance (%s / %s)" % [spit.aimed.headline, spit.aimed.caption])
	foe.hp = foe.max_hp()
	var hl := DamageForecast.Line.new()
	DamageForecast._text(hl, null)
	ok(hl.caption == "Damage", "the default caption is Damage")
	b.queue_free()
	await get_tree().process_frame


func _skill(n: String) -> SkillData:
	for s in SkillLibrary.physical():
		if s.display_name == n:
			return s
	return null


func _healing(support: String) -> SkillData:
	for s in SkillLibrary.healing():
		if s.support == support:
			return s
	return null


func stage() -> void:
	BattleStage.pending_game = FirstBattle.game()
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	add_child(s)
	await get_tree().create_timer(0.4).timeout
	while s.battle.current != null and s.battle.current.team != 0:
		await get_tree().process_frame
	var fp := s.hud.forecast
	ok(fp != null and not fp.visible and not fp.shown, "no prediction until a tile is aimed")
	s._on_action_chosen(BattleAction.attack())
	ok(not fp.shown, "choosing the attack alone shows none (no tile yet)")
	# aim at a tile that holds a foe if one is in reach, else the nearest reachable tile with a unit; place a foe in reach otherwise
	var king := s.battle.deployment.king
	var foe: BattleUnit = s.battle.enemies[0]
	var tile := Vector2i(king.cell.x + 1, king.cell.y)
	var reach := s.highlights.shown(TileHighlights.Kind.REACH)
	if not reach.is_empty():
		tile = reach[0]
	# move the foe onto the reach tile so there is a target
	s.grid.move_occupant(foe, tile)
	foe.cell = tile
	s.tap_cell(tile)
	ok(s.mode == BattleStage.Mode.CONFIRM, "a tile is aimed")
	ok(fp.shown and fp.visible, "the prediction slides out when a target is aimed")
	await get_tree().create_timer(0.5).timeout
	ok(is_equal_approx(fp.position.x, ForecastPanel.WIDTH * 0.0 + BattleHud.FORECAST_X) and fp.modulate.a > 0.95, "it rests at the HUD's left edge, fully shown (x %.0f)" % fp.position.x)
	ok(fp.name_label.text == foe.data.display_name, "it names the target (%s)" % fp.name_label.text)
	ok(fp.hit_value.text.ends_with("%") and fp.hit_value.text.to_int() >= BattleController.MIN_HIT and fp.big.text.to_int() > 0, "it shows the chance (%s) and the damage (%s)" % [fp.hit_value.text, fp.big.text])
	ok(fp.plaque_label.text == "ATTACK", "the plaque names the action (%s)" % fp.plaque_label.text)
	s.cancel()
	await get_tree().create_timer(0.5).timeout
	ok(not fp.shown and not fp.visible, "cancelling hides it again")
	s._on_action_chosen(BattleAction.attack())
	s.tap_cell(tile)
	ok(fp.shown, "aiming again brings it back")
	s.tap_cell(tile)  # confirm: performs
	await get_tree().create_timer(0.5).timeout
	ok(not fp.shown, "performing the action hides it")
	s.queue_free()
