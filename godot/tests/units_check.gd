extends Node
## Headless checks for units and deployment (scripts/units): godot --headless --path godot res://tests/units_check.tscn

var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s: got %s, want %s" % [what, a, b])


func _ready() -> void:
	DamageFormula.legacy_numbers()  # this check reads exact numbers from before the FFT-pace tuning (tests/tension_check measures the new ones)
	roles()
	deployment()
	party_members()
	end_of_battle()
	print("units checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## Flat n x n grass.
func board(n := 20) -> TacticalGrid:
	var rows := []
	var row := []
	row.resize(n)
	row.fill("g0")
	for y in n:
		rows.append(" ".join(PackedStringArray(row)))
	return TacticalGrid.from_rows(rows)


func unit(cls, name: String) -> UnitData:
	var u: UnitData = cls.new()
	u.display_name = name
	u.stats = CharacterStats.new()
	u.loadout = EquipmentLoadout.make(WeaponItem.new(), WeaponStyle.new())
	return u


func relic(name: String) -> RelicItem:
	var r := RelicItem.new()
	r.display_name = name
	r.passives = [StatModifier.make(StatModifier.Stat.ATTACK, 3)]
	return r


func vessel(name: String) -> CoCaptainData:
	return unit(CoCaptainData, name) as CoCaptainData


func manager(g: TacticalGrid) -> DeploymentManager:
	var m := DeploymentManager.new()
	add_child(m)
	m.setup(g)
	return m


func roles() -> void:
	ok(unit(KingData, "K").is_human(), "king is human")
	ok(unit(CoCaptainData, "C").is_human(), "a companion is human")
	eq(unit(CoCaptainData, "C").role_name(), "Companion", "role name")
	var bu := BattleUnit.new(unit(KingData, "K"))
	eq(bu.hp, 31, "battle unit hp from stats (level 1)")
	eq(bu.sp, 9, "battle unit sp from stats")


func deployment() -> void:
	var g := board()
	var m := manager(g)
	var king := unit(KingData, "King") as KingData
	var cap := unit(CoCaptainData, "Cap") as CoCaptainData
	ok(not m.ready_to_start(), "no King, no battle")
	var kb := m.deploy_king(king, Vector2i(0, 0))
	ok(kb != null and m.ready_to_start(), "King deployed")
	eq(m.deploy_error(unit(KingData, "K2"), Vector2i(1, 0)), "only 1 King", "one King")
	eq(m.deploy_error(cap, Vector2i(0, 0)), "tile is blocked or occupied", "occupied tile")
	ok(m.deploy_co_captain(cap, Vector2i(1, 0)) != null, "co-captain")
	eq(m.deploy_error(unit(CoCaptainData, "Cap2"), Vector2i(2, 0)), "only 1 Co-Captain", "one co-captain")
	eq(m.deploy_error(king, Vector2i(3, 3)), "already on the field", "no double deploy")
	ok(m.move_unit(kb, Vector2i(0, 1)) and kb.cell == Vector2i(0, 1), "move unit")


## The chosen party is placed at the start of a battle (no summoning, no stones).
func party_members() -> void:
	var g := board()
	var m := manager(g)
	var kb := m.deploy_king(unit(KingData, "King") as KingData, Vector2i(5, 5))
	var vd := vessel("V0")
	var v := m.deploy_party_member(vd, Vector2i(6, 5))
	ok(v != null and v.data == vd, "a party vessel is placed")
	ok(v.cell == Vector2i(6, 5) and g.occupant(Vector2i(6, 5)) == v, "it stands on its tile")
	ok(m.field_units().has(v) and m.is_deployed(vd), "it is on the field")
	ok(m.deploy_party_member(vd, Vector2i(7, 5)) == null, "one body per member")
	ok(m.deploy_party_member(vessel("V1"), Vector2i(6, 5)) == null, "not onto an occupied tile")
	var c1 := m.deploy_party_member(unit(CoCaptainData, "Cap1") as CoCaptainData, Vector2i(4, 5))
	var c2 := m.deploy_party_member(unit(CoCaptainData, "Cap2") as CoCaptainData, Vector2i(3, 5))
	ok(c1 != null and c2 != null and m.co_captain == v and m.extra_captains == [c1, c2], "companions stand as such (the first is `co_captain`)")
	eq(m.field_units().size(), 4, "the King and three members")
	ok(kb != null, "the King is there")


func end_of_battle() -> void:
	var m := manager(board())
	var kd := unit(KingData, "King") as KingData
	var inv := relic("Inventory relic")
	kd.loadout.equip(EquipmentLoadout.Slot.RELIC_SLOT_1, inv)
	m.deploy_king(kd, Vector2i(5, 5))
	var vd := vessel("V")
	var v := m.deploy_party_member(vd, Vector2i(6, 5))
	var haul := m.end_battle()
	ok(haul.is_empty(), "no relic comes home")
	ok(kd.loadout.relic_slot_1 == inv, "inventory relics stay equipped after battle")
