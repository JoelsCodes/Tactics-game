class_name ItemBag
extends RefCounted
## The party's consumables (ConsumableItem), shared by every unit in a battle: item id -> how many. Backed by the roster's own `items` dictionary when it
## comes from one (`of`), so what a battle uses is gone from the save too; the first time a roster is asked it is given the starter kit (ItemCatalog.STARTER).

var counts := {}  ## StringName id -> int (the roster's dictionary itself when made by `of`)


## The bag of `roster` (its starter kit the first time).
static func of(roster: PartyRoster) -> ItemBag:
	var b := ItemBag.new()
	if roster == null:
		return starter()
	if not roster.items_given:
		roster.items_given = true
		for id in ItemCatalog.STARTER:
			roster.items[id] = int(roster.items.get(id, 0)) + int(ItemCatalog.STARTER[id])
	b.counts = roster.items
	return b


## A bag with the starter kit and no roster behind it (a battle outside the campaign, tests).
static func starter() -> ItemBag:
	var b := ItemBag.new()
	for id in ItemCatalog.STARTER:
		b.counts[id] = int(ItemCatalog.STARTER[id])
	return b


func count(id: StringName) -> int:
	return int(counts.get(id, 0))


func add(id: StringName, n := 1) -> void:
	if n <= 0 or ItemCatalog.get_item(id) == null:
		return
	counts[id] = mini(count(id) + n, ItemCatalog.MAX_STACK)


## Uses one up. False when there is none.
func take(id: StringName) -> bool:
	var n := count(id)
	if n <= 0:
		return false
	if n == 1:
		counts.erase(id)
	else:
		counts[id] = n - 1
	return true


## The items in the bag, in the catalog's order.
func items() -> Array[ConsumableItem]:
	var out: Array[ConsumableItem] = []
	for it in ItemCatalog.all():
		if count(it.id) > 0:
			out.append(it)
	return out


func is_empty() -> bool:
	return items().is_empty()
