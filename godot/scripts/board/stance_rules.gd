class_name StanceRules
extends RefCounted
## What the six weapon styles (their geometry) do with each stance (owner's rules, Nov 2026). The footprint and who is hit come from
## StyleResolver; this file is the table of what is allowed and the damage percents. A unit's style and stance are set before battle
## and fixed during it. They apply to weapon attacks and Physical skills; the other five proficiencies ignore them.
##
## Every style has Impact and Pierce; only the Pawn also has Axe. All hits land on whoever stands on a tile, ally or foe.
##
##   Rook, Bishop   a facing line (Rook: straight ahead; Bishop: the two forward diagonals), the whole map. Impact hits the first
##                  unit on it; Pierce hits every unit on it. Percent by distance D (in steps): 33% for D 1-3, then 1/D (25% at 4).
##   Knight         one of the 8 L-jumps, to its end tile. Impact: that tile, 100%. Pierce: end tile 50%, the two tiles the L
##                  passes through 25%.
##   Queen          a line in any of the 8 directions. Impact: the first unit within 2 tiles, 50%. Pierce: like the Rook, any of 8.
##   King           the 8 tiles around it. Impact: the chosen tile, 100%. Pierce: all 8 at once, 33% each.
##   Pawn (faces)   the front tile and the two forward diagonals. Impact: the front tile, 100%. Pierce: one chosen of the three, 50%.
##                  Axe: all three at once, 33% each.
## Higher ground than the attacker's level blocks a line or can not be aimed at (the Knight can land up to 2 levels higher).
## Rook, Bishop and Pawn can only use the way they face: after a move, the direction of its last step; attacking does not turn them.

const FACING_STYLES := [TacticalMath.Geometry.ROOK, TacticalMath.Geometry.BISHOP, TacticalMath.Geometry.PAWN]
const ENEMY_STYLES := [TacticalMath.Geometry.ROOK, TacticalMath.Geometry.BISHOP, TacticalMath.Geometry.KNIGHT, TacticalMath.Geometry.PAWN]
const FLAT_PERCENT_UP_TO := 3  ## distance (steps) up to which a line attack does the flat percent
const FLAT_PERCENT := 33


## The stances a geometry may use.
static func allowed_stances(geometry: TacticalMath.Geometry) -> Array:
	if geometry == TacticalMath.Geometry.PAWN:
		return [WeaponStyle.Stance.IMPACT, WeaponStyle.Stance.PIERCE, WeaponStyle.Stance.AXE]
	return [WeaponStyle.Stance.IMPACT, WeaponStyle.Stance.PIERCE]


static func is_allowed(geometry: TacticalMath.Geometry, stance: WeaponStyle.Stance) -> bool:
	return allowed_stances(geometry).has(stance)


## Whether the geometry can only be used toward the way the unit faces.
static func uses_facing(geometry: TacticalMath.Geometry) -> bool:
	return FACING_STYLES.has(geometry)


## Damage percent of a line hit at `d` steps: 33% for 1-3, then 1/d.
static func distance_percent(d: int) -> int:
	return FLAT_PERCENT if d <= FLAT_PERCENT_UP_TO else roundi(100.0 / d)


## Damage percent for a hit on `tile` of `area` (set by StyleResolver); 100 when the area holds none (non-styled actions).
static func damage_percent(_stance: WeaponStyle.Stance, area: TargetArea, tile: Vector2i) -> int:
	return int(area.percents.get(tile, 100))


## Physical damage after the percent: base x percent, rounded, at least 1 when base > 0.
static func scale_damage(base: int, percent: int) -> int:
	return 0 if base <= 0 else maxi(1, roundi(base * percent / 100.0))


## The bare footprint (the style's geometry and reach, no stance): what skills of the other five proficiencies use. No style:
## King geometry, reach 1.
static func footprint(style: WeaponStyle, _stance: WeaponStyle.Stance, facing: Vector2i, vertical_reach: int, _skill: SkillData = null) -> GeometryPattern:
	var base := GeometryPattern.build(style.geometry if style else TacticalMath.Geometry.KING, style.reach if style else 1, facing)
	base.vertical_reach = vertical_reach
	return base


## One line on what a style does with a stance, for the menus.
static func describe(geometry: TacticalMath.Geometry, stance: WeaponStyle.Stance) -> String:
	var G := TacticalMath.Geometry
	var pierce := stance == WeaponStyle.Stance.PIERCE
	match geometry:
		G.ROOK:
			return ("Faces forward. Hits everyone on the line ahead, the whole map." if pierce else "Faces forward. Hits the first unit on the line ahead, the whole map.") + " 33% within 3 tiles, then 1/distance."
		G.BISHOP:
			return ("Faces forward. Picks a forward diagonal and hits everyone on it." if pierce else "Faces forward. Picks a forward diagonal and hits the first unit on it.") + " 33% within 3 tiles, then 1/distance."
		G.KNIGHT:
			return "Jumps in an L. The end tile takes 50%, the two tiles it passes 25%." if pierce else "Jumps in an L. Only the end tile is hit, for 100%."
		G.QUEEN:
			return "Picks any of 8 directions and hits everyone on the line. 33% within 3 tiles, then 1/distance." if pierce else "Picks any of 8 directions and hits the first unit within 2 tiles, for 50%."
		G.KING:
			return "Hits all 8 tiles around it at once, 33% each." if pierce else "Hits one chosen tile around it, for 100%."
		G.PAWN:
			if stance == WeaponStyle.Stance.AXE:
				return "Faces forward. Hits the tile ahead and both forward diagonals at once, 33% each."
			return "Faces forward. Hits one chosen tile of the three ahead, for 50%." if pierce else "Faces forward. Hits only the tile ahead, for 100%."
	return ""


static func stance_name(stance: WeaponStyle.Stance) -> String:
	return WeaponStyle.Stance.keys()[stance].capitalize()


static func style_name(geometry: TacticalMath.Geometry) -> String:
	return TacticalMath.Geometry.keys()[geometry].capitalize()
