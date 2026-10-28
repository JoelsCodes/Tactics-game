class_name AccessoryItem
extends ItemResource
## General stat tuning, including SP pool changes (a MAX_SP modifier). No skill, no drawback.
## Note: the four loadout slots do not take accessories yet (see EquipmentLoadout).

@export var bonuses: Array[StatModifier] = []


func item_type() -> ItemType:
	return ItemType.ACCESSORY


func modifiers() -> Array[StatModifier]:
	return bonuses.duplicate()
