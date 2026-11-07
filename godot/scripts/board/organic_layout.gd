class_name OrganicLayout
extends RefCounted
## A procedural tactical layout: natural terrain, not boxes. Output is the project's own map data, so TacticalGrid.from_rows reads it as-is:
##   {"rows": ["g0 g1 r3 ...", ...], "spawns": {king, captain, stones, enemy_cells}, "flags": {cliff, ramp, choke, cover, high_ground}}
## rows[y] is one strip along the long axis (y, left to right on screen); each token is "<terrain><height>" for x = 0 .. depth-1.
##
## The rules it follows (TacticalGrid.step_cost: a unit climbs at most 1 level per step; a rise of 2+ is a wall):
##   1. Noise-driven plateaus, plus cellular-automata ridges and hollows: rock outcrops grow organically, never stamped rooms.
##   2. Terraces: heights are quantised into tiers and then staggered by noise, so a rise is a run of ledges. About half the cut-off plateaus get
##      crumbling ramps (chains of 1-level steps), a high one at least two (two approach angles); the rest stay unclimbable ledges.
##   3. Choke points: across the middle of the map, rocky debris pinches the open ground down to one or two 1-2 tile passes.
##   4. Cover: boulders, broken pillars and rock spikes scattered by Poisson-disc with noise-weighted density, so the scatter is uneven.
## Afterwards the map is validated: every enemy start must be reachable from the player's start; if not, a ramp is carved.

const ROCK := "r"      ## ridge rock: stands 2+ above its neighbours, so it acts as a cliff
const RUBBLE := "d"    ## a ramp of fallen stone (walkable)
const COVER := "t"     ## boulders, pillars and spikes: TacticalGrid makes this impassable and line-blocking
const WATER := "W"

var depth := 16        ## x, up the screen (keep 16, the HUD rule)
var width := 24        ## y, the long axis, left to right
var max_level := 5
var seed := 1
var base_code := "g"   ## the ground's terrain code ("g" grass, "s" stone, "M" marble...)
var cover_density := 0.06
var choke_count := 2
## Share of cut-off plateaus that get ramps. The rest stay out of reach: high ledges and pillars nobody can climb (owner, Nov 2026: that is fine).
var ramp_share := 0.5

var h := PackedInt32Array()        ## height per cell, index y * depth + x
var code: Array[String] = []
var flags := {"cliff": [], "ramp": [], "choke": [], "cover": [], "high_ground": []}
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


static func generate(p_seed: int, p_width := 24, p_depth := 16, ground := "g") -> Dictionary:
	var g := OrganicLayout.new()
	g.seed = p_seed
	g.width = p_width
	g.depth = p_depth
	g.base_code = ground
	return g.build()


func build() -> Dictionary:
	_rng.seed = seed
	_noise.seed = seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 0.075
	h.resize(width * depth)
	code.resize(width * depth)
	_terraces()
	_ridges()
	_keep_start_zones_open()
	_chokes()
	_ramps()
	_cover()
	_validate()
	_mark_flags()
	return {"rows": _rows(), "spawns": _spawns(), "flags": flags}


# ---------------------------------------------------------------------------------------------- 1 + 2: terrain
## Noise heights, quantised into tiers, then each tier's border nudged by a second noise so ledges are staggered, not ruled lines.
func _terraces() -> void:
	for y in width:
		for x in depth:
			var n := (_noise.get_noise_2d(x * 1.2, y) + 1.0) * 0.5
			var wobble := _noise.get_noise_2d(x * 3.1 + 100.0, y * 3.1) * 0.12
			var lv := clampi(floori((n + wobble) * (max_level + 1) - 0.3), 0, max_level - 1)
			h[_i(x, y)] = lv
			code[_i(x, y)] = base_code
	# a gentle smoothing pass keeps tiers in blobs, so small one-tile pimples disappear
	for _pass in 2:
		var nh := h.duplicate()
		for y in width:
			for x in depth:
				var counts := {}
				for c in _around8(x, y):
					counts[h[_i(c.x, c.y)]] = int(counts.get(h[_i(c.x, c.y)], 0)) + 1
				for lv in counts:
					if counts[lv] >= 5:
						nh[_i(x, y)] = lv
		h = nh


## Cellular automata ridges: a noisy random fill, smoothed with the classic 4-5 rule, becomes winding rock spines and hollows.
func _ridges() -> void:
	var rock := {}
	for y in width:
		for x in depth:
			var bias := (_noise.get_noise_2d(x * 2.0 + 500.0, y * 2.0) + 1.0) * 0.5
			rock[Vector2i(x, y)] = _rng.randf() < 0.30 + bias * 0.22
	for _step in 5:
		var next := {}
		for y in width:
			for x in depth:
				var n := 0
				for c in _around8(x, y, true):
					if rock.get(c, true):
						n += 1
				next[Vector2i(x, y)] = n >= 5 or (rock[Vector2i(x, y)] and n >= 4)
		rock = next
	for c in rock:
		if rock[c] and _rng.randf() < 0.55:      # thin the rock out so the field stays open: spines, not walls everywhere
			code[_i(c.x, c.y)] = ROCK
			h[_i(c.x, c.y)] = mini(max_level, h[_i(c.x, c.y)] + 2)


## The player's side (y 0..4) and the enemy's far end stay fightable: low, open ground.
func _keep_start_zones_open() -> void:
	for y in width:
		if y > 4 and y < width - 5:
			continue
		for x in depth:
			if code[_i(x, y)] == ROCK:
				code[_i(x, y)] = base_code
			h[_i(x, y)] = mini(h[_i(x, y)], 2)  # gentle rises only: the starts stay open but not flat


# ---------------------------------------------------------------------------------------------- 3: choke points
## Across the middle band, a ragged line of collapsed debris with one or two passes of 1-2 tiles. The line wanders (noise), so it is never straight.
func _chokes() -> void:
	var lanes := []
	for k in choke_count:
		lanes.append(int(lerpf(width * 0.35, width * 0.65, (k + 0.5) / choke_count)) + _rng.randi_range(-1, 1))
	for y0 in lanes:
		var gaps := []
		for _g in _rng.randi_range(1, 2):
			gaps.append(_rng.randi_range(2, depth - 4))
		for x in depth:
			var y: int = clampi(y0 + roundi(_noise.get_noise_2d(x * 0.9, y0 * 5.0) * 2.0), 6, width - 7)
			var in_gap := gaps.any(func(g): return x >= g and x < g + _rng.randi_range(1, 2))
			if in_gap:
				code[_i(x, y)] = RUBBLE                       # the pass itself: loose stone, walkable
				h[_i(x, y)] = h[_i(x, maxi(0, y - 1))]
				flags.choke.append([x, y])
				continue
			code[_i(x, y)] = ROCK
			h[_i(x, y)] = mini(max_level, maxi(h[_i(x, y)], _max_neighbour(x, y)) + 2)
			if _rng.randf() < 0.35 and y + 1 < width - 5:      # the debris is thicker in places
				code[_i(x, y + 1)] = ROCK
				h[_i(x, y + 1)] = h[_i(x, y)]


# ---------------------------------------------------------------------------------------------- 2: ramps between tiers
## Every walkable region must connect. Plateaus that cannot be climbed onto get crumbling ramps (stairs of 1-level rubble steps),
## and any plateau of level 3 or more gets at least two, from different sides, so high ground is strong but never a one-door fortress.
func _ramps() -> void:
	_rng.seed = seed + 77  # the same plateaus keep or lose their ramps however often this runs
	for _round in 1:
		var regions := _regions()
		if regions.size() <= 1:
			break
		regions.sort_custom(func(a, b): return a.size() > b.size())
		var main: Dictionary = {}
		for c in regions[0]:
			main[c] = true
		for r in regions.slice(1):
			if r.size() < 3 or _rng.randf() > ramp_share:
				continue  # left unclimbable: scenery, a ledge above the fight
			var want := 2 if _level_of(r) >= 3 else 1
			for k in want:
				_carve_ramp(r, main, k)


## A ramp from region `r` to the main ground: the nearest pair of cells, then a stair of 1-level steps between them.
func _carve_ramp(r: Array, main: Dictionary, k: int) -> void:
	var best := []
	var best_d := 1 << 30
	for a in r:
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for dist in range(1, 5):
				var b: Vector2i = a + dir * dist
				if main.has(b):
					var d := dist * 10 + (_rng.randi_range(0, 30) if k > 0 else 0)    # the second ramp picks a different approach
					if d < best_d:
						best_d = d
						best = [a, b, dir]
					break
	if best.is_empty():
		return
	var a: Vector2i = best[0]
	var b: Vector2i = best[1]
	var dir: Vector2i = best[2]
	var from_h := h[_i(a.x, a.y)]
	var to_h := h[_i(b.x, b.y)]
	var steps := maxi(1, absi(from_h - to_h))
	var c := a + dir
	var level := from_h
	while c != b and _in(c):
		level += signi(to_h - level)
		h[_i(c.x, c.y)] = level
		code[_i(c.x, c.y)] = RUBBLE
		flags.ramp.append([c.x, c.y])
		c += dir
	# the far end eases down too, so there is never a 2-level lip at the foot of the ramp
	var left := absi(level - to_h)
	var foot := b
	while left > 1 and _in(foot):
		level += signi(to_h - level)
		h[_i(foot.x, foot.y)] = level
		code[_i(foot.x, foot.y)] = RUBBLE
		flags.ramp.append([foot.x, foot.y])
		foot += dir
		left = absi(level - to_h)


# ---------------------------------------------------------------------------------------------- 4: cover
## Poisson-disc boulders, pillars and spikes. Density follows noise (thick clusters here, open ground there), never near the starts or in a pass.
func _cover() -> void:
	var placed: Array[Vector2i] = []
	var tries := int(width * depth * cover_density * 4)
	for _t in tries:
		var c := Vector2i(_rng.randi_range(0, depth - 1), _rng.randi_range(6, width - 7))
		var dens := (_noise.get_noise_2d(c.x * 1.7 + 900.0, c.y * 1.7) + 1.0) * 0.5
		if _rng.randf() > dens or code[_i(c.x, c.y)] != base_code:
			continue
		if placed.any(func(p): return p.distance_to(c) < 2.6) or placed.filter(func(p): return p.y == c.y).size() >= 2:
			continue
		if flags.choke.any(func(p): return Vector2i(p[0], p[1]).distance_to(c) < 2.0):
			continue
		code[_i(c.x, c.y)] = COVER
		placed.append(c)
		if placed.size() >= int(width * depth * cover_density):
			break


# ---------------------------------------------------------------------------------------------- validation
## Every enemy start must be reachable from the player's start with the grid's own climbing rule; if one is not, open a ramp to it.
func _validate() -> void:
	for _round in 4:
		var reach := _flood(Vector2i(6, 2))
		var missing := _enemy_cells().filter(func(c): return not reach.has(c))
		if missing.is_empty():
			return
		for c in missing:
			code[_i(c.x, c.y)] = base_code
			h[_i(c.x, c.y)] = 1
		var keep := ramp_share
		ramp_share = 1.0
		_ramps()
		ramp_share = keep


func _mark_flags() -> void:
	for y in width:
		for x in depth:
			if code[_i(x, y)] == COVER:
				flags.cover.append([x, y])
			if code[_i(x, y)] != ROCK and h[_i(x, y)] >= 3:
				flags.high_ground.append([x, y])
			for c in _around4(x, y):
				if absi(h[_i(c.x, c.y)] - h[_i(x, y)]) >= 2:
					flags.cliff.append([x, y])
					break


# ---------------------------------------------------------------------------------------------- output
func _rows() -> Array:
	var out := []
	for y in width:
		var parts := PackedStringArray()
		for x in depth:
			parts.append("%s%d" % [code[_i(x, y)], h[_i(x, y)]])
		out.append(" ".join(parts))
	return out


## The project's spawn layout: the player on the left (low y), the enemy at the far end, stones by the player.
func _spawns() -> Dictionary:
	return {"king": [6, 2], "captain": [8, 2], "stones": [[4, 1], [10, 1], [7, 4]], "enemy_cells": _enemy_cells().map(func(c): return [c.x, c.y])}


func _enemy_cells() -> Array:
	var out := []
	for y in range(width - 4, width):
		for x in range(3, depth - 3, 3):
			if code[_i(x, y)] != COVER and code[_i(x, y)] != ROCK:
				out.append(Vector2i(x, y))
	return out


# ---------------------------------------------------------------------------------------------- helpers
func _i(x: int, y: int) -> int:
	return y * depth + x


func _in(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < depth and c.y < width


func _around4(x: int, y: int) -> Array:
	return [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)].filter(func(c): return _in(c))


func _around8(x: int, y: int, include_outside := false) -> Array:
	var out := []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var c := Vector2i(x + dx, y + dy)
			if include_outside or _in(c):
				out.append(c)
	return out


func _max_neighbour(x: int, y: int) -> int:
	var m := 0
	for c in _around4(x, y):
		m = maxi(m, h[_i(c.x, c.y)])
	return m


func _min_neighbour(x: int, y: int) -> int:
	var m := max_level
	for c in _around4(x, y):
		m = mini(m, h[_i(c.x, c.y)])
	return m


func _walkable(c: Vector2i) -> bool:
	return _in(c) and code[_i(c.x, c.y)] != COVER and code[_i(c.x, c.y)] != ROCK and code[_i(c.x, c.y)] != WATER


## Cells reachable from `start` under TacticalGrid's rule: up at most 1 level a step, down any amount (worst case: jump 3).
func _flood(start: Vector2i, jump := 3) -> Dictionary:
	var seen := {start: true}
	var todo := [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for n in _around4(c.x, c.y):
			if seen.has(n) or not _walkable(n):
				continue
			var rise := h[_i(n.x, n.y)] - h[_i(c.x, c.y)]
			if rise > 1 or -rise > jump:
				continue
			seen[n] = true
			todo.append(n)
	return seen


## Walkable regions joined by 1-level steps both ways (so a ramp is needed between any two of them).
func _regions() -> Array:
	var seen := {}
	var out := []
	for y in width:
		for x in depth:
			var c := Vector2i(x, y)
			if seen.has(c) or not _walkable(c):
				continue
			var region := []
			var todo := [c]
			seen[c] = true
			while not todo.is_empty():
				var a: Vector2i = todo.pop_back()
				region.append(a)
				for n in _around4(a.x, a.y):
					if not seen.has(n) and _walkable(n) and absi(h[_i(n.x, n.y)] - h[_i(a.x, a.y)]) <= 1:
						seen[n] = true
						todo.append(n)
			out.append(region)
	return out


func _level_of(region: Array) -> int:
	var total := 0
	for c in region:
		total += h[_i(c.x, c.y)]
	return total / maxi(1, region.size())
