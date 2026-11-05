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
	ok(Crucible.setup(3).flee.has("Vesper"), "Vesper flees on map 3")
	var stage := load("res://scenes/battle.tscn")
	ok(stage != null, "the battle scene loads")


func foes() -> void:
	var rank_d := 0
	for kind in Crucible.KINDS:
		var k: Dictionary = Crucible.KINDS[kind]
		var e := Crucible.enemy(kind, 2, 1)
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
		ok(r.skill.is_physical() and r.skill.rank <= SkillData.Rank.D, "a stone's skill is physical, E or D")
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
	Crucible.unlock_party(g)
	Crucible.unlock_party(g)
	eq(g.roster.co_captains.size(), 1, "Lyra becomes the Co-Captain, once")
	eq(g.roster.active_co_captain.display_name, "Lyra", "and she is the active one")
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


## The choice: deployed as the Co-Captain, Lyra cannot be summoned; with no Co-Captain chosen she is a vessel again.
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
	ok(dm2.owned_vessels.any(func(v): return v.display_name == "Lyra"), "without a Co-Captain in the field, Lyra is a vessel slot again")
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
