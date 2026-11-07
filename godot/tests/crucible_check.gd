extends Node
## Headless: chapter three (Crucible): three big maps on a new tileset, the foes (rank E and D skills, their own roles), the stones (some rank D), Gideon and
## Kaelen, and Lyra becoming a Co-Captain who is deployed as the Co-Captain or as a vessel, never both.
## godot --headless --path godot res://tests/crucible_check.tscn
var fails := 0
var count := 0
const NEW_TILES := ["M", "n", "a", "k", "l"]


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_crucible"
	maps()
	foes()
	party()
	await coop()
	await story_rules()
	print("crucible checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps() -> void:
	var seen_new := {}
	for n in range(1, 4):
		var label := "map %d (%s)" % [n, Crucible.NAMES[n]]
		var map := Terrain.load_map(Crucible.MAPS[n])
		eq(map.w, 16, "%s: depth 16" % label)
		ok(map.d >= 32 and map.d <= 40, "%s: big, %d wide (the camera scrolls)" % [label, map.d])
		var codes := {}
		var heights := {}
		for y in map.d:
			for x in map.w:
				codes[map.tiles[y][x].t] = true
				heights[map.tiles[y][x].h] = true
		for c in NEW_TILES:
			if codes.has(c):
				seen_new[c] = true
		ok(heights.size() >= 5, "%s: several levels (%d)" % [label, heights.size()])
		var s := Crucible.setup(n)
		eq(s.relics.size(), 3, "%s: three summon stones" % label)
		ok(s.captain_cell != TacticalGrid.NO_CELL and not s.enemies.is_empty() and not s.waves.is_empty(), "%s: a captain's place, foes and waves" % label)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "%s: everyone starts on open ground" % label)
	ok(seen_new.size() >= 5, "a tileset the game had not used (%s)" % [seen_new.keys()])
	ok(Terrain.load_map(Crucible.BASTION).w == 16, "the war room exists")
	ok(Crucible.setup(3).flee.has("Soul Warden"), "the Soul Warden withdraws on map 3")
	for n in [4, 5]:
		var bm := Terrain.load_map(Crucible.MAPS[n])
		eq(bm.w, 16, "map %d: depth 16" % n)
		ok(bm.d >= 20 and bm.d <= 26, "map %d: %d wide" % [n, bm.d])
		ok(not Crucible.setup(n).enemies.is_empty() and Crucible.setup(n).relics.size() == 3, "map %d: foes and three stones" % n)
	var stage := load("res://scenes/battle.tscn")
	ok(stage != null, "the battle scene loads")


func foes() -> void:
	var rank_d := 0
	for kind in Crucible.KINDS:
		var k: Dictionary = Crucible.KINDS[kind]
		var e := Crucible.enemy(kind, 2, 1)
		if e.behavior != "" or k.get("boss", false):
			ok(e.behavior != "" or e.skills.size() >= 4, "%s: a device or carrier acts by its own rules, a boss has his four arts" % k.name)
		else:
			ok(e.skills.all(func(s): return s.rank <= SkillData.Rank.D), "%s: rank E and D skills only" % k.name)
			rank_d += e.skills.filter(func(s): return s.rank == SkillData.Rank.D).size()
			ok(e.skills.any(func(s): return s.rank == SkillData.Rank.E), "%s: and mostly rank E" % k.name)
		var sheet := UnitLook.sheet_for(e)
		ok(sheet != "" and sheet != "squire" or kind == "x", "%s is drawn with %s" % [k.name, sheet])
	ok(rank_d >= 7, "rank D skills here and there (%d)" % rank_d)
	ok(Crucible.KINDS.runemage.role == "caster" and Crucible.KINDS.phalanx.role == "guardian", "the AI roles are set")
	# stones: mostly rank E, now and then rank D
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var d := 0
	for i in 200:
		var r := SummonStone.make(rng, Crucible.STONE_D_CHANCE)
		ok(r.skill.rank <= SkillData.Rank.D, "a stone's skill is rank E or D")
		if r.skill.rank == SkillData.Rank.D:
			d += 1
	ok(d > 30 and d < 100, "about a third of the stones carry a rank D skill (%d of 200)" % d)
	var e_only := true
	for i in 100:
		e_only = e_only and SummonStone.make(rng).skill.rank == SkillData.Rank.E
	ok(e_only, "stones made without a D chance (Riverford) stay rank E")


func party() -> void:
	var g := Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game()))
	ok(g.roster.co_captains.is_empty(), "no Co-Captain before chapter three")
	var vl: VesselData = g.roster.king.vessel_roster.filter(func(o): return o.display_name == "Lyra")[0]
	ok(vl != null, "before the story makes her human, Lyra is a vessel")
	vl.stats.add_exp(ExperienceCurve.total_to_reach(14) - vl.stats.total_exp, vl.loadout)
	var learned_skill := SkillLibrary.find("Arc Bolt")
	var m := SkillMastery.make(learned_skill)
	m.level = 3
	Mentorship.tree_of(vl).masteries.append(m)
	var vatk := vl.stats.attack
	Crucible.unlock_party(g)
	Crucible.unlock_party(g)
	eq(g.roster.co_captains.size(), 1, "Lyra becomes the Co-Captain, once")
	eq(g.roster.active_co_captain.display_name, "Lyra", "and she is the active one")
	ok(not g.roster.king.vessel_roster.any(func(v): return v.display_name == "Lyra"), "her vessel is deleted when she becomes human")
	var cap := g.roster.active_co_captain
	eq(cap.stats.level, 14, "the Co-Captain carries the vessel's level")
	eq(cap.stats.total_exp, vl.stats.total_exp, "...and experience")
	ok(cap.stats.attack >= vatk, "...and her attributes")
	ok(cap.skill_tree.skill_level(learned_skill) == 3, "...and every skill the vessel learned, at its level")
	ok(g.roster.king.vessel_roster.any(func(v): return v.display_name == "Gideon") and g.roster.king.vessel_roster.any(func(v): return v.display_name == "Kaelen"), "Gideon and Kaelen join")
	eq(g.roster.king.vessel_roster.filter(func(v): return v.display_name == "Gideon").size(), 1, "...once")
	for name in ["Gideon", "Kaelen"]:
		var v: VesselData = g.roster.king.vessel_roster.filter(func(o): return o.display_name == name)[0]
		ok(CharacterLook.base_of(v) != "", "%s has a sheet (%s)" % [name, CharacterLook.base_of(v)])
	ok(CharacterLook.base_of(g.roster.active_co_captain) == "mira", "Lyra the Co-Captain is drawn as Lyra")
	ok(g.roster.active_co_captain.signature_skills.size() == 3 and g.roster.active_co_captain.signature_skills.all(func(s): return s != null), "she has her three signature skills")
	var back := SaveCodec.decode(SaveCodec.encode(g))
	g.roster.stand_down = true
	ok(SaveCodec.decode(SaveCodec.encode(g)).game.roster.stand_down, "her standing down is saved")
	g.roster.stand_down = false
	ok(back != null and back.game.roster.co_captains.size() == 1 and back.game.roster.king.vessel_roster.any(func(v): return v.display_name == "Kaelen"), "all of it survives a save and a load")


## Once human, Lyra is never a vessel again (her vessel was merged into her).
func coop() -> void:
	var g := Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())))
	var dm := DeploymentManager.new()
	add_child(dm)
	CampaignFlow.prepare_deployment(g, dm)
	ok(not dm.owned_vessels.any(func(v): return v.display_name == "Lyra"), "with Lyra as the Co-Captain, she is not among the vessels to summon")
	ok(dm.owned_vessels.any(func(v): return v.display_name == "Bram") and dm.owned_vessels.any(func(v): return v.display_name == "Gideon"), "the others are")
	g.roster.stand_down = true
	var dm2 := DeploymentManager.new()
	add_child(dm2)
	CampaignFlow.prepare_deployment(g, dm2)
	ok(not dm2.owned_vessels.any(func(v): return v.display_name == "Lyra"), "standing her down does not bring a Lyra vessel back: she is human now")
	# in a real battle the Co-Captain stands on the field
	RosterManager.set_active_co_captain(g.roster, g.roster.co_captains[0])
	ok(not g.roster.stand_down, "choosing the Co-Captain again puts her back on the field")
	BattleStage.pending_game = g
	BattleStage.pending_setup = Crucible.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	add_child(s)
	await get_tree().process_frame
	ok(s.battle.deployment.co_captain != null and s.battle.deployment.co_captain.data.display_name == "Lyra", "Lyra the Co-Captain stands on the field")
	eq(s.scrolling, true, "a 32-wide map scrolls")
	s.queue_free()
	await get_tree().process_frame


func _stage(n: int) -> BattleStage:
	BattleStage.pending_game = Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)
	BattleStage.pending_setup = Crucible.setup(n)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	return s


func _unit(s: BattleStage, display_name: String) -> BattleUnit:
	for e in s.battle.enemies:
		if e.data.display_name == display_name:
			return e
	return null


## The new story's battle rules (ScenarioRules) and the Soul Warden's arts.
func story_rules() -> void:
	# Battle 1: three lantern bearers; knocking each down frees a spirit; carrying one off the map loses
	var s := _stage(1)
	await get_tree().process_frame
	ok(s.scenario != null and s.scenario.carriers_total == 3, "Battle 1: three spirits to free")
	for e in s.battle.enemies:
		if e.data.display_name == "Lantern Bearer":
			e.hp = 0
	s.scenario.check()
	eq(s.scenario.freed, 3, "Battle 1: three spirits freed")
	eq(s.battle.outcome, BattleController.Outcome.WON, "Battle 1: freeing all three wins, soldiers or not")
	s.queue_free()
	await get_tree().process_frame
	s = _stage(1)
	await get_tree().process_frame
	var b := _unit(s, "Lantern Bearer")
	var exit: Array = Crucible.setup(1).rules.carriers.exit[0]
	var ex := Vector2i(int(exit[0]), int(exit[1]))
	s.battle.grid.remove(b)
	s.battle.grid.place(b, ex, 1)
	b.cell = ex
	await s.scenario._carry_off(b)
	eq(s.scenario.escaped, 1, "Battle 1: a bearer reaching the arch is carried off")
	eq(s.battle.outcome, BattleController.Outcome.LOST, "Battle 1: and the battle is lost")
	s.queue_free()
	await get_tree().process_frame
	# Battle 2: the binders consume a spirit every third round
	s = _stage(2)
	await get_tree().process_frame
	for r in [3, 6, 9]:
		s.scenario.on_round(r)
	eq(s.scenario.consumed, 3, "Battle 2: three spirits consumed by round 9")
	eq(s.battle.outcome, BattleController.Outcome.ONGOING, "Battle 2: still fighting")
	s.scenario.on_round(12)
	eq(s.battle.outcome, BattleController.Outcome.LOST, "Battle 2: the fourth consumed loses")
	s.queue_free()
	await get_tree().process_frame
	s = _stage(2)
	await get_tree().process_frame
	for e in s.battle.enemies:
		if e.data.display_name == "Soul Binder":
			e.hp = 0
	s.scenario.check()
	eq(s.battle.outcome, BattleController.Outcome.WON, "Battle 2: all binders down wins")
	s.queue_free()
	await get_tree().process_frame
	# Battle 4: the apparatus drains Alaric each round until Lyra pushes back at half its strength; breaking it wins; Alaric down loses
	s = _stage(4)
	await get_tree().process_frame
	var king := s.battle.deployment.king
	var full := king.hp
	s.scenario.on_round(2)
	ok(king.hp < full, "Battle 4: the apparatus drains Alaric (%d of %d)" % [king.hp, full])
	var ap := _unit(s, "Ritual Apparatus")
	ap.hp = ap.max_hp() * 4 / 10
	s.scenario.check()
	var after := king.hp
	s.scenario.on_round(3)
	eq(king.hp, after, "Battle 4: at half strength the drain stops")
	ap.hp = 0
	s.scenario.check()
	eq(s.battle.outcome, BattleController.Outcome.WON, "Battle 4: the apparatus down wins")
	s.queue_free()
	await get_tree().process_frame
	s = _stage(4)
	await get_tree().process_frame
	s.battle.deployment.king.hp = 0
	s.scenario.check()
	eq(s.battle.outcome, BattleController.Outcome.LOST, "Battle 4: Alaric down loses")
	s.queue_free()
	await get_tree().process_frame
	# Battle 5: the Warden's four arts, Lyra unbound, a telegraphed judgment that lands next turn
	s = _stage(5)
	await get_tree().process_frame
	var w := _unit(s, "Soul Warden")
	ok(w != null and ["Soul Lantern", "Judgment Chains", "Ether Drain", "Final Absolution"].all(func(n): return w.data.skills.any(func(k): return k.display_name == n)), "Battle 5: the Warden has his four arts")
	var lyra_unit := s.battle.deployment.co_captain
	ok(SkillFx.soul_immune(lyra_unit), "Lyra, living, is out of reach of the soul arts")
	var lantern := SkillLibrary.find("Soul Lantern")
	var h := ActionResult.Hit.new()
	h.target = lyra_unit
	var res := ActionResult.new()
	res.hits = [h]
	SkillFx.apply(s.battle, w, lantern, res, RandomNumberGenerator.new())
	ok(not lyra_unit.has_status(BattleUnit.SILENCE) and h.notes.has("Unbound"), "Soul Lantern cannot silence Lyra")
	var kingu := s.battle.deployment.king
	kingu.cell = kingu.cell  # keep him where he is
	h.target = kingu
	h.notes.clear()
	SkillFx.apply(s.battle, w, lantern, res, RandomNumberGenerator.new())
	ok(not kingu.has_status(BattleUnit.SILENCE), "Soul Lantern works on vessels only")
	# the judgment: aimed on one turn, nothing happens yet; it lands on the Warden's next turn
	var absolution := SkillLibrary.find("Final Absolution")
	ok(absolution != null and SkillFx.flag(absolution, "telegraph"), "Final Absolution is telegraphed")
	s.battle.grid.move_occupant(w, Vector2i(kingu.cell.x, kingu.cell.y + 3))  # the Warden steps up to the party for this check
	w.cell = Vector2i(kingu.cell.x, kingu.cell.y + 3)
	s.battle.current = w
	s.battle.acted = false
	w.sp = 20
	var reach := s.battle.highlights(w, BattleAction.use(absolution))
	ok(not reach.is_empty(), "the Warden can aim Final Absolution somewhere")
	var aim: Vector2i = reach[0]
	s.battle.grid.move_occupant(kingu, aim)  # Alaric stands on the marked ground
	kingu.cell = aim
	var king_hp := kingu.hp
	var r1 := s.battle.perform(w, BattleAction.use(absolution), aim)
	ok(r1.ok and r1.hits.is_empty() and s.battle.telegraphs.size() == 1, "Final Absolution is only marked at first (%s)" % r1.error)
	eq(kingu.hp, king_hp, "nobody is hurt on the turn it is aimed")
	s.battle.acted = false
	ok(s.battle.action_error(w, BattleAction.use(absolution), aim) != "", "he cannot charge a second one while one is waiting")
	s.battle.miss_chance = 0.0
	var landed := s.battle.land_telegraphs(w)
	ok(landed.size() == 1 and kingu.hp < king_hp, "it lands on his next turn and hurts whoever stayed (%d to %d)" % [king_hp, kingu.hp])
	s.queue_free()
	await get_tree().process_frame
