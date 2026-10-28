class_name GeometryPattern
extends RefCounted
## A unit's active vector footprint: the rays it reaches along and how a hit spreads.
## Built from a geometry (TacticalMath.Geometry) and a reach, then reshaped by a stance (StanceRules).
## Plain data; GeometryResolver walks it over a TacticalGrid.

## How a hit spreads from the aimed tile.
enum Splash {
	NONE,  ## just the aimed tile
	CROSS,  ## the aimed tile and its four orthogonal neighbours
	CLEAVE,  ## the aimed tile and the two tiles beside it, across the line of attack
}

var geometry: TacticalMath.Geometry = TacticalMath.Geometry.ROOK
var reach := 1  ## tiles per ray for sliding geometries
var facing := Vector2i(0, 1)  ## only Pawn uses it
var rays: Array[Array] = []  ## Array of Array[Vector2i] offsets, nearest first
## Jumping patterns (Knight) ignore anything between the unit and the target tile.
var jumps := false
## Extra tiles hit behind the aimed tile, along the line of attack.
var pierce := 0
var splash: Splash = Splash.NONE
## Largest height difference (levels) between the unit and a tile it can target. A tile higher than
## this above the unit is a wall that stops a sliding ray.
var vertical_reach := 3


static func build(geo: TacticalMath.Geometry, reach_tiles: int, face := Vector2i(0, 1)) -> GeometryPattern:
	var p := GeometryPattern.new()
	p.geometry = geo
	p.reach = maxi(reach_tiles, 1)
	p.facing = face
	p.jumps = geo == TacticalMath.Geometry.KNIGHT
	p.rays = TacticalMath.geometry_rays(geo, p.reach, face)
	return p


static func from_style(style: WeaponStyle, face := Vector2i(0, 1)) -> GeometryPattern:
	return build(style.geometry, style.reach, face)


func copy() -> GeometryPattern:
	var p := build(geometry, reach, facing)
	p.jumps = jumps
	p.pierce = pierce
	p.splash = splash
	p.vertical_reach = vertical_reach
	return p


## Every offset on the rays, ignoring the board.
func offsets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ray in rays:
		for o in ray:
			out.append(o)
	return out
