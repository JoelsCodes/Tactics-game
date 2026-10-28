class_name StanceRules
extends RefCounted
## How each stance reshapes a weapon style's footprint. One table, so tuning is one line:
##   Impact  reach -1, the hit bursts into a cross (the tile and its 4 neighbours)
##   Pierce  reach +1, the hit carries on 1 tile behind the target
##   Axe     same reach, the hit cleaves the two tiles beside the target
## Reach never drops below 1. Knight, King and Pawn take one step per ray, so reach changes do
## nothing to them; their splash and pierce still apply.

const RULES := {
	WeaponStyle.Stance.IMPACT: {"reach": -1, "pierce": 0, "splash": GeometryPattern.Splash.CROSS},
	WeaponStyle.Stance.PIERCE: {"reach": 1, "pierce": 1, "splash": GeometryPattern.Splash.NONE},
	WeaponStyle.Stance.AXE: {"reach": 0, "pierce": 0, "splash": GeometryPattern.Splash.CLEAVE},
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


static func stance_name(stance: WeaponStyle.Stance) -> String:
	return WeaponStyle.Stance.keys()[stance].capitalize()
