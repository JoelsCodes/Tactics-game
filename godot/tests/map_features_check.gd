extends Node
## Headless: the map format's half steps, ramps and flags (Terrain.parse, TacticalGrid, Board3D). godot --headless --path godot res://tests/map_features_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, str(a), str(b)])


func _ready() -> void:
	tokens()
	grid_rules()
	await board()
	await decks()
	print("map features checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func tokens() -> void:
	eq(Terrain.parse_token("g2"), {"t": "g", "h": 2.0, "s": "", "f": ""}, "a plain tile")
	eq(Terrain.parse_token("g1.5>"), {"t": "g", "h": 1.5, "s": ">", "f": ""}, "a ramp")
	eq(Terrain.parse_token("s3!"), {"t": "s", "h": 3.0, "s": "", "f": "!"}, "a no-walk tile")
	eq(Terrain.parse_token("b0~"), {"t": "b", "h": 0.0, "s": "", "f": "~"}, "a pass-only tile")
	eq(Terrain.parse_token("g2.5v*"), {"t": "g", "h": 2.5, "s": "v", "f": "*"}, "a ramp out of play")
	eq(Terrain.parse_token("v")["t"], "v", "the void")
	eq(Terrain.parse_token("W0")["h"], 0.0, "deep water")
	var deck := Terrain.parse_token("b4=W0")
	ok(deck.t == "b" and deck.h == 4.0 and deck.u.t == "W" and deck.u.h == 0.0, "a deck: a bridge at 4 over deep water")


func grid_rules() -> void:
	var g := TacticalGrid.from_map(Terrain.load_map("res://samples/features_demo.json"))
	eq(g.height(Vector2i(3, 4)), 1.5, "a half step")
	eq(g.slope(Vector2i(3, 5)), "v", "a ramp's direction")
	ok(not g.is_passable(Vector2i(10, 2)), "a no-walk rock top: no walking")
	ok(not g.is_obstacle(Vector2i(10, 2)), "but it does not block lines")
	ok(g.is_passable(Vector2i(5, 4)) and not g.can_stand(Vector2i(5, 4)), "a pass-only bridge: walk across, never stand")
	ok(g.is_void(Vector2i(0, 7)), "an out-of-play tile is the void to the rules")
	var r := g.reachable(Vector2i(4, 4), 6, 1)
	ok(r.costs.has(Vector2i(7, 4)), "the bridge carries a unit across the water")
	ok(not r.costs.has(Vector2i(5, 4)) and not r.costs.has(Vector2i(6, 4)), "but no move ends on the bridge")
	# the ramps: level 1 -> 1.5 -> 2.5 -> 3 climbs a cliff that is two levels high straight on
	ok(g.step_cost(Vector2i(2, 6), Vector2i(2, 7), 3) == 1, "one level down, fine")
	ok(g.step_cost(Vector2i(5, 7), Vector2i(4, 7), 1) < 0, "three levels straight up: no")
	ok(g.step_cost(Vector2i(2, 7), Vector2i(3, 7), 1) < 0, "the terrace's side is a cliff")
	var p := g.find_path(Vector2i(3, 3), Vector2i(3, 7), 1)
	ok(not p.is_empty(), "the ramps make a way up to the terrace")
	var up := g.find_path(Vector2i(7, 1), Vector2i(9, 1), 1)
	ok(not up.is_empty() and up.has(Vector2i(8, 1)), "a pair of ramps climbs two levels onto the stone shelf")
	ok(p.has(Vector2i(3, 5)) and p.has(Vector2i(3, 6)), "and the way up is the ramps")
	ok(not StyleResolver.blocks(g, Vector2i(3, 4), 1.0), "a half step higher does not block a line")
	ok(StyleResolver.blocks(g, Vector2i(3, 7), 1.0), "two levels higher does")


func board() -> void:
	var b := Board3D.new()
	add_child(b)
	b.setup(Terrain.load_map("res://samples/features_demo.json"))
	await get_tree().process_frame
	eq(b.corner_levels(3, 5), [1.0, 1.0, 2.0, 2.0], "the ramp's corners run from its low to its high side")
	eq(b.edge_levels(3, 5, Vector2i(1, 0)), [1.0, 2.0], "its right side slants")
	eq(b.edge_levels(3, 4, Vector2i(0, 1)), [1.5, 1.5], "the half step's side is flat")
	var tc := b.top_corners(Vector2i(8, 1))
	ok(tc[1].y > tc[0].y, "a ramp's top tilts")
	ok(b.get_node_or_null("Terrain") != null, "the terrain mesh is built")
	b.queue_free()


func decks() -> void:
	var m := Terrain.load_map("res://samples/deck_demo.json")
	var g := TacticalGrid.from_map(m)
	eq(g.height(Vector2i(5, 2)), 4.0, "a deck stands at its own height to the rules")
	eq(g.terrain(Vector2i(5, 2)), "b", "and is the bridge, not the water under it")
	var p := g.find_path(Vector2i(0, 2), Vector2i(11, 2), 1)
	ok(not p.is_empty() and p.has(Vector2i(5, 2)), "units cross the canyon on the bridge")
	ok(not g.is_passable(Vector2i(5, 8)), "a walkway marked no-walk is scenery")
	var b := Board3D.new()
	add_child(b)
	b.setup(m)
	await get_tree().process_frame
	ok(b.is_deck(5, 2), "the board knows the deck")
	eq(b.corner_levels(5, 2), [4.0, 4.0, 4.0, 4.0], "a unit stands on the deck's top")
	ok(b.corner_levels(5, 2, true)[0] < 0.0, "and the walls next to it come down to the water below")
	ok(b.get_node_or_null("Terrain") != null, "the board with decks builds")
	b.queue_free()
