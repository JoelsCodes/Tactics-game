extends Node
## Headless checks for the board layer (scripts/board): godot --headless --path godot res://tests/board_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


class Body:
	var down := false

	func is_down() -> bool:
		return down


func _ready() -> void:
	grid_and_walking()
	geometries()
	stances()
	projection()
	print("board checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## 7 x 7 flat grass with a few features
func flat(n := 7) -> TacticalGrid:
	var rows := []
	for y in n:
		var r := []
		for x in n:
			r.append("g0")
		rows.append(" ".join(r))
	return TacticalGrid.from_rows(rows)


func grid_and_walking() -> void:
	var g := TacticalGrid.from_rows([
		"g0 g0 g0 g0 g0",
		"g0 t0 g0 W0 g0",
		"g0 g0 g3 g0 g0",
		"g0 w0 g1 g0 g0",
		"g0 g0 g0 g0 v0",
	])
	eq([g.width, g.depth], [5, 5], "size")
	ok(g.in_bounds(Vector2i(4, 4)) and not g.in_bounds(Vector2i(5, 0)) and not g.in_bounds(Vector2i(0, -1)), "bounds")
	eq(g.height(Vector2i(2, 2)), 3, "height")
	ok(not g.is_passable(Vector2i(1, 1)) and g.is_obstacle(Vector2i(1, 1)), "tree blocks")
	ok(not g.is_passable(Vector2i(3, 1)) and not g.is_obstacle(Vector2i(3, 1)), "deep water: no standing, no line block")
	ok(g.is_void(Vector2i(4, 4)), "sky is void")
	g.add_obstacle(Vector2i(0, 4))
	ok(not g.can_stand(Vector2i(0, 4)), "placed obstacle")
	g.remove_obstacle(Vector2i(0, 4))
	ok(g.place("ally", Vector2i(1, 0), 0), "place")
	ok(not g.place("x", Vector2i(1, 0), 0), "no stacking")
	ok(not g.place("ally", Vector2i(2, 0), 0), "no double place")
	ok(g.place("foe", Vector2i(0, 2), 1), "place foe")
	eq(g.team_at(Vector2i(0, 2)), 1, "team at")
	eq(g.cell_of("ally"), Vector2i(1, 0), "cell of")
	ok(g.move_occupant("ally", Vector2i(2, 0)) and g.occupant(Vector2i(2, 0)) == "ally" and not g.is_occupied(Vector2i(1, 0)), "move occupant")
	ok(g.move_occupant("ally", Vector2i(1, 0)), "move back")

	# walking from (0,0), team 0, Move 4, Jump 1
	var r := g.reachable(Vector2i(0, 0), 4, 1, 0)
	ok(r.can_reach(Vector2i(0, 0)), "origin reachable")
	ok(not r.can_reach(Vector2i(1, 0)), "cannot end on an ally")
	ok(r.can_reach(Vector2i(2, 0)), "passes through an ally")
	ok(not r.can_reach(Vector2i(0, 2)) and not r.can_reach(Vector2i(0, 3)), "foe blocks the column")
	ok(not r.can_reach(Vector2i(2, 2)), "jump 1 cannot climb 3")
	eq(r.cost_to(Vector2i(4, 0)), 4, "cost along the top row")
	eq(r.path_to(Vector2i(3, 0)), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "path through ally")
	var r2 := g.reachable(Vector2i(0, 4), 3, 1, 1)
	eq(r2.cost_to(Vector2i(1, 3)), 3, "shallow water costs 2")
	ok(not g.reachable(Vector2i(0, 0), 4, 3, 0).can_reach(Vector2i(2, 2)), "even a high JUMP cannot climb 3 (only one level up)")
	# knocked-out bodies of any team can be walked through, never stood on
	var foe_body := Body.new()
	var r3 := g.reachable(Vector2i(0, 0), 4, 1, 1)  # team 1 path through the team-0 ally at (1, 0) is blocked
	ok(not r3.can_reach(Vector2i(2, 0)), "standing unit of another team blocks")
	g.remove("ally")
	g.place(foe_body, Vector2i(1, 0), 0)
	ok(not foe_body.down and not g.is_body(Vector2i(1, 0)), "standing: not a body")
	foe_body.down = true
	ok(g.is_body(Vector2i(1, 0)), "knocked out: a body")
	var r4 := g.reachable(Vector2i(0, 0), 4, 1, 1)
	ok(r4.can_reach(Vector2i(2, 0)), "walks through another team's body")
	ok(not r4.can_reach(Vector2i(1, 0)), "cannot end on a body")
	eq(r4.path_to(Vector2i(2, 0)), [Vector2i(1, 0), Vector2i(2, 0)], "path goes over the body")
	g.remove(foe_body)
	g.place("ally", Vector2i(1, 0), 0)
	eq(g.find_path(Vector2i(0, 0), Vector2i(4, 3), 1, 0).back(), Vector2i(4, 3), "find path ends at target")
	eq(g.find_path(Vector2i(0, 0), Vector2i(2, 2), 1, 0), [] as Array[Vector2i], "no path up a cliff")


func geometries() -> void:
	var g := flat()
	var o := Vector2i(3, 3)
	var rook := GeometryPattern.build(TacticalMath.Geometry.ROOK, 3)
	eq(GeometryResolver.targetable(g, o, rook).size(), 12, "rook on open board")
	var bishop := GeometryPattern.build(TacticalMath.Geometry.BISHOP, 8)
	eq(GeometryResolver.targetable(g, o, bishop).size(), 12, "bishop clipped by edges")
	var knight := GeometryPattern.build(TacticalMath.Geometry.KNIGHT, 1)
	eq(GeometryResolver.targetable(g, o, knight).size(), 8, "knight jumps")
	eq(GeometryResolver.targetable(g, Vector2i(0, 0), knight).size(), 2, "knight in the corner")
	var queen := GeometryPattern.build(TacticalMath.Geometry.QUEEN, 1)
	eq(GeometryResolver.targetable(g, o, queen).size(), 8, "queen 1")
	var pawn := GeometryPattern.build(TacticalMath.Geometry.PAWN, 1, Vector2i(1, 0))
	eq(GeometryResolver.targetable(g, o, pawn), [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 2)], "pawn faces +x")

	# blocking: a unit stops the ray (and can be hit), an obstacle stops it (and cannot)
	g.place("foe", Vector2i(3, 1), 1)
	g.place("pal", Vector2i(5, 3), 0)
	g.add_obstacle(Vector2i(3, 5))
	var t := GeometryResolver.targetable(g, o, rook)
	ok(t.has(Vector2i(3, 2)) and t.has(Vector2i(3, 1)) and not t.has(Vector2i(3, 0)), "unit ends ray")
	ok(t.has(Vector2i(3, 4)) and not t.has(Vector2i(3, 5)) and not t.has(Vector2i(3, 6)), "obstacle ends ray")
	ok(t.has(Vector2i(5, 3)) and not t.has(Vector2i(6, 3)), "ally ends ray too")
	eq(GeometryResolver.in_reach(g, o, rook, -1, 0), ["foe"], "foes in reach")
	eq(GeometryResolver.in_reach(g, o, rook).size(), 2, "everyone in reach")
	var mv := GeometryResolver.move_tiles(g, o, rook)
	ok(not mv.has(Vector2i(3, 1)) and mv.has(Vector2i(3, 2)), "moves do not land on units")
	g.add_obstacle(Vector2i(4, 4))
	ok(GeometryResolver.targetable(g, o, knight).has(Vector2i(5, 4)), "knight jumps over obstacles")

	# height: a wall more than vertical_reach above stops the ray; low ground is skipped but passed
	var h := TacticalGrid.from_rows(["g0 g5 g0 g0", "g0 g0 g0 g0", "g0 g0 g0 g0", "g4 g0 g0 g0"])
	var hr := GeometryPattern.build(TacticalMath.Geometry.ROOK, 3)
	var ht := GeometryResolver.targetable(h, Vector2i(0, 0), hr)
	ok(not ht.has(Vector2i(1, 0)) and not ht.has(Vector2i(2, 0)), "cliff is a wall")
	ok(ht.has(Vector2i(0, 2)) and not ht.has(Vector2i(0, 3)), "height 4 out of reach 3")
	var top := GeometryResolver.targetable(h, Vector2i(1, 0), hr)
	ok(not top.has(Vector2i(2, 0)) and top.has(Vector2i(1, 1)) == false, "5 levels down is out of reach")
	hr.vertical_reach = 5
	ok(GeometryResolver.targetable(h, Vector2i(1, 0), hr).has(Vector2i(3, 0)), "more vertical reach")


## The footprint of each stance (StanceRules.footprint), for a Rook style of reach 2. A unit's stance is
## fixed for the whole battle, so each case is its own footprint, not a switch.
func stances() -> void:
	var style := WeaponStyle.new()
	style.geometry = TacticalMath.Geometry.ROOK
	style.reach = 2
	var g := flat()
	var o := Vector2i(3, 3)
	g.place("a", Vector2i(3, 1), 1)
	g.place("b", Vector2i(3, 0), 1)
	var fp := func(st: WeaponStyle.Stance, skill: SkillData = null) -> GeometryPattern:
		return StanceRules.footprint(style, st, Vector2i(0, 1), 3, skill)
	var pierce: GeometryPattern = fp.call(WeaponStyle.Stance.PIERCE)
	eq(pierce.reach, 3, "pierce reach +1")
	eq(pierce.pierce, 1, "pierce carries on")
	var area := GeometryResolver.affected(g, o, pierce, Vector2i(3, 1))
	eq(area.tiles, [Vector2i(3, 1), Vector2i(3, 0)], "pierce tiles")
	eq(area.occupants, ["a", "b"], "pierce hits the unit behind")
	var axe: GeometryPattern = fp.call(WeaponStyle.Stance.AXE)
	eq(axe.reach, 2, "axe reach")
	area = GeometryResolver.affected(g, o, axe, Vector2i(3, 1))
	eq(area.tiles, [Vector2i(3, 1), Vector2i(4, 1), Vector2i(2, 1)], "axe cleaves sideways")
	var impact: GeometryPattern = fp.call(WeaponStyle.Stance.IMPACT)
	eq(impact.reach, 1, "impact reach -1")
	eq(GeometryResolver.targetable(g, o, impact).size(), 4, "impact footprint shrinks")
	area = GeometryResolver.affected(g, o, impact, Vector2i(3, 2))
	eq(area.tiles.size(), 4, "impact cross (origin excluded)")
	ok(not area.tiles.has(o), "never hits yourself")
	eq(area.occupants, ["a"], "impact splash hits neighbour")
	ok(GeometryResolver.affected(g, o, impact, Vector2i(0, 0)).is_empty(), "aim out of reach does nothing")
	# damage: physical scaled by stance, other proficiencies untouched, SP cost fixed
	eq(StanceRules.scale_damage(20, StanceRules.damage_percent(WeaponStyle.Stance.IMPACT, area, Vector2i(3, 2))), 20, "impact main 100%")
	eq(StanceRules.scale_damage(20, StanceRules.damage_percent(WeaponStyle.Stance.IMPACT, area, Vector2i(3, 1))), 10, "impact splash 50%")
	var phys := SkillData.new()
	phys.sp_cost = 4
	var mag := SkillData.new()
	mag.sp_cost = 4
	mag.category = Proficiency.Category.ELEMENTAL
	var bare: GeometryPattern = fp.call(WeaponStyle.Stance.IMPACT, mag)
	eq(bare.reach, 2, "other proficiencies use the bare footprint")
	eq(bare.splash, GeometryPattern.Splash.NONE, "no stance splash for them")
	eq((fp.call(WeaponStyle.Stance.IMPACT, phys) as GeometryPattern).splash, GeometryPattern.Splash.CROSS, "physical skills use the stance")
	var ax := GeometryResolver.affected(g, o, fp.call(WeaponStyle.Stance.AXE, phys), Vector2i(3, 1))
	eq(StanceRules.scale_damage(20, StanceRules.damage_percent(WeaponStyle.Stance.AXE, ax, Vector2i(3, 1))), 22, "axe main 110%")
	eq(StanceRules.scale_damage(1, StanceRules.damage_percent(WeaponStyle.Stance.AXE, ax, Vector2i(4, 1))), 1, "at least 1 damage")
	var pa := GeometryResolver.affected(g, o, pierce, Vector2i(3, 1))
	eq(StanceRules.scale_damage(20, StanceRules.damage_percent(WeaponStyle.Stance.PIERCE, pa, Vector2i(3, 0))), 15, "pierce behind 75%")
	eq([phys.sp_cost, mag.sp_cost], [4, 4], "stances never change SP costs")
	eq(GeometryPattern.build(TacticalMath.Geometry.PAWN, 1, Vector2i(0, -1)).offsets(), [Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, -1)], "pawn facing -y")
	var k := StanceRules.apply(GeometryPattern.build(TacticalMath.Geometry.KNIGHT, 1), WeaponStyle.Stance.IMPACT)
	ok(k.jumps and k.reach == 1 and k.rays.size() == 8, "knight keeps its jumps under impact")
	eq(ClassDB.class_exists("StanceComponent") or ResourceLoader.exists("res://scripts/board/stance_component.gd"), false, "no stance-switching component")


func projection() -> void:
	eq(IsoProjection.rotate(Vector2(1, 0), 1, 4, 3), Vector2(2, 1), "rotate")
	eq(IsoProjection.rotate(IsoProjection.rotate(Vector2(1, 2), 2, 5, 5), 2, 5, 5), Vector2(1, 2), "two half turns")
	var g := flat(3)
	for rot in 4:
		for y in 3:
			for x in 3:
				var c := Vector2i(x, y)
				var p := IsoProjection.to_world(Vector2(c), g.height(c), rot, 3, 3)
				eq(IsoProjection.pick(g, p, rot), c, "pick centre of %s rot %d" % [c, rot])
	eq(IsoProjection.pick(g, Vector2(5000, 5000), 0), TacticalGrid.NO_CELL, "pick off the board")
	var hill := TacticalGrid.from_rows(["g0 g0 g0", "g0 g2 g0", "g0 g0 g0"])
	var behind := IsoProjection.to_world(Vector2(0, 0), 0, 0, 3, 3)
	eq(IsoProjection.pick(hill, behind, 0), Vector2i(1, 1), "a raised tile in front hides the one behind")
	var cliff := IsoProjection.to_world(Vector2(1, 1), 0, 0, 3, 3) + Vector2(-10, 0)
	eq(IsoProjection.pick(hill, cliff, 0), Vector2i(1, 1), "clicking a cliff side picks its tile")
	eq(IsoProjection.pick(hill, IsoProjection.to_world(Vector2(2, 2), 0, 0, 3, 3), 0), Vector2i(2, 2), "front tile")
	ok(IsoProjection.screen_dir(Vector2i(0, -1), 0).y < 0, "facing -y looks away from the camera")
