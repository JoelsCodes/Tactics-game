class_name PartyRoster
extends Resource
## The player's party between battles: the King (fixed on every mission), his companions (`co_captains`: every other member, the type keeps its old name)
## with the battle party chosen from them (below), and the permanent relic inventory.
##
## A relic is in exactly one place: the inventory (spare), or a Relic Slot 1 / 2 of one unit. Use
## RosterManager to move them, so the rule holds.

@export var king: KingData
@export var co_captains: Array[CoCaptainData] = []
## Spare permanent relics (not equipped by anyone): equipped in Relic Slot 1 or 2 from the menus; never
## placed on the field.
@export var relic_inventory: Array[RelicItem] = []


## The battle party (owner, Nov 2026): the Formation pop-up before a battle picks up to PARTY_SIZE members of the company to fight beside the King; the
## choice is remembered and saved. `party_names` is the last confirmed pick (display names, in order); `party_known` is every company member there was when it
## was confirmed, so someone who joins later fills a free slot without undoing a smaller party the player chose on purpose.
const PARTY_SIZE := 3
@export var party_names: Array[String] = []
@export var party_known: Array[String] = []


## Everyone who can fight beside the King: his companions.
func company() -> Array[UnitData]:
	var out: Array[UnitData] = []
	out.append_array(co_captains)
	return out


## Who goes into the next battle, in order: the remembered pick (anyone who has left the company is dropped), then newcomers into free slots. A roster that
## has never been picked takes the first PARTY_SIZE of the company.
func party() -> Array[UnitData]:
	var comp := company()
	var out: Array[UnitData] = []
	for n in party_names:
		for u in comp:
			if u.display_name == n and not out.has(u) and out.size() < PARTY_SIZE:
				out.append(u)
				break
	if party_known.is_empty() and party_names.is_empty():
		for u in comp:
			if out.size() < PARTY_SIZE and not out.has(u):
				out.append(u)
	else:
		for u in comp:
			if out.size() < PARTY_SIZE and not out.has(u) and not party_known.has(u.display_name):
				out.append(u)
	return out


## Remembers a pick (the Formation pop-up's Fight): at most PARTY_SIZE company members, in the order given.
func set_party(members: Array) -> void:
	party_names.clear()
	for u in members:
		if u is UnitData and company().has(u) and not party_names.has(u.display_name) and party_names.size() < PARTY_SIZE:
			party_names.append(u.display_name)
	party_known.clear()
	for u in company():
		party_known.append(u.display_name)
	emit_changed()


## The spare relics grouped into stacks (RelicDrop.stacks): the same move shows once, as x2, x3.
func relic_stacks() -> Array[Dictionary]:
	return RelicDrop.stacks(relic_inventory)


## The King first, then his companions.
func humans() -> Array[UnitData]:
	var out: Array[UnitData] = []
	if king:
		out.append(king)
	out.append_array(co_captains)
	return out


## Every unit in the party: the King, then his companions.
func all_units() -> Array[UnitData]:
	return humans()


## Problems with the roster's consistency (empty when fine): a relic in two places.
func audit() -> Array[String]:
	var out: Array[String] = []
	var where := {}  ## relic -> where it was first found
	for r in relic_inventory:
		if where.has(r):
			out.append("relic '%s' is in the inventory twice" % r.display_name)
		where[r] = "the inventory"
	for u in all_units():
		if u.loadout == null:
			continue
		for r in [u.loadout.relic_slot_1, u.loadout.relic_slot_2]:
			if r == null:
				continue
			if where.has(r):
				out.append("relic '%s' is in %s and on %s" % [r.display_name, where[r], u.display_name])
			where[r] = u.display_name
	return out


## "GEOMETRY:STANCE", the key a style and stance are stored under (each unit keeps its own found styles: `UnitData.known_styles`).
static func style_key(geometry: TacticalMath.Geometry, stance: WeaponStyle.Stance) -> String:
	return "%s:%s" % [TacticalMath.Geometry.keys()[geometry], WeaponStyle.Stance.keys()[stance]]


## A new WeaponStyle for a key (null for a key that does not name a style and stance).
static func style_from_key(key: String) -> WeaponStyle:
	var parts := key.split(":")
	if parts.size() != 2 or not TacticalMath.Geometry.keys().has(parts[0]) or not WeaponStyle.Stance.keys().has(parts[1]):
		return null
	var s := WeaponStyle.new()
	s.geometry = TacticalMath.Geometry[parts[0]]
	s.stance = WeaponStyle.Stance[parts[1]]
	s.display_name = StanceRules.style_name(s.geometry)
	return s


## Adds relics brought home from a battle (DeploymentManager.end_battle) to the inventory.
func receive_relics(relics: Array[RelicItem]) -> void:
	for r in relics:
		if not relic_inventory.has(r):
			relic_inventory.append(r)
	emit_changed()
