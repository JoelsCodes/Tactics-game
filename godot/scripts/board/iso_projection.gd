class_name IsoProjection
extends RefCounted
## Grid <-> screen math for the isometric diorama view. Pure functions: no nodes, no drawing.
## Terrain (rendering) and input picking both use these, so a tile is always drawn where it is picked.
##
## A cell (x, y) on the board is drawn as a diamond 2*TW wide and 2*TH tall, raised HS pixels per
## height level. The view can be rotated in quarter turns (`rot` 0..3); rotation is a view change only,
## the board's own coordinates never change.

const TW := 32.0  ## tile half-width in pixels
const TH := 16.0  ## tile half-height in pixels
const HS := 14.0  ## pixels per height level


## Board position -> rotated view position, for a board of w x d cells.
static func rotate(p: Vector2, rot: int, w: int, d: int) -> Vector2:
	match posmod(rot, 4):
		1: return Vector2(d - 1 - p.y, p.x)
		2: return Vector2(w - 1 - p.x, d - 1 - p.y)
		3: return Vector2(p.y, w - 1 - p.x)
	return p


## Ground point (height 0) of a board position, in world pixels.
static func ground(p: Vector2, rot: int, w: int, d: int) -> Vector2:
	var r := rotate(p, rot, w, d)
	return Vector2((r.x - r.y) * TW, (r.x + r.y) * TH)


## World point of a board position standing at height h.
static func to_world(p: Vector2, h: float, rot: int, w: int, d: int) -> Vector2:
	return ground(p, rot, w, d) - Vector2(0, h * HS)


## Draw order key of a cell: larger means nearer the camera (drawn later).
static func depth(cell: Vector2i, rot: int, w: int, d: int) -> float:
	var r := rotate(Vector2(cell), rot, w, d)
	return r.x + r.y


## Screen direction of a board direction under a view rotation (for sprite facing: y < 0 = away).
static func screen_dir(dir: Vector2i, rot: int) -> Vector2:
	var r := rotate(Vector2(dir), rot, 1, 1) - rotate(Vector2.ZERO, rot, 1, 1)
	return Vector2(r.x - r.y, (r.x + r.y) / 2.0)


## The cell drawn under a world point, or Vector2i(-1, -1): a tile's top face and the cliff sides below
## it both count, and where tiles overlap (a high tile in front of a low one) the one drawn nearest the
## camera wins, so you always get the tile you see.
static func pick(grid: TacticalGrid, point: Vector2, rot: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_depth := -INF
	for y in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, y)
			if grid.is_void(c):
				continue
			var local := point - to_world(Vector2(c), grid.height(c), rot, grid.width, grid.depth)
			if absf(local.x) > TW:
				continue
			var edge := TH * (1.0 - absf(local.x) / TW)
			if local.y < -edge or local.y > grid.height(c) * HS + edge:  # above the top, or below the column
				continue
			var dk := depth(c, rot, grid.width, grid.depth) + grid.height(c) * .01
			if dk > best_depth:
				best_depth = dk
				best = c
	return best
