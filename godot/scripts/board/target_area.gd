class_name TargetArea
extends RefCounted
## What one attack aimed at one tile affects: the tiles and whoever stands on them.

var origin := TacticalGrid.NO_CELL
var aim := TacticalGrid.NO_CELL
var tiles: Array[Vector2i] = []  ## aimed tile first, then pierce tiles, then splash tiles
var occupants: Array = []  ## in the same order as their tiles; the attacker is never included


func is_empty() -> bool:
	return tiles.is_empty()


func has_tile(c: Vector2i) -> bool:
	return tiles.has(c)
