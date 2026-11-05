extends Node
## Headless: chapter two's five battles (Riverford): the maps (depth 16, up to 24 wide, varied tiles and heights), the setups (stones, a place for
## the Co-Captain, the foes), the enemies (their own stats, their own sprites, rank E skills only), Merc as a vessel, the waves and Vesper's flight.
## godot --headless --path godot res://tests/riverford_check.tscn
var fails := 0
var count := 0
const KNOWN := ["g", "d", "s", "m", "q", "c", "f", "h", "e", "o", "b", "w", "W", "t", "M", "r", "a"]


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_riverford"
	maps()
	enemies()
	merc()
	fleeing()
	await waves()
	print("riverford checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func maps() -> void:
	var tilesets := []
	var heights_seen := 0
	for n in range(1, 6):
		var label := "map %d (%s)" % [n, Riverford.NAMES[n]]
		var map := Terrain.load_map(Riverford.MAPS[n])
		eq(map.w, 16, "%s: depth 16" % label)
		ok(map.d >= 18 and map.d <= 24 and map.d % 2 == 0, "%s: %d wide (up to 24, even)" % [label, map.d])
		var codes := {}
		var heights := {}
		for y in map.d:
			for x in map.w:
				var t: Dictionary = map.tiles[y][x]
				codes[t.t] = true
				heights[t.h] = true
		ok(codes.keys().all(func(c): return c in KNOWN), "%s: known tiles (%s)" % [label, codes.keys()])
		ok(heights.size() >= 5, "%s: several levels of height (%d)" % [label, heights.size()])
		tilesets.append("".join(codes.keys()))
		heights_seen += heights.size()
		var s := Riverford.setup(n)
		eq(s.relics.size(), 3, "%s: three summon stones" % label)
		ok(s.captain_cell != TacticalGrid.NO_CELL, "%s: a place for the Co-Captain" % label)
		eq(s.enemies.size(), [4, 4, 4, 4, 4][n - 1], "%s: the foes" % label)
		var grid := TacticalGrid.from_map(map)
		ok(grid.is_passable(s.king_cell) and grid.is_passable(s.captain_cell) and s.relics.all(func(r): return grid.is_passable(r[1])) and s.enemies.all(func(e): return grid.is_passable(e[1])), "%s: everyone starts on open ground" % label)
		# the fight runs left to right: the sides are apart along y (the screen's horizontal)
		var ey := 0.0
		for e in s.enemies:
			ey += e[1].y
		ey /= s.enemies.size()
		if n == 4:
			ok(ey < s.king_cell.y - 5, "%s: Alaric starts on the right, the foes on the left" % label)
		else:
			ok(ey > s.king_cell.y + 5, "%s: Alaric starts on the left, the foes across" % label)
		eq(s.objective != "", true, "%s: has an objective" % label)
	var unique := {}
	for t in tilesets:
		unique[t] = true
	ok(unique.size() >= 4, "the maps differ in their tiles (%d different sets)" % unique.size())
	ok(Terrain.load_map(Riverford.MARKET).w == 19, "the market square is 19 x 19")
	eq(Riverford.setup(5).waves.size(), 2, "map 5 has two waves of reinforcements")
	ok(Riverford.setup(5).flee.has("Vesper") and Riverford.setup(5).flee_line.size() == 3, "map 5: Vesper flees, and says so")
	ok(Riverford.setup(1).waves.is_empty() and Riverford.setup(1).flee.is_empty(), "the others have neither")


func enemies() -> void:
	var seen := {}
	for kind in Riverford.KINDS:
		var k: Dictionary = Riverford.KINDS[kind]
		var e := Riverford.enemy(kind, 3, 1)
		ok(e.skills_only and not e.basic_attack_only and not e.skills.is_empty(), "%s uses only its own list of skills" % k.name)
		ok(e.skills.all(func(s): return s.rank == SkillData.Rank.E), "%s: every skill is rank E (%s)" % [k.name, e.skills.map(func(s): return s.display_name)])
		var sig := "%s/%s" % [var_to_str([k.hp, k.atk, k.def, k.mag, k.res, k.spd, k.will, k.move, k.jump]), var_to_str(e.skills.map(func(s): return s.display_name))]
		ok(not seen.has(sig), "%s has stats and skills of its own" % k.name)
		seen[sig] = true
		var sheet := UnitLook.sheet_for(e)
		ok(sheet != "" and (sheet != "squire" or kind in ["squire", "aide"]), "%s is drawn with %s" % [k.name, sheet])
		ok(e.stats.max_hp() >= 25 and e.stats.max_hp() <= 130, "%s: sensible HP (%d)" % [k.name, e.stats.max_hp()])
		ok(e.exp_reward > 0, "%s gives XP" % k.name)
	# fair: the stronger kinds are the slower or the fewer, and nothing out-hits the party's best by a mile
	var alaric := FirstBattle.game().roster.king.stats
	for kind in Riverford.KINDS:
		var k: Dictionary = Riverford.KINDS[kind]
		ok(int(k.atk) <= alaric.attack + 6 and int(k.def) <= alaric.defense + 5 and int(k.mag) <= 12, "%s: numbers stay near the party's (atk %d, def %d, mag %d)" % [k.name, k.atk, k.def, k.mag])
	ok(int(Riverford.KINDS.hound.spd) > int(Riverford.KINDS.guard.spd) and int(Riverford.KINDS.hound.hp) < int(Riverford.KINDS.guard.hp), "the fast kinds are fragile and the armoured ones slow")
	# the levels rise through the chapter
	ok(Riverford.ENEMY_LEVEL[1] < Riverford.ENEMY_LEVEL[5], "enemy levels rise through the chapter")
	# every map's summon stones carry rank E physical skills only
	for n in range(1, 6):
		for r in Riverford.setup(n).relics:
			ok(r[0].skill.rank == SkillData.Rank.E and r[0].skill.is_physical(), "map %d: the stone's skill is a rank E physical skill" % n)


func merc() -> void:
	var g := FirstBattle.chamber_game(FirstBattle.game())
	var before := g.roster.king.vessel_roster.size()
	Riverford.add_merc(g)
	Riverford.add_merc(g)
	eq(g.roster.king.vessel_roster.size(), before + 1, "Merc joins once")
	var m: VesselData = g.roster.king.vessel_roster.filter(func(v): return v.display_name == "Merc")[0]
	ok(m.loadout.relic_slot_1.skill != null and m.loadout.relic_slot_1.skill.rank == SkillData.Rank.E and m.loadout.relic_slot_2.skill.rank == SkillData.Rank.E, "Merc's relics carry rank E skills")
	# survives a save and load
	var codec := SaveCodec.encode(g)
	var back := SaveCodec.decode(codec)
	ok(back != null and back.game.roster.king.vessel_roster.any(func(v): return v.display_name == "Merc"), "Merc is still a vessel after a save and a load")


func _grid() -> TacticalGrid:
	var row := " ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"]))
	return TacticalGrid.from_rows([row, row, row, row, row, row, row, row])


## A unit with a flee percent is never knocked out; at that share of its HP it leaves the fight, and the battle can be won without it.
func fleeing() -> void:
	var grid := _grid()
	var b := BattleController.new()
	add_child(b)
	b.setup(grid)
	b.miss_chance = 0.0
	var kd := FirstBattle.game().roster.king.duplicate(true) as KingData
	kd.stats.attack = 70
	kd.loadout.weapon_style.geometry = TacticalMath.Geometry.KING  # a full-strength hit on the aimed tile
	var king := b.deployment.deploy_king(kd, Vector2i(1, 1))
	var vd := Riverford.enemy("vesper", 5, 1)
	vd.stats.speed = 1
	var foe := b.add_enemy(vd, Vector2i(1, 2))
	b.fleeing[foe] = 40
	var fled: Array = []
	b.unit_fled.connect(func(u): fled.append(u))
	b.start()
	b.next_turn()
	king.facing = Vector2i(0, 1)
	var r := b.perform(king, BattleAction.attack(), Vector2i(1, 2))
	ok(r.ok and foe.fled and foe.hp == 0 and fled == [foe], "a hit that takes Vesper to 40% HP or less makes Vesper flee")
	ok(not r.hits[0].knocked_out, "...and it never counts as a knockout")
	ok(not b.swords.has(Vector2i(1, 2)), "...and drops no sword")
	eq(b.outcome, BattleController.Outcome.WON, "with nobody else left, the battle is won")
	b.queue_free()
	# a hit that would kill is held to 1 HP first
	var b2 := BattleController.new()
	add_child(b2)
	b2.setup(_grid())
	b2.miss_chance = 0.0
	var kd2 := FirstBattle.game().roster.king.duplicate(true) as KingData
	kd2.stats.attack = 99
	kd2.loadout.weapon_style.geometry = TacticalMath.Geometry.KING
	var king2 := b2.deployment.deploy_king(kd2, Vector2i(1, 1))
	var vd2 := Riverford.enemy("vesper", 5, 2)
	vd2.stats.speed = 1
	var foe2 := b2.add_enemy(vd2, Vector2i(1, 2))
	var gd := Riverford.enemy("guard", 5, 3)
	gd.stats.speed = 1
	var other := b2.add_enemy(gd, Vector2i(3, 6))
	b2.fleeing[foe2] = 40
	b2.start()
	b2.next_turn()
	king2.facing = Vector2i(0, 1)
	var r2 := b2.perform(king2, BattleAction.attack(), Vector2i(1, 2))
	ok(r2.hits[0].amount < r2.hits[0].target.max_hp() and foe2.fled, "a killing blow is held back: Vesper flees instead of dying")
	eq(b2.outcome, BattleController.Outcome.ONGOING, "the battle goes on while another enemy stands")
	b2.queue_free()


## Waves arrive on their round, on a free tile (the nearest if the cell is taken), once.
func waves() -> void:
	BattleStage.pending_game = Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game()))
	BattleStage.pending_setup = Riverford.setup(5)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.animate = false
	s.enemy_delay = 1000.0
	add_child(s)
	await get_tree().process_frame
	var before := s.battle.enemies.size()
	s.round = 3
	await s._arrivals()
	eq(s.battle.enemies.size(), before + 2, "wave 1 brings two foes on round 3")
	await s._arrivals()
	eq(s.battle.enemies.size(), before + 2, "...once")
	s.round = 6
	await s._arrivals()
	eq(s.battle.enemies.size(), before + 4, "wave 2 brings two more on round 6")
	ok(s.battle.enemies.all(func(e): return e.cell != TacticalGrid.NO_CELL and s.grid.occupant(e.cell) == e), "every arrival stands on its own tile")
	s.queue_free()
	await get_tree().process_frame
