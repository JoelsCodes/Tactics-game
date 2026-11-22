class_name RelicItem
extends ItemResource
## A relic. Relics are also the game's accessories (there is no separate accessory slot). Three parts:
##   - skill: the active skill it channels (the skill conduit),
##   - passives: the accessory passive while it is held (e.g. Attack +2, Max SP +2),
##   - drawbacks: the negative trade-off, as stat penalties (e.g. Move -1) and per-turn drains.
##
## Where it lives: an enemy drops one when it is defeated (RelicDrop), it waits in the inventory (stacked as x2, x3) and is equipped in Relic Slot 1 or 2 at
## the base. The unit that uses its skill trains it; at mastery the relic breaks and the skill is the unit's for good.

@export var skill: SkillData
@export var passives: Array[StatModifier] = []
@export var drawbacks: Array[StatModifier] = []
@export_range(0, 10) var sp_drain_per_turn := 0  ## SP lost at the start of each of the holder's turns
@export_range(0, 30) var hp_drain_per_turn := 0  ## HP lost at the start of each of the holder's turns


func item_type() -> ItemType:
	return ItemType.RELIC


## Passives and drawbacks together; penalties are just negative modifiers.
func modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = passives.duplicate()
	out.append_array(drawbacks)
	return out


## One line for lists and details: name, skill, passives and trade-offs.
func describe() -> String:
	var parts: Array[String] = []
	if skill:
		parts.append("%s (%s, SP %d)" % [skill.display_name, Proficiency.short_name(skill.category), skill.sp_cost])
	if not passives.is_empty():
		parts.append(", ".join(passives.map(func(m): return m.describe())))
	var trade: Array[String] = []
	for m in drawbacks:
		trade.append(m.describe())
	if sp_drain_per_turn > 0:
		trade.append("SP -%d/turn" % sp_drain_per_turn)
	if hp_drain_per_turn > 0:
		trade.append("HP -%d/turn" % hp_drain_per_turn)
	if not trade.is_empty():
		parts.append("Trade-off: " + ", ".join(trade))
	return display_name if parts.is_empty() else "%s  ·  %s" % [display_name, "  ·  ".join(parts)]


func has_drawback() -> bool:
	return not drawbacks.is_empty() or sp_drain_per_turn > 0 or hp_drain_per_turn > 0
