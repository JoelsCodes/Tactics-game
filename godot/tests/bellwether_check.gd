extends Node
## Headless: chapter five (Bellwether): five maps, rank D and C enemy skills (chapter four's carry D), the world-map wiring, and above all Battle 4: only Alaric and
## Lyra fight, no vessel can be summoned, Alaric starts weakened, and none of it outlives the battle (the save is untouched, Battle 5 summons normally).
## godot --headless --path godot res://tests/bellwether_check.tscn
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
	SaveSystem.dir = "user://test_saves_bellwether"
	maps_and_foes()
	ranks()
	world()
	await battle_four()
	await battle_five()
	print("bellwether checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _game() -> SaveGame:
	return Mountain.recruit(Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())), false))


func maps_and_foes() -> void:
	for n in range(1, 6):
		var map := Terrain.load_map(Bellwether.MAPS[n])
		eq(map.w, 16, "map %d (%s): depth 16" % [n, Bellwether.NAMES[n]])
		ok(map.d >= 18 and map.d <= 24, "map %d: %d wide" % [n, map.d])
		var s := Bellwether.setup(n)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and s.enemies.all(func(e): return grid.is_passable(e[1])), "map %d: everyone starts on open ground" % n)
		ok(s.objective == "Defeat all enemies" and s.rules.keys().all(func(k): return k == "king_hp_pct"), "map %d: a plain defeat-all-enemies battle (no objective rules)" % n)
		ok(not s.opening_line.is_empty(), "map %d: an opening bark" % n)
	ok(Terrain.load_map(Bellwether.TOWN).w == 16, "the festival square exists")
	ok(Bellwether.setup(5).enemies.any(func(e): return e[0].display_name == "The Deepdweller"), "Battle 5 has the mine's titan")
	for kind in Bellwether.KINDS:
		ok(UnitLook.sheet_for(Bellwether.enemy(kind, 1, 1)) != "", "%s has a sheet" % Bellwether.KINDS[kind].name)


func ranks() -> void:
	# chapter four's foes use rank D skills as a matter of course; chapter five's use rank D and C
	var d4 := 0
	for kind in Mountain.KINDS:
		var e := Mountain.enemy(kind, 2, 1)
		if e.behavior == "" and not Mountain.KINDS[kind].get("boss", false):
			ok(e.skills.any(func(s): return s.rank == SkillData.Rank.D), "chapter four: %s has a rank D skill" % Mountain.KINDS[kind].name)
			d4 += 1
	ok(d4 >= 10, "chapter four: %d kinds checked" % d4)
	var c5 := 0
	for kind in Bellwether.KINDS:
		var e := Bellwether.enemy(kind, 3, 1)
		ok(e.skills.all(func(s): return s.rank <= SkillData.Rank.C), "chapter five: %s stays at rank C or lower" % Bellwether.KINDS[kind].name)
		ok(e.skills.any(func(s): return s.rank == SkillData.Rank.C), "chapter five: %s has a rank C skill" % Bellwether.KINDS[kind].name)
		ok(e.skills.any(func(s): return s.rank <= SkillData.Rank.D), "chapter five: %s has rank D (or E) skills too" % Bellwether.KINDS[kind].name)
		if e.skills.any(func(s): return s.rank == SkillData.Rank.C):
			c5 += 1
	eq(c5, Bellwether.KINDS.size(), "chapter five: every kind has rank C")


func world() -> void:
	var c := CampaignState.new()
	ok(not c.is_area_unlocked(&"bellwether"), "Bellwether is locked at first")
	WorldData.clear_map(c, "wrath")
	WorldData.clear_map(c, "judgment")
	WorldData.clear_map(c, "mheart")
	ok(c.is_area_unlocked(&"bellwether"), "clearing the Mountain's Heart opens Bellwether")
	eq(WorldData.map_state(c, "bwroad"), "mission", "its first battle is the next mission")
	eq(WorldData.scene_for(c, "bwroad", "pre"), "bw_arrival", "the first click plays the festival")
	c.mark_scene_seen(&"bw_toy")
	c.mark_scene_seen(&"bw_arrival")  # the chain ends in bw_toy, which marks both (also_seen)
	eq(WorldData.scene_for(c, "bwroad", "pre"), "bw_road_pre", "the second plays the ambush's scene")
	for id in ["bwroad", "bwquarry", "bwmine", "bwhollow", "bwstay"]:
		ok(WorldData.setup_for(id, 1, false) != null, "%s starts a battle" % id)


func _stage(n: int, g: SaveGame) -> BattleStage:
	BattleStage.pending_game = g
	BattleStage.pending_setup = Bellwether.setup(n)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 1000.0
	s.animate = false
	add_child(s)
	return s


func battle_four() -> void:
	var g := _game()
	g.roster.stand_down = true  # even a player who stood Lyra down finds her on the field here
	var before := SaveCodec.encode(g)
	var setup := Bellwether.setup(4)
	eq(setup.max_summons, 0, "Battle 4: no summons allowed")
	eq(setup.relics.size(), 0, "Battle 4: no summon stones")
	var s := _stage(4, g)
	await get_tree().process_frame
	var dm := s.battle.deployment
	ok(dm.king != null and dm.co_captain != null and dm.co_captain.data.display_name == "Lyra", "Battle 4: Alaric and Lyra are on the field")
	eq(dm.field_units().size(), 2, "Battle 4: nobody else is")
	eq(dm.summons_left(), 0, "Battle 4: no summons left")
	var v: VesselData = g.roster.vessels().filter(func(x): return x.display_name == "Bram").front()
	ok(not dm.can_summon(v, Vector2i(6, 3)), "Battle 4: a vessel cannot be summoned")
	ok(dm.king.hp * 100 <= dm.king.max_hp() * (Bellwether.WEAKENED_PERCENT + 1) and dm.king.hp < dm.king.max_hp(), "Battle 4: Alaric starts weakened (%d of %d)" % [dm.king.hp, dm.king.max_hp()])
	ok(dm.co_captain.hp == dm.co_captain.max_hp(), "Battle 4: Lyra is at full strength")
	ok(s.battle.enemies.size() <= 5, "Battle 4: a small group (%d)" % s.battle.enemies.size())
	s.queue_free()
	await get_tree().process_frame
	# temporary: the save is exactly as it was, every vessel still owned, the stand-down flag as the player set it
	eq(SaveCodec.encode(g), before, "Battle 4: the save is untouched by the restriction")
	ok(g.roster.stand_down, "Battle 4: the player's own stand-down setting is not changed")
	for name in ["Bram", "Merc", "Gideon", "Kaelen"]:
		ok(g.roster.vessels().any(func(x): return x.display_name == name), "Battle 4: %s is still owned" % name)


func battle_five() -> void:
	var g := _game()
	var setup := Bellwether.setup(5)
	eq(setup.max_summons, 6, "Battle 5: normal summoning is back")
	eq(setup.relics.size(), 3, "Battle 5: the summon stones are back")
	ok(setup.rules.is_empty(), "Battle 5: no leftover restriction")
	var s := _stage(5, g)
	await get_tree().process_frame
	var dm := s.battle.deployment
	eq(dm.summons_left(), 6, "Battle 5: six summons")
	ok(dm.king.hp == dm.king.max_hp(), "Battle 5: Alaric is whole again")
	ok(dm.owned_vessels.any(func(x): return x.display_name == "Gideon") and dm.owned_vessels.any(func(x): return x.display_name == "Kaelen"), "Battle 5: the whole company can be summoned")
	s.queue_free()
	await get_tree().process_frame
