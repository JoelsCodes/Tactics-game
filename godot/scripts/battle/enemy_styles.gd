class_name EnemyStyles
extends RefCounted
## Every enemy gets a random weapon style and a random stance that style allows, rolled new at the start of every battle (owner, Nov 2026).
## They may have any style except the King and the Queen: Rook, Bishop, Knight or Pawn; the stance is Impact or Pierce, and for the Pawn
## also Axe. The tutorial fights (the first battle and the chamber) keep their fixed styles (`BattleSetup.fixed_styles`).


## A random style and stance. `rng` rolls; the style comes back as a new WeaponStyle.
static func roll(rng: RandomNumberGenerator) -> WeaponStyle:
	var geos: Array = StanceRules.ENEMY_STYLES
	var geo: TacticalMath.Geometry = geos[rng.randi() % geos.size()]
	var stances: Array = StanceRules.allowed_stances(geo)
	var s := WeaponStyle.new()
	s.geometry = geo
	s.stance = stances[rng.randi() % stances.size()]
	s.display_name = StanceRules.style_name(geo)
	return s


## Gives `unit` a rolled style (keeping the rest of its loadout).
static func assign(unit: EnemyData, rng: RandomNumberGenerator) -> void:
	if unit.loadout == null:
		unit.loadout = EquipmentLoadout.make(WeaponItem.new(), roll(rng))
	else:
		unit.loadout.weapon_style = roll(rng)
