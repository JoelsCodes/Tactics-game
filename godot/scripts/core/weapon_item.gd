class_name WeaponItem
extends ItemResource
## A unit's main weapon. It is bound to the unit for good: the player cannot swap it (see
## EquipmentLoadout), only improve it through smithing. Smithing raises `smith_level` (0-99), which
## scales power by 1 + 0.02 x level and moves the weapon through the smithing tiers.
##
## Give each unit its own copy (`duplicate()`), since smithing changes the resource.

signal smithed(new_level: int)

## Smithing tiers: the level each tier starts at, and its name. Masterwork is level 99 only.
const TIER_LEVELS: Array[int] = [0, 25, 50, 75, 99]
const TIER_NAMES: Array[String] = ["Raw", "Tempered", "Honed", "Refined", "Masterwork"]

@export_range(1, 30) var base_power := 8  ## low on purpose: HP pools are 50-300
@export_range(0, 99) var smith_level := 0


func item_type() -> ItemType:
	return ItemType.WEAPON


## Weapon power at the current smithing level.
func power() -> int:
	return TacticalMath.scale(base_power, smith_level)


## Tier index 0..4 for the current smithing level.
func tier() -> int:
	var t := 0
	for i in TIER_LEVELS.size():
		if smith_level >= TIER_LEVELS[i]:
			t = i
	return t


func tier_name() -> String:
	return TIER_NAMES[tier()]


## Raises the smithing level (the only way a main weapon changes). Returns the levels actually gained.
func smith_upgrade(levels := 1) -> int:
	var before := smith_level
	smith_level = TacticalMath.clamp_level(smith_level + maxi(levels, 0))
	if smith_level != before:
		smithed.emit(smith_level)
		emit_changed()
	return smith_level - before
