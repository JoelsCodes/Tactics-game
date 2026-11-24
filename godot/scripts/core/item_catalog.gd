class_name ItemCatalog
extends RefCounted
## Every consumable in the game (ConsumableItem), after Final Fantasy Tactics' item list, sized for this game's small HP and SP pools (a unit has 20-130
## HP and 10-30 SP): a Potion is about a fifth of a bar, a Hi-Potion about half, an X-Potion all of it. Built in code so the numbers sit in one place.
## Bought in a shop to come (`price`), found after a won battle (`trophies`, weighted by `rarity`), and the party starts with STARTER.

const MAX_STACK := 99
## What a new party carries the first time it fights (ItemBag.of).
const STARTER := {&"potion": 4, &"hi_potion": 1, &"ether": 2, &"phoenix_down": 2, &"antidote": 2, &"remedy": 1, &"firebomb": 2}

static var _all: Array[ConsumableItem] = []
static var _by_id := {}


static func _make(id: StringName, name: String, desc: String, effect: ConsumableItem.Effect, amount: int, percent: int, reach: int, price: int, rarity: int,
		cures: Array[String] = [], blast := 0) -> void:
	var it := ConsumableItem.new()
	it.id = id
	it.display_name = name
	it.description = desc
	it.effect = effect
	it.amount = amount
	it.percent = percent
	it.reach = reach
	it.price = price
	it.rarity = rarity
	it.cures = cures
	it.blast = blast
	_all.append(it)
	_by_id[id] = it


static func _build() -> void:
	if not _all.is_empty():
		return

	_make(&"potion", "Potion", "A common restorative. Restores 12 HP and a fifth of the bar.", ConsumableItem.Effect.HEAL, 12, 20, 1, 50, 10)
	_make(&"hi_potion", "Hi-Potion", "A stronger draught. Restores 25 HP and a third of the bar.", ConsumableItem.Effect.HEAL, 25, 35, 1, 200, 5)
	_make(&"x_potion", "X-Potion", "Restores every point of HP.", ConsumableItem.Effect.HEAL, 0, 100, 1, 700, 2)
	_make(&"ether", "Ether", "Restores 6 SP.", ConsumableItem.Effect.SP, 6, 0, 1, 200, 5)
	_make(&"hi_ether", "Hi-Ether", "Restores every point of SP.", ConsumableItem.Effect.SP, 0, 100, 1, 600, 2)
	_make(&"phoenix_down", "Phoenix Down", "A feather that rekindles life: brings a fallen ally back with a quarter of its HP.", ConsumableItem.Effect.REVIVE, 0, 25, 1, 300, 4)
	_make(&"antidote", "Antidote", "Cures poison and burns.", ConsumableItem.Effect.CURE, 0, 0, 1, 40, 6, ["poison", "burn"] as Array[String])
	_make(&"eye_drops", "Eye Drops", "Clears the eyes: cures blindness.", ConsumableItem.Effect.CURE, 0, 0, 1, 40, 4, ["blind", "mild_blind"] as Array[String])
	_make(&"echo_herbs", "Echo Herbs", "Restores the voice: cures silence.", ConsumableItem.Effect.CURE, 0, 0, 1, 60, 3, ["silence"] as Array[String])
	_make(&"holy_water", "Holy Water", "Lifts curses and the doom count.", ConsumableItem.Effect.CURE, 0, 0, 1, 150, 2, ["curse", "doom"] as Array[String])
	_make(&"smelling_salts", "Smelling Salts", "Wakes and steadies: cures sleep, stun, confusion and berserk.", ConsumableItem.Effect.CURE, 0, 0, 1, 80, 3,
			["sleep", "stun", "confuse", "berserk"] as Array[String])
	_make(&"remedy", "Remedy", "Cures every ailment.", ConsumableItem.Effect.CURE, 0, 0, 1, 350, 2, BattleUnit.NEGATIVE.duplicate())
	_make(&"elixir", "Elixir", "A rare cordial: full HP and SP, and every ailment gone.", ConsumableItem.Effect.ELIXIR, 0, 100, 1, 0, 1)
	_make(&"firebomb", "Firebomb", "A clay pot of oil and pitch, thrown up to three tiles: 14 damage to each foe on the tile and round it.", ConsumableItem.Effect.DAMAGE, 14, 0, 3, 120, 4,
			[] as Array[String], 1)


static func all() -> Array[ConsumableItem]:
	_build()
	return _all


static func get_item(id: StringName) -> ConsumableItem:
	_build()
	return _by_id.get(id)


## What a won battle leaves behind: one item, two against five foes or more, drawn by rarity. id -> count.
static func trophies(rng: RandomNumberGenerator, foes: int) -> Dictionary:
	_build()
	var out := {}
	var pool := _all.filter(func(it): return it.rarity > 0)
	var total := 0
	for it in pool:
		total += it.rarity
	for k in (2 if foes >= 5 else 1):
		var roll := rng.randi_range(1, total)
		for it in pool:
			roll -= it.rarity
			if roll <= 0:
				out[it.id] = int(out.get(it.id, 0)) + 1
				break
	return out
