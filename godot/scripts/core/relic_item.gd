class_name RelicItem
extends ItemResource
## A prop extracted from the battlefield and slotted into Relic Slot 1 or 2. Relics are also the
## game's accessories (there is no separate accessory slot). Three parts:
##   - skill: the active skill it channels (the skill conduit),
##   - passives: the accessory passive while it is held (e.g. Attack +2, Max SP +2),
##   - drawbacks: the negative trade-off, as stat penalties (e.g. Move -1) and per-turn drains.
## Relics are battle-only by default: they are lost when the battle ends.

@export var skill: SkillData
@export var passives: Array[StatModifier] = []
@export var drawbacks: Array[StatModifier] = []
@export_range(0, 10) var sp_drain_per_turn := 0  ## SP lost at the start of each of the holder's turns
@export_range(0, 30) var hp_drain_per_turn := 0  ## HP lost at the start of each of the holder's turns
@export var battle_only := true


func item_type() -> ItemType:
	return ItemType.RELIC


## Passives and drawbacks together; penalties are just negative modifiers.
func modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = passives.duplicate()
	out.append_array(drawbacks)
	return out


func has_drawback() -> bool:
	return not drawbacks.is_empty() or sp_drain_per_turn > 0 or hp_drain_per_turn > 0
