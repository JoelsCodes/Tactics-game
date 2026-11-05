extends Node
## Headless: chapter four (Mountain): five maps, the foes, the battle rules (war standards, the memorial, the Hollow Heart's echoes and arts), Gideon and
## Kaelen as temporary allies in Battle 5 and as recruits only after the final scene, and the world-map wiring.
## godot --headless --path godot res://tests/mountain_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_mountain"
	maps_and_foes()
	world()
	await rules()
	await recruitment()
	print("mountain checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps_and_foes() -> void:
	for n in range(1, 6):
		var map := Terrain.load_map(Mountain.MAPS[n])
		eq(map.w, 16, "map %d (%s): depth 16" % [n, Mountain.NAMES[n]])
		ok(map.d >= 22 and map.d <= 32, "map %d: %d wide" % [n, map.d])
		var s := Mountain.setup(n)
		eq(s.relics.size(), 3, "map %d: three summon stones" % n)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "map %d: everyone starts on open ground" % n)
		ok(s.objective != "" and not s.opening_line.is_empty(), "map %d: an objective and an opening bark" % n)
	for kind in Mountain.KINDS:
		var k: Dictionary = Mountain.KINDS[kind]
		var e := Mountain.enemy(kind, 2, 1)
		if e.behavior == "" and not k.get("boss", false):
			ok(e.skills.all(func(s): return s.rank <= SkillData.Rank.D) and not e.skills.is_empty(), "%s: rank E and D skills" % k.name)
		var sheet := UnitLook.sheet_for(e)
		ok(sheet != "", "%s is drawn with %s" % [k.name, sheet])
	var heart := Mountain.enemy("heart", 5, 1)
	ok(["Griefbound", "Unbroken Oath", "Final Lament"].all(func(n): return heart.skills.any(func(s): return s.display_name == n)), "the Hollow Heart has Griefbound, Unbroken Oath and Final Lament")
	ok(Mountain.setup(2).flee.has("Kaelen") and Mountain.setup(4).flee.has("Gideon"), "Kaelen and Gideon yield instead of dying")
	var scene_ids := MountainStory.SCENES.keys()
	for k in ["mt_road", "mt_pass_pre", "mt_pass_post", "mt_scout_pre", "mt_scout_post", "mt_siege_pre", "mt_siege_post", "mt_last_pre", "mt_last_post", "mt_heart_pre", "mt_heart_post", "mt_oath", "mt_ahead"]:
		ok(scene_ids.has(k), "scene %s exists" % k)


func world() -> void:
	var c := CampaignState.new()
	ok(not c.is_area_unlocked(&"mountain"), "the mountain is locked at first")
	WorldData.clear_map(c, "wrath")
	WorldData.clear_map(c, "judgment")
	ok(c.is_area_unlocked(&"mountain"), "clearing the Warden's Judgment opens the Forgotten Mountain")
	eq(WorldData.map_state(c, "mpass"), "mission", "its first battle is the next mission")
	eq(WorldData.scene_for(c, "mpass", "pre"), "mt_road", "the first click plays the road scene, which chains into the pass")
	eq(WorldData.scene_for(c, "mheart", "post"), "mt_heart_post", "the last battle ends with the soldiers passing on")
	for id in ["mpass", "mscout", "msiege", "mlast", "mheart"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)


func _stage(n: int, g: SaveGame = null) -> BattleStage:
	BattleStage.pending_game = g if g != null else Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)
	BattleStage.pending_setup = Mountain.setup(n)
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


func rules() -> void:
	# Battle 3: three war standards, a soldier called by each every third round; all three down wins
	var s := _stage(3)
	await get_tree().process_frame
	eq(s.battle.enemies.filter(func(e): return e.data.display_name == "War Standard").size(), 3, "Battle 3: three war standards")
	var before := s.battle.enemies.size()
	s.scenario.on_round(3)
	eq(s.battle.enemies.size(), before + 3, "Battle 3: each standard calls one soldier on round 3")
	s.scenario.on_round(4)
	eq(s.battle.enemies.size(), before + 3, "Battle 3: none on round 4")
	var first := _unit(s, "War Standard")
	first.hp = 0
	s.scenario.on_round(6)
	eq(s.battle.enemies.size(), before + 5, "Battle 3: a fallen standard calls no more")
	for e in s.battle.enemies:
		if e.data.display_name == "War Standard":
			e.hp = 0
	s.scenario.check()
	eq(s.battle.outcome, BattleController.Outcome.WON, "Battle 3: all standards down wins, soldiers or not")
	s.queue_free()
	await get_tree().process_frame
	# Battle 4: the memorial must not fall; Gideon and his guard down wins
	s = _stage(4)
	await get_tree().process_frame
	var mem := _unit(s, "The Memorial")
	for e in s.battle.enemies:
		if e != mem:
			e.hp = 0
	s.scenario.check()
	eq(s.battle.outcome, BattleController.Outcome.WON, "Battle 4: everyone but the memorial down wins")
	s.queue_free()
	await get_tree().process_frame
	s = _stage(4)
	await get_tree().process_frame
	mem = _unit(s, "The Memorial")
	for e in s.battle.enemies:
		e.hp = 0  # even if the memorial was the last to fall
	s.scenario.check()
	eq(s.battle.outcome, BattleController.Outcome.LOST, "Battle 4: the memorial falling loses, even as the last enemy")
	s.queue_free()
	await get_tree().process_frame
	# Battle 5: echoes every third round, the Heart's arts, Gideon and Kaelen summonable only here
	s = _stage(5)
	await get_tree().process_frame
	var dm := s.battle.deployment
	ok(dm.owned_vessels.any(func(v): return v.display_name == "Gideon") and dm.owned_vessels.any(func(v): return v.display_name == "Kaelen"), "Battle 5: Gideon and Kaelen can be summoned")
	ok(not s.game.roster.vessels().any(func(v): return v.display_name == "Gideon" or v.display_name == "Kaelen"), "Battle 5: but they are not in the roster yet")
	var n0 := s.battle.enemies.size()
	s.scenario.on_round(3)
	eq(s.battle.enemies.size(), n0 + 2, "Battle 5: Echoes of War calls two soldiers on round 3")
	var heart := _unit(s, "Hollow Heart")
	var lament := SkillLibrary.find("Final Lament")
	ok(lament != null and SkillFx.flag(lament, "telegraph"), "Final Lament is telegraphed")
	var grief := SkillLibrary.find("Griefbound")
	ok(grief != null and SkillFx.flag(grief, "vessels_only"), "Griefbound weakens spirits only")
	s.battle.grid.move_occupant(heart, Vector2i(s.battle.deployment.king.cell.x, s.battle.deployment.king.cell.y + 3))
	heart.cell = Vector2i(s.battle.deployment.king.cell.x, s.battle.deployment.king.cell.y + 3)
	s.battle.current = heart
	s.battle.acted = false
	heart.sp = 30
	var reach := s.battle.highlights(heart, BattleAction.use(lament))
	ok(not reach.is_empty(), "the Heart can aim Final Lament")
	var r1 := s.battle.perform(heart, BattleAction.use(lament), reach[0])
	ok(r1.ok and r1.hits.is_empty() and s.battle.telegraphs.size() == 1, "Final Lament is marked first, not struck (%s)" % r1.error)
	s.queue_free()
	await get_tree().process_frame


func recruitment() -> void:
	var g := Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false)
	ok(not g.roster.vessels().any(func(v): return v.display_name == "Gideon"), "before the final scene Gideon is not a recruit")
	Mountain.recruit(g)
	Mountain.recruit(g)
	eq(g.roster.vessels().filter(func(v): return v.display_name == "Gideon").size(), 1, "Gideon joins once")
	ok(g.roster.vessels().any(func(v): return v.display_name == "Kaelen"), "Kaelen joins")
