class_name ConsumableItem
extends ItemResource
## A consumable used in battle from the ITEMS command (Claude, Nov 2026; owner: "feel free to also work on an item system"). After the Final Fantasy
## Tactics item bag: using one takes the unit's action, costs no SP, never misses, and the item is gone. The party shares one bag (ItemBag), kept on the
## roster and saved with it; the catalog of items is ItemCatalog.
##   HEAL    restores `amount` + `percent` of the target's max HP (a cursed unit gets half, as with any healing)
##   SP      restores `amount` + `percent` of the target's max SP
##   REVIVE  brings a knocked-out ally back with `percent` of its max HP (at least 1)
##   CURE    removes the statuses in `cures`
##   ELIXIR  everything: full HP and SP, every ailment gone
##   DAMAGE  `amount` damage to each foe in the area (a fixed number: Defense and the guard do not cut it)
## Reach: 0 the user only, 1 the user or a unit next to it (handed over), more = thrown that far. `blast` widens the aimed tile to the tiles round it.

enum Effect { HEAL, SP, REVIVE, CURE, ELIXIR, DAMAGE }

@export var effect: Effect = Effect.HEAL
@export_range(0, 999) var amount := 0
@export_range(0, 100) var percent := 0
@export var cures: Array[String] = []
@export_range(0, 6) var reach := 1
@export_range(0, 3) var blast := 0
@export_range(0, 9999) var price := 0  ## in gold, for a shop to come
@export_range(0, 10) var rarity := 0  ## weight as a battle trophy (0: never found, only bought)


func item_type() -> ItemType:
	return ItemType.CONSUMABLE


## Whether it is used on the user's own side (everything but DAMAGE).
func on_allies() -> bool:
	return effect != Effect.DAMAGE


## HP (HEAL) or SP (SP) it would restore to `bu`, before the room left to fill.
func restore_for(bu: BattleUnit) -> int:
	var top := bu.max_sp() if effect == Effect.SP else bu.max_hp()
	return amount + top * percent / 100


## One line for the list and the aiming hint: what it does.
func effect_text() -> String:
	match effect:
		Effect.HEAL:
			return "Full HP" if percent >= 100 else ("HP +%d" % amount if percent == 0 else "HP +%d and %d%%" % [amount, percent])
		Effect.SP:
			return "Full SP" if percent >= 100 else "SP +%d" % amount
		Effect.REVIVE:
			return "Revive (%d%% HP)" % percent
		Effect.CURE:
			return "Cures %s" % ", ".join(cures.map(func(s): return String(s).replace("_", " ")))
		Effect.ELIXIR:
			return "Full HP and SP, cures all"
		Effect.DAMAGE:
			return "%d damage%s" % [amount, " round the tile" if blast > 0 else ""]
	return ""
