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
	fade_clock()
	roles()
	deployment()
	severing()
	print("units checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func board() -> TacticalGrid:
	var rows := []
	for y in 8:
		rows.append(" ".join(PackedStringArray(["g0", "g0", "g0", "g0", "g0", "g0", "g0", "g0"])))
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
	return r


func manager(g: TacticalGrid) -> DeploymentManager:
	var m := DeploymentManager.new()
	add_child(m)
	m.setup(g)
	return m


func fade_clock() -> void:
	var c := FadeClock.new(3)
	var faded := [0]
	c.faded.connect(func(): faded[0] += 1)
	ok(not c.tick() and not c.tick(), "two ticks")
	eq(c.turns_left, 1, "one left")
	c.extend(2)
	eq(c.turns_left, 3, "extended")
	c.tick()
	c.tick()
	ok(c.tick(), "fades on the last tick")
	ok(not c.tick(), "no tick after fading")
	eq(faded[0], 1, "faded once")


func roles() -> void:
	ok(unit(KingData, "K").is_human() and not unit(KingData, "K").decays(), "king human, no decay")
	ok(unit(CoCaptainData, "C").is_human() and not unit(CoCaptainData, "C").decays(), "co-captain immune to decay")
	ok(not unit(VesselData, "V").is_human() and unit(VesselData, "V").decays(), "vessel decays")
	eq(unit(CoCaptainData, "C").role_name(), "Co Captain", "role name")
	var bu := BattleUnit.new(unit(KingData, "K"))
	eq(bu.hp, 60, "battle unit hp from stats")
	eq(bu.sp, 9, "battle unit sp from stats")


func deployment() -> void:
	var g := board()
	var m := manager(g)
	var king := unit(KingData, "King") as KingData
	var cap := unit(CoCaptainData, "Cap") as CoCaptainData
	var cap2 := unit(CoCaptainData, "Cap2") as CoCaptainData
	var v0 := unit(VesselData, "V0") as VesselData
	ok(not m.ready_to_start(), "no King, no battle")
	eq(m.deploy_error(v0, Vector2i(1, 1)), "the King must be on the field to summon", "vessel needs the King")
	var kb := m.deploy_king(king, Vector2i(0, 0))
	ok(kb != null and m.ready_to_start(), "King deployed")
	eq(m.deploy_error(unit(KingData, "K2"), Vector2i(1, 0)), "only 1 King", "one King")
	eq(m.deploy_error(cap, Vector2i(0, 0)), "tile is blocked or occupied", "occupied tile")
	ok(m.deploy_co_captain(cap, Vector2i(1, 0)) != null, "co-captain")
	eq(m.deploy_error(cap2, Vector2i(2, 0)), "only 1 Co-Captain", "one co-captain")
	eq(m.deploy_error(king, Vector2i(3, 3)), "already on the field", "no double deploy")
	for i in 6:
		ok(m.summon_vessel(unit(VesselData, "V%d" % i) as VesselData, Vector2i(i, 2)) != null, "vessel %d" % i)
	eq(m.vessel_slots_left(), 0, "six vessels")
	eq(m.deploy_error(unit(VesselData, "V7"), Vector2i(0, 4)), "only 6 Vessels", "seventh refused")
	eq(m.field_units().size(), 8, "8 on the field")
	ok(m.vessels[0].anchor == kb, "anchored to the King")
	ok(g.occupant(Vector2i(3, 2)) == m.vessels[3], "on the grid")
	ok(m.move_unit(kb, Vector2i(0, 1)) and kb.cell == Vector2i(0, 1), "move unit")
	var m2 := manager(board())
	m2.summon_range = 2
	m2.deploy_king(unit(KingData, "K") as KingData, Vector2i(0, 0))
	eq(m2.deploy_error(unit(VesselData, "far"), Vector2i(3, 0)), "too far from the King", "summon range")
	ok(m2.can_deploy(unit(VesselData, "near"), Vector2i(2, 2)), "in summon range")


func severing() -> void:
	var g := board()
	var m := manager(g)
	var dropped := []
	var reasons := []
	m.relic_dropped.connect(func(p): dropped.append(p))
	m.vessel_severed.connect(func(v, r): reasons.append(r))
	var king := unit(KingData, "King") as KingData
	var kb := m.deploy_king(king, Vector2i(4, 4))
	var cap := m.deploy_co_captain(unit(CoCaptainData, "Cap") as CoCaptainData, Vector2i(0, 0))

	# fade: 2 turns, holding two relics -> both drop on its tile
	var vd := unit(VesselData, "Faint") as VesselData
	vd.fade_turns = 2
	vd.loadout.relic_slot_1 = relic("Banner")
	vd.loadout.relic_slot_2 = relic("Lens")
	var v := m.summon_vessel(vd, Vector2i(6, 6))
	ok(not m.start_turn(v), "turn 1")
	eq(v.fade_clock.turns_left, 1, "clock counts down")
	ok(m.start_turn(v), "fades on turn 2")
	ok(not v.on_field and not g.is_occupied(Vector2i(6, 6)), "faded vessel leaves the grid")
	eq(vd.sever_count, 1, "vessel sever count")
	eq(king.sever_count, 1, "King counts the sever")
	eq(m.props_at(Vector2i(6, 6)).size(), 2, "two relic props on the tile")
	eq(dropped.size(), 2, "drop signals")
	ok(dropped[0].get_parent() == m and dropped[0].relic.display_name == "Banner", "prop instantiated with its relic")
	ok(vd.loadout.relics().is_empty(), "relics left the vessel")
	ok(g.can_stand(Vector2i(6, 6)), "props do not block the tile")
	eq(m.deploy_error(vd, Vector2i(6, 6)), "severed this battle", "no resummon")
	ok(not m.start_turn(cap) and cap.fade_clock == null, "co-captain has no fade clock")

	# extraction: next to the King, relics go home and do not drop when severed later
	var hd := unit(VesselData, "Courier") as VesselData
	hd.loadout.relic_slot_1 = relic("Crown")
	var h := m.summon_vessel(hd, Vector2i(1, 7))
	eq(m.extract_relics(h).size(), 0, "too far to extract")
	m.move_unit(h, Vector2i(5, 5))
	eq(m.extract_relics(h).size(), 1, "extracted next to the King")
	m.untether(h)
	eq(m.props_at(Vector2i(5, 5)).size(), 0, "nothing dropped after extracting")
	eq(king.sever_count, 2, "untether counts")

	# King falls: every vessel is cut loose; the co-captain stays
	var a := m.summon_vessel(unit(VesselData, "A") as VesselData, Vector2i(2, 2))
	var b := m.summon_vessel(unit(VesselData, "B") as VesselData, Vector2i(3, 2))
	b.data.loadout.relic_slot_1 = relic("Shard")
	kb.hp = 0
	m.unit_fell(kb)
	ok(m.vessels.is_empty() and not a.on_field and not b.on_field, "King's fall severs all vessels")
	ok(cap.on_field, "co-captain stays")
	eq(m.props_at(Vector2i(3, 2)).size(), 1, "relic dropped where B stood")
	eq(reasons, [DeploymentManager.SeverReason.FADED, DeploymentManager.SeverReason.UNTETHERED, DeploymentManager.SeverReason.KING_FELL, DeploymentManager.SeverReason.KING_FELL], "sever reasons")
	eq(m.deploy_error(unit(VesselData, "C"), Vector2i(7, 0)), "the King must be on the field to summon", "fallen King cannot summon")
	eq(king.sever_count, 4, "King's total")
	eq(m.pick_up(Vector2i(6, 6)).size(), 2, "pick up props")
	eq(m.props_at(Vector2i(6, 6)).size(), 0, "tile cleared")
	eq(m.end_battle().size(), 1, "haul: one extracted relic")
