class_name ItemResource
extends Resource
## Base class for everything a unit can hold. Subclasses: WeaponItem, WeaponStyle, RelicItem.
## There is no separate accessory: relics carry the accessory passives. Stat changes go through
## `modifiers()`, so the loadout can sum any item the same way.

enum ItemType { WEAPON, WEAPON_STYLE, RELIC }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D


## The item's type. Each subclass returns its own.
func item_type() -> ItemType:
	push_error("ItemResource.item_type() must be overridden")
	return ItemType.RELIC


## Every stat change this item applies while equipped (bonuses and penalties). None by default.
func modifiers() -> Array[StatModifier]:
	return []
