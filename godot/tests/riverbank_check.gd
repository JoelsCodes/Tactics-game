extends Node
## Headless: the four Riverbank battle maps. The fight runs left to right (owner, Nov 2026): Alaric starts on the left (levels 1, 3) or the right (2, 4), the
## foes on the other side. Sizes (16 deep, 16 to 19 wide and even, level 4 is 15x15), one tileset, several levels of
## height, routes that block (water, cliffs, trees) so the road to the enemy is a detour, the fortress and its boss in level 4.
## godot --headless --path godot res://tests/riverbank_check.tscn
var fails := 0
var count := 0
const TILESET := ["g", "d", "s", "r", "w", "W", "b", "t"]


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	var sizes := [Vector2i(16, 16), Vector2i(16, 16), Vector2i(16, 16), Vector2i(15, 15)]
	for n in range(1, 5):
		level(n, sizes[n - 1])
	sizes_cap()
	stones()
	print("riverbank checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func level(n: int, want: Vector2i) -> void:
	var label := "level %d (%s)" % [n, Riverbank.NAMES[n]]
	var map := Terrain.load_map(Riverbank.MAPS[n])
	eq(Vector2i(map.w, map.d), want, "%s: size" % label)
	if n < 4:
		ok(map.w == 16 and map.d >= 16 and map.d <= 19 and map.d % 2 == 0, "%s: the standard 16, grown by at most 3 and kept even, never past 19" % label)
	var codes := {}
	var heights := {}
	for y in map.d:
		for x in map.w:
			var t: Dictionary = map.tiles[y][x]
			codes[t.t] = codes.get(t.t, 0) + 1
			heights[t.h] = true
	ok(codes.keys().all(func(c): return c in TILESET), "%s: only the Riverbank tileset (%s)" % [label, codes.keys()])
	ok(codes.has("w") or codes.has("W"), "%s: water" % label)
	ok(codes.get("t", 0) >= 10 and codes.get("r", 0) >= 10 and codes.get("W", 0) >= 8, "%s: trees, rock and deep water to block the way" % label)
	ok(heights.size() >= 4, "%s: several levels of height (%d)" % [label, heights.size()])
	# the setup
	var s := Riverbank.setup(n)
	eq(s.relics.size(), 3, "%s: three summon stones" % label)
	ok(s.captain_cell != TacticalGrid.NO_CELL, "%s: a place for the Co-Captain" % label)
	eq(s.enemies.size(), [4, 5, 5, 6][n - 1], "%s: the foes" % label)
	var grid := TacticalGrid.from_map(map)
	var open := func(c: Vector2i) -> bool: return grid.is_passable(c)
	ok(open.call(s.king_cell) and open.call(s.captain_cell) and s.relics.all(func(r): return open.call(r[1])) and s.enemies.all(func(e): return open.call(e[1])), "%s: everyone starts on open ground" % label)
	# the fight runs left to right: the two sides are apart along y (the screen's horizontal), on the left for levels 1 and 3, on the right for 2 and 4
	var left_start := n % 2 == 1
	var dx := 0.0
	var dy := 0.0
	for e in s.enemies:
		dx += absf(e[1].x - s.king_cell.x)
		dy += absf(e[1].y - s.king_cell.y)
		var side_ok: bool = e[1].y > s.king_cell.y if left_start else e[1].y < s.king_cell.y
		ok(side_ok, "%s: the %s is on the %s of Alaric" % [label, e[0].display_name, "right" if left_start else "left"])
	ok(dy > dx, "%s: the foes are across the screen (%.0f apart sideways, %.0f in depth), not front to back" % [label, dy / s.enemies.size(), dx / s.enemies.size()])
	# the road to the enemy is a detour: every foe can be reached, but not by a straight line
	var costs := grid.reachable(s.king_cell, 999, 2)
	var gains: Array[int] = []
	for e in s.enemies:
		var best := 999
		for d in TacticalMath.ORTHOGONAL:
			var c: Vector2i = e[1] + d
			if costs.can_reach(c):
				best = mini(best, costs.cost_to(c))
		var straight: int = absi(s.king_cell.x - e[1].x) + absi(s.king_cell.y - e[1].y) - 1
		ok(best < 999, "%s: Alaric can reach the %s at %s" % [label, e[0].display_name, e[1]])
		gains.append(best - straight)
	var sum := 0
	for g in gains:
		sum += g
	ok(float(sum) / gains.size() >= 4.0 and gains.filter(func(g): return g >= 4).size() >= 3, "%s: the way round is longer than a straight line (%s)" % [label, gains])
	if n == 4:
		fortress(s, map, grid, label)


func fortress(s: BattleSetup, map: Dictionary, grid: TacticalGrid, label: String) -> void:
	var boss: Array = s.enemies.filter(func(e): return e[0].exp_reward >= 150)
	eq(boss.size(), 1, "%s: one boss" % label)
	var at: Vector2i = boss[0][1]
	ok(at.y <= 3 and grid.height(at) >= 4, "%s: the boss stands on the dais in the hall, high on the enemy's side, the left end (%s, level %d)" % [label, at, grid.height(at)])
	var walls := 0
	for y in map.d:
		for x in map.w:
			if y > 3:
				continue
			walls += 1 if grid.terrain(Vector2i(x, y)) == "r" and grid.height(Vector2i(x, y)) >= 5 else 0
	ok(walls >= 25, "%s: the hall is walled in (%d wall tiles)" % [label, walls])
	ok(s.enemies.all(func(e): return e[1].y <= 4), "%s: every foe starts on the fortress side" % label)
	ok(s.king_cell.y >= 11, "%s: Alaric starts across the moat" % label)
	eq(s.objective, "Defeat the boss in the Hold", "%s: the objective names the boss" % label)


## No battle map is bigger than 19 in either direction (the standard is 16x16).
func sizes_cap() -> void:
	for path in ["res://samples/intro_ruins.json", "res://samples/ruins_chamber.json", "res://samples/demo_battlefield.json"] + Riverbank.MAPS.slice(1):
		var map := Terrain.load_map(path)
		ok(map.w <= 19 and map.d <= 19, "%s is %dx%d, not bigger than 19" % [path.get_file(), map.w, map.d])


## Every summoning stone carries one rank E physical skill, picked at random.
func stones() -> void:
	var library := SummonStone.e_skills()
	eq(library.size(), 10, "ten rank E physical skills so far")
	ok(library.all(func(s): return s.is_physical() and s.rank == SkillData.Rank.E), "all physical, all rank E")
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var r := SummonStone.make(rng)
		ok(r.skill != null and library.has(r.skill), "a stone's skill is one of them")
		seen[r.skill.display_name] = true
	ok(seen.size() >= 6, "the pick is random (%d different skills in 60 stones)" % seen.size())
	for n in range(1, 5):
		var s := Riverbank.setup(n)
		ok(s.relics.all(func(r): return r[0].skill != null and r[0].skill.is_physical() and r[0].skill.rank == SkillData.Rank.E), "Riverbank %d: every stone carries a rank E physical skill" % n)
	for s in [FirstBattle.chamber_setup(ChamberCutscene.WALL_SPOT, ChamberCutscene.SQUIRES_TO), FirstBattle.hallway_replay(), FirstBattle.chamber_replay(), SampleBattle.setup(1)]:
		ok(not s.relics.is_empty() and s.relics.all(func(r): return r[0].skill != null and r[0].skill.rank == SkillData.Rank.E and r[0].skill.is_physical()), "the story, replay and sample battles' stones too")
