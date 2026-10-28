class_name StanceRules
extends RefCounted
## What a stance does, and all it does (a unit's stance comes from its weapon style, set before battle
## and fixed during it): it reshapes the footprint (which tiles can be selected and
## which are hit) and scales the damage of weapon attacks and Physical skills. It never changes
## stats or SP costs, and skills of the other five proficiencies ignore it. One table, so tuning is one line:
##   stance  reach  footprint                              damage: aimed tile / other hit tiles
##   Impact   -1    cross burst (the tile + 4 neighbours)  100% / 50%
##   Pierce   +1    carries on 1 tile behind the target     90% / 75%
##   Axe       0    cleaves the 2 tiles beside the target  110% / 50%
## Reach never drops below 1. Knight, King and Pawn take one step per ray, so reach changes do
## nothing to them; their splash and pierce still apply.

const RULES := {
	WeaponStyle.Stance.IMPACT: {"reach": -1, "pierce": 0, "splash": GeometryPattern.Splash.CROSS, "main": 100, "spread": 50},
	WeaponStyle.Stance.PIERCE: {"reach": 1, "pierce": 1, "splash": GeometryPattern.Splash.NONE, "main": 90, "spread": 75},
	WeaponStyle.Stance.AXE: {"reach": 0, "pierce": 0, "splash": GeometryPattern.Splash.CLEAVE, "main": 110, "spread": 50},
}


## A new pattern: `base` reshaped by `stance`. `base` is not changed.
static func apply(base: GeometryPattern, stance: WeaponStyle.Stance) -> GeometryPattern:
	var r: Dictionary = RULES[stance]
	var p := GeometryPattern.build(base.geometry, base.reach + r.reach, base.facing)
	p.jumps = base.jumps
	p.vertical_reach = base.vertical_reach
	p.pierce = base.pierce + r.pierce
	p.splash = r.splash
	return p


## Damage percent for a hit on a tile of `area`: the aimed tile gets the stance's main percent,
## pierced and splashed tiles its spread percent.
static func damage_percent(stance: WeaponStyle.Stance, area: TargetArea, tile: Vector2i) -> int:
	var r: Dictionary = RULES[stance]
	return r.main if tile == area.aim else r.spread


## Physical damage after the stance: base x percent, rounded, at least 1 when base > 0.
static func scale_damage(base: int, percent: int) -> int:
	return 0 if base <= 0 else maxi(1, roundi(base * percent / 100.0))


## The footprint an attack uses: the style's geometry and reach, reshaped by `stance` for basic weapon
## attacks (skill = null) and Physical skills; bare for the other five proficiencies. No style: King
## geometry, reach 1.
static func footprint(style: WeaponStyle, stance: WeaponStyle.Stance, facing: Vector2i, vertical_reach: int, skill: SkillData = null) -> GeometryPattern:
	var base := GeometryPattern.build(style.geometry if style else TacticalMath.Geometry.KING, style.reach if style else 1, facing)
	base.vertical_reach = vertical_reach
	if skill != null and not skill.is_physical():
		return base
	return apply(base, stance)


static func stance_name(stance: WeaponStyle.Stance) -> String:
	return WeaponStyle.Stance.keys()[stance].capitalize()
