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
	var h := TacticalGrid.from_rows(["g0 g5 g0 g0", "g0 g0 g0 g0", "g0 g0 g0 g0", "g5 g0 g0 g0"])
	var hr := GeometryPattern.build(TacticalMath.Geometry.ROOK, 3)
	var ht := GeometryResolver.targetable(h, Vector2i(0, 0), hr)
	ok(not ht.has(Vector2i(1, 0)) and not ht.has(Vector2i(2, 0)), "cliff is a wall")
	ok(ht.has(Vector2i(0, 2)) and not ht.has(Vector2i(0, 3)), "height 5 out of reach 3 + 1 (one level higher than the reach is allowed: height 4 is in)")
	var top := GeometryResolver.targetable(h, Vector2i(1, 0), hr)
	ok(not top.has(Vector2i(2, 0)) and top.has(Vector2i(1, 1)) == false, "5 levels down is out of reach")
	hr.vertical_reach = 5
	ok(GeometryResolver.targetable(h, Vector2i(1, 0), hr).has(Vector2i(3, 0)), "more vertical reach")


## The six styles with their stances (StyleResolver, the owner's rules in StanceRules): who may use what, where each can aim, what
## each hits and for how much. A unit's style and stance are fixed for the whole battle.
func stances() -> void:
	var G := TacticalMath.Geometry
	var IM := WeaponStyle.Stance.IMPACT
	var PI := WeaponStyle.Stance.PIERCE
	var AX := WeaponStyle.Stance.AXE
	for geo in G.values():  # every style has Impact and Pierce; only the Pawn also has Axe
		ok(StanceRules.is_allowed(geo, IM) and StanceRules.is_allowed(geo, PI), "%s has impact and pierce" % StanceRules.style_name(geo))
		eq(StanceRules.is_allowed(geo, AX), geo == G.PAWN, "only the pawn has axe (%s)" % StanceRules.style_name(geo))
	eq([StanceRules.distance_percent(1), StanceRules.distance_percent(3), StanceRules.distance_percent(4), StanceRules.distance_percent(5)], [33, 33, 25, 20], "33% for 1-3, then 1/D")
	var o := Vector2i(3, 3)
	var north := Vector2i(0, -1)
	var g := flat()
	# Rook: the line straight ahead, the whole map; impact hits the first unit (ally or foe), pierce every unit
	eq(StyleResolver.targetable(g, o, G.ROOK, IM, north).size(), 3, "rook: the line north to the edge (3 tiles)")
	g.place("a", Vector2i(3, 2), 1)
	g.place("b", Vector2i(3, 0), 0)
	var area := StyleResolver.affected(g, o, G.ROOK, IM, north, Vector2i(3, 0))
	eq(area.occupants, ["a"], "rook impact stops at the first unit")
	eq(area.percents[Vector2i(3, 2)], 33, "rook impact at 1 tile: 33%")
	area = StyleResolver.affected(g, o, G.ROOK, PI, north, Vector2i(3, 1))
	eq(area.occupants, ["a", "b"], "rook pierce hits everyone on the line, ally and foe")
	eq(area.percents[Vector2i(3, 0)], 33, "rook pierce at 3 tiles: 33%")
	ok(StyleResolver.affected(g, o, G.ROOK, IM, north, Vector2i(4, 3)).is_empty(), "rook can not aim sideways")
	var big := flat(12)
	var far := StyleResolver.affected(big, Vector2i(0, 5), G.ROOK, PI, Vector2i(1, 0), Vector2i(1, 5))
	eq(far.percents[Vector2i(11, 5)], 9, "rook pierce at 11 tiles: 1/11")
	eq(far.percents[Vector2i(4, 5)], 25, "...and 25% at 4")
	# higher ground stops a line; lower ground does not; units never do
	var east := Vector2i(1, 0)
	eq(StyleResolver.targetable(TacticalGrid.from_rows(["g0 g0 g2 g0"]), Vector2i(0, 0), G.ROOK, IM, east), [Vector2i(1, 0)], "ground two levels higher than the attacker ends a line")
	eq(StyleResolver.targetable(TacticalGrid.from_rows(["g0 g0 g1 g0"]), Vector2i(0, 0), G.ROOK, IM, east).size(), 3, "ground one level higher does not (every attack reaches one level up)")
	eq(StyleResolver.targetable(TacticalGrid.from_rows(["g1 g0 g0 g0"]), Vector2i(0, 0), G.ROOK, IM, east).size(), 3, "lower ground never blocks")
	eq(StyleResolver.targetable(TacticalGrid.from_rows(["g0 g2 g0"]), Vector2i(0, 0), G.KING, IM, east), [] as Array[Vector2i], "the King can not aim at ground two levels higher")
	eq(StyleResolver.targetable(TacticalGrid.from_rows(["g0 g1 g0"]), Vector2i(0, 0), G.KING, IM, east), [Vector2i(1, 0)] as Array[Vector2i], "the King can aim one level higher")
	eq(StyleResolver.targetable(TacticalGrid.from_rows(["g0 g0 g0 g2", "g0 g0 g0 g3", "g0 g0 g0 g0"]), Vector2i(1, 1), G.KNIGHT, IM, east).size() > 0, true, "the knight can land up to 3 levels higher (2 and the one level every attack reaches up)")
	ok(not StyleResolver.targetable(TacticalGrid.from_rows(["g0 g0 g4", "g0 g0 g0", "g0 g0 g0"]), Vector2i(0, 1), G.KNIGHT, IM, east).has(Vector2i(2, 0)), "...but not 4")
	# Bishop: the two forward diagonals; counts steps
	g = flat()
	eq(StyleResolver.targetable(g, o, G.BISHOP, IM, north).size(), 6, "bishop facing north: both forward diagonals (3 + 3)")
	ok(not StyleResolver.targetable(g, o, G.BISHOP, IM, north).has(Vector2i(4, 4)), "bishop has no backward diagonals")
	g.place("c", Vector2i(5, 1), 1)
	area = StyleResolver.affected(g, o, G.BISHOP, PI, north, Vector2i(4, 2))
	eq(area.occupants, ["c"], "bishop pierce along the diagonal")
	eq(area.percents[Vector2i(5, 1)], 33, "bishop: each diagonal tile is one step")
	# Knight: one of the 8 jumps; impact 100% at the end tile; pierce 50% there and 25% on the two tiles the L passes through
	g = flat()
	g.place("k1", Vector2i(4, 1), 1)
	g.place("k2", Vector2i(3, 2), 1)
	eq(StyleResolver.targetable(g, o, G.KNIGHT, IM, north).size(), 8, "knight: 8 jumps")
	area = StyleResolver.affected(g, o, G.KNIGHT, IM, north, Vector2i(4, 1))
	eq([area.tiles, area.percents[Vector2i(4, 1)]], [[Vector2i(4, 1)], 100], "knight impact: the end tile, 100%")
	area = StyleResolver.affected(g, o, G.KNIGHT, PI, north, Vector2i(4, 1))
	eq(area.tiles, [Vector2i(4, 1), Vector2i(3, 2), Vector2i(3, 1)], "knight pierce: the end of the L and the two tiles it passes")
	eq([area.percents[Vector2i(4, 1)], area.percents[Vector2i(3, 2)], area.percents[Vector2i(3, 1)]], [50, 25, 25], "knight pierce 50 / 25 / 25")
	# Queen: eight directions; impact reaches 2 tiles and hits the first unit for 50%; pierce is the rook's line in any direction
	g = flat()
	eq(StyleResolver.targetable(g, o, G.QUEEN, IM, north).size(), 16, "queen impact: 8 directions x 2 tiles")
	g.place("q", Vector2i(3, 2), 1)
	g.place("r", Vector2i(3, 1), 1)
	area = StyleResolver.affected(g, o, G.QUEEN, IM, north, Vector2i(3, 1))
	eq([area.occupants, area.percents[Vector2i(3, 2)]], [["q"], 50], "queen impact: the first unit, 50%")
	area = StyleResolver.affected(g, o, G.QUEEN, PI, north, Vector2i(3, 2))
	eq(area.occupants, ["q", "r"], "queen pierce: every unit on the line")
	eq(StyleResolver.targetable(g, o, G.QUEEN, PI, north).size() > 16, true, "queen pierce reaches the whole map")
	# King: the 8 tiles around; impact the chosen tile for 100%; pierce all 8 at once for 33%
	g = flat()
	g.place("x", Vector2i(4, 4), 1)
	g.place("y", Vector2i(2, 3), 1)
	eq(StyleResolver.targetable(g, o, G.KING, IM, north).size(), 8, "king: 8 tiles")
	area = StyleResolver.affected(g, o, G.KING, IM, north, Vector2i(4, 4))
	eq([area.tiles, area.percents[Vector2i(4, 4)]], [[Vector2i(4, 4)], 100], "king impact: the chosen tile, 100%")
	area = StyleResolver.affected(g, o, G.KING, PI, north, Vector2i(4, 4))
	eq([area.tiles.size(), area.occupants.size(), area.percents[Vector2i(4, 4)]], [8, 2, 33], "king pierce: all 8 tiles, 33% each")
	# Pawn (faces): impact the front tile 100%; pierce one of three front tiles at 50%; axe all three at 33%
	g = flat()
	g.place("p1", Vector2i(3, 2), 1)
	g.place("p2", Vector2i(4, 2), 1)
	g.place("p3", Vector2i(2, 2), 1)
	eq(StyleResolver.targetable(g, o, G.PAWN, IM, north), [Vector2i(3, 2)], "pawn impact: only the tile ahead")
	area = StyleResolver.affected(g, o, G.PAWN, IM, north, Vector2i(3, 2))
	eq(area.percents[Vector2i(3, 2)], 100, "pawn impact 100%")
	eq(StyleResolver.targetable(g, o, G.PAWN, PI, north).size(), 3, "pawn pierce: choose one of three")
	area = StyleResolver.affected(g, o, G.PAWN, PI, north, Vector2i(4, 2))
	eq([area.tiles, area.percents[Vector2i(4, 2)]], [[Vector2i(4, 2)], 50], "pawn pierce: the chosen tile, 50%")
	area = StyleResolver.affected(g, o, G.PAWN, AX, north, Vector2i(3, 2))
	eq([area.occupants, area.percents[Vector2i(2, 2)]], [["p1", "p2", "p3"], 33], "pawn axe: all three at 33%")
	eq(StyleResolver.targetable(g, o, G.PAWN, PI, Vector2i(1, 0)), [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 2)], "pawn faces +x")
	# an obstacle stops a line and can not be aimed at
	g = flat()
	g.add_obstacle(Vector2i(3, 1))
	eq(StyleResolver.targetable(g, o, G.ROOK, IM, north), [Vector2i(3, 2)], "an obstacle ends a line")
	# damage: scaled, at least 1; skills of other proficiencies never use a stance
	eq(StanceRules.scale_damage(9, 33), 3, "33% of 9")
	eq(StanceRules.scale_damage(1, 33), 1, "at least 1 damage")
	var mag := SkillData.new()
	mag.category = Proficiency.Category.ELEMENTAL
	var style := WeaponStyle.new()
	style.geometry = G.ROOK
	style.reach = 2
	eq(StanceRules.footprint(style, IM, north, 3, mag).reach, 2, "other proficiencies use the bare footprint")
	# enemies roll a random style (never King or Queen) and an allowed stance; the tutorial fights keep theirs
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen := {}
	var axe_seen := false
	for i in 300:
		var rolled := EnemyStyles.roll(rng)
		ok(StanceRules.ENEMY_STYLES.has(rolled.geometry) and StanceRules.is_allowed(rolled.geometry, rolled.stance), "a rolled enemy style is Rook, Bishop, Knight or Pawn with an allowed stance")
		seen[rolled.geometry] = true
		axe_seen = axe_seen or rolled.stance == AX
		ok(rolled.stance != AX or rolled.geometry == G.PAWN, "only a Pawn rolls Axe")
	eq(seen.size(), 4, "all four enemy styles come up")
	ok(axe_seen, "a Pawn rolls Axe sometimes")
	ok(FirstBattle.setup(Vector2i(0, 0), Vector2i(1, 1)).fixed_styles and not Riverford.setup(1).fixed_styles, "the first battle keeps its fixed styles; a Riverford battle rolls them")
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
