class_name StanceComponent
extends Node
## Holds a unit's active stance and footprint. Add it as a child of a unit node and give it the
## unit's WeaponStyle; switching stance rebuilds the footprint at once and emits `footprint_changed`.
## The WeaponStyle resource is never modified: the style's own stance is only the starting stance.

signal stance_changed(stance: WeaponStyle.Stance)
signal footprint_changed(pattern: GeometryPattern)

@export var style: WeaponStyle:
	set(value):
		style = value
		if style != null:
			stance = style.stance
		_rebuild()
## The active stance. Setting it switches stance.
@export var stance: WeaponStyle.Stance = WeaponStyle.Stance.IMPACT:
	set(value):
		if value == stance and _pattern != null:
			return
		stance = value
		_rebuild()
		stance_changed.emit(stance)
## Board direction the unit faces (orthogonal unit vector). Only Pawn footprints depend on it.
@export var facing := Vector2i(0, 1):
	set(value):
		if value == facing:
			return
		facing = value
		_rebuild()
## Height levels the unit can hit above or below itself.
@export_range(0, 8) var vertical_reach := 3:
	set(value):
		vertical_reach = value
		_rebuild()

var _pattern: GeometryPattern


## The current footprint (stance applied).
func footprint() -> GeometryPattern:
	if _pattern == null:
		_rebuild()
	return _pattern


func set_stance(s: WeaponStyle.Stance) -> void:
	stance = s


## Switches to the next stance (Impact -> Pierce -> Axe -> Impact). Returns the new stance.
func cycle_stance() -> WeaponStyle.Stance:
	stance = ((stance + 1) % WeaponStyle.Stance.size()) as WeaponStyle.Stance
	return stance


## The proficiency the active stance trains (&"impact", &"pierce", &"axe").
func proficiency_id() -> StringName:
	return StringName(WeaponStyle.Stance.keys()[stance].to_lower())


func targetable(grid: TacticalGrid, origin: Vector2i) -> Array[Vector2i]:
	return GeometryResolver.targetable(grid, origin, footprint())


func affected(grid: TacticalGrid, origin: Vector2i, aim: Vector2i) -> TargetArea:
	return GeometryResolver.affected(grid, origin, footprint(), aim)


func _rebuild() -> void:
	var base := GeometryPattern.build(style.geometry if style else TacticalMath.Geometry.KING, style.reach if style else 1, facing)
	base.vertical_reach = vertical_reach
	_pattern = StanceRules.apply(base, stance)
	footprint_changed.emit(_pattern)
