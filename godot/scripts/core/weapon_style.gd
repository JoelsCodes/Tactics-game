class_name WeaponStyle
extends ItemResource
## How the main weapon is used: a chess vector geometry (where it reaches) and a stance (what kind of
## hit it lands). The style is a separate slot from the weapon, so one weapon can be fought with
## different geometries. The stance names the proficiency the style trains.

enum Stance { IMPACT, PIERCE, AXE }

@export var geometry: TacticalMath.Geometry = TacticalMath.Geometry.ROOK
@export var stance: Stance = Stance.IMPACT
## Tiles per ray for sliding geometries (Rook, Bishop, Queen). Knight and King ignore it.
@export_range(1, 8) var reach := 2
## Stat tilt of the stance, e.g. Pierce: Speed +1, Defense -1.
@export var stance_modifiers: Array[StatModifier] = []


func item_type() -> ItemType:
	return ItemType.STYLE


func modifiers() -> Array[StatModifier]:
	return stance_modifiers.duplicate()


## The proficiency this style trains: &"impact", &"pierce" or &"axe".
func proficiency_id() -> StringName:
	return StringName(Stance.keys()[stance].to_lower())


## Reach rays from the unit, nearest tile first (see TacticalMath.geometry_rays).
func rays() -> Array[Array]:
	return TacticalMath.geometry_rays(geometry, reach)


func offsets() -> Array[Vector2i]:
	return TacticalMath.geometry_offsets(geometry, reach)
