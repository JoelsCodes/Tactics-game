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
	summoning()
	untether_cycle()
	end_of_battle()
	print("units checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## Flat n x n grass. The default 20 x 20 gives a summon radius of 6 tiles.
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


func vessel(name: String, fade := 5) -> VesselData:
	var v := unit(VesselData, name) as VesselData
	v.fade_turns = fade
	return v


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
	ok(c.tick(), "runs out on the last tick")
	ok(not c.tick(), "no tick after running out")
	eq(faded[0], 1, "faded once")
	eq(FadeClock.new().total, 5, "default 5 turns")


func roles() -> void:
	ok(unit(KingData, "K").is_human() and not unit(KingData, "K").decays(), "king human, no decay")
	ok(unit(CoCaptainData, "C").is_human() and not unit(CoCaptainData, "C").decays(), "co-captain immune to decay")
	ok(not unit(VesselData, "V").is_human() and unit(VesselData, "V").decays(), "vessel decays")
	eq((unit(VesselData, "V") as VesselData).sever_count, 0, "sever count starts at 0")
	eq(unit(CoCaptainData, "C").role_name(), "Co Captain", "role name")
	var bu := BattleUnit.new(unit(KingData, "K"))
	eq(bu.hp, 60, "battle unit hp from stats")
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
	eq(m.deploy_error(unit(VesselData, "V"), Vector2i(3, 3)), "vessels are summoned onto relics (summon_vessel)", "vessels only onto relics")
	ok(m.move_unit(kb, Vector2i(0, 1)) and kb.cell == Vector2i(0, 1), "move unit")


func summoning() -> void:
	var g := board()
	var m := manager(g)
	var kb := m.deploy_king(unit(KingData, "King") as KingData, Vector2i(5, 5))
	for i in 7:
		m.place_relic(relic("R%d" % i), Vector2i(2 + i, 8))
	ok(m.place_relic(relic("dup"), Vector2i(2, 8)) == null, "one relic per tile")
	var p := m.prop_at(Vector2i(2, 8))
	ok(p != null and p.get_parent() == m and p.relic.display_name == "R0", "prop instantiated")
	ok(g.can_stand(Vector2i(2, 8)), "props do not block the tile")
	var vd := vessel("V0")
	eq(m.summon_error(vd, Vector2i(0, 0)), "no relic on that tile", "vessels are summoned onto relics")
	var r0 := p.relic
	var v := m.summon_vessel(vd, Vector2i(2, 8))
	ok(v != null and v.is_vessel() and v.data == vd and v.anchor == kb, "vessel summoned, anchored to the King")
	ok(v.cell == Vector2i(2, 8) and g.occupant(Vector2i(2, 8)) == v, "vessel stands where the relic was")
	ok(m.prop_at(Vector2i(2, 8)) == null, "the vessel replaces the prop")
	ok(v.temp_relic() == r0 and vd.loadout.temp_relic == r0, "relic tethered into the Temp-Relic slot")
	eq(v.data.stats.final_stat(StatModifier.Stat.ATTACK, vd.loadout), 9, "temp relic passive applies to the vessel")
	eq(v.fade_clock.turns_left, 5, "fade clock starts at fade_turns")
	eq(m.summon_error(vd, Vector2i(3, 8)), "already on the field", "one vessel, one body")
	for i in range(1, 6):
		ok(m.summon_vessel(vessel("V%d" % i), Vector2i(2 + i, 8)) != null, "vessel %d" % i)
	eq(m.vessel_slots_left(), 0, "six vessels")
	eq(m.summon_error(vessel("V7"), Vector2i(8, 8)), "only 6 Vessels", "seventh refused")
	eq(m.field_units().size(), 7, "King and 6 vessels")
	var nl := vessel("No loadout")
	nl.loadout = null
	var m3 := manager(board())
	m3.deploy_king(unit(KingData, "K") as KingData, Vector2i(5, 5))
	m3.place_relic(relic("r"), Vector2i(6, 6))
	ok(m3.summon_vessel(nl, Vector2i(6, 6)) != null and nl.loadout.temp_relic != null, "a vessel without a loadout gets one")

	# summon range: 30% of the longer side (10 x 6 map -> 3 tiles), straight-line from the King
	var g2 := TacticalGrid.from_rows(["g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0"])
	var m2 := manager(g2)
	for c in [Vector2i(8, 2), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 2), Vector2i(9, 0), Vector2i(6, 2)]:
		m2.place_relic(relic("r"), c)
	var w := vessel("W")
	eq(m2.summon_error(w, Vector2i(8, 2)), "the King must be on the field to summon", "no King, no summon")
	ok(is_equal_approx(m2.summon_radius(), 3.0), "radius is 30% of the longer side")
	var k2 := m2.deploy_king(unit(KingData, "K") as KingData, Vector2i(5, 2))
	ok(m2.can_summon(w, Vector2i(8, 2)), "exactly 3 tiles away")
	ok(m2.can_summon(w, Vector2i(7, 4)), "2.8 tiles diagonally")
	eq(m2.summon_error(w, Vector2i(8, 4)), "too far from the King", "3.6 tiles away")
	eq(m2.summon_error(w, Vector2i(9, 2)), "too far from the King", "4 tiles away")
	m2.move_unit(k2, Vector2i(9, 3))
	ok(m2.can_summon(w, Vector2i(9, 0)), "range follows the King")
	m2.move_unit(k2, Vector2i(6, 2))
	eq(m2.summon_error(w, Vector2i(6, 2)), "tile is blocked or occupied", "someone stands on the relic")
	k2.hp = 0
	eq(m2.summon_error(w, Vector2i(8, 2)), "the King must be on the field to summon", "a fallen King cannot summon")


func untether_cycle() -> void:
	var g := board()
	var m := manager(g)
	m.rng.seed = 7
	var events := []
	m.vessel_untethered.connect(func(_v, home): events.append(home))
	var kb := m.deploy_king(unit(KingData, "King") as KingData, Vector2i(5, 5))
	var cap := m.deploy_co_captain(unit(CoCaptainData, "Cap") as CoCaptainData, Vector2i(4, 4))
	var r := relic("Banner")
	m.place_relic(r, Vector2i(6, 6))
	var vd := vessel("Faint", 2)
	var v := m.summon_vessel(vd, Vector2i(6, 6))
	ok(not m.end_turn(kb) and not m.end_turn(cap), "human turns do not touch it")
	eq(v.fade_clock.turns_left, 2, "only its own turns count")
	ok(cap.fade_clock == null, "co-captain has no fade clock")
	v.hp = 0
	ok(not m.end_turn(v) and not m.end_turn(v), "knocked out: no ticks")
	eq(v.fade_clock.turns_left, 2, "clock paused while knocked out")
	ok(v.on_field, "a knocked-out vessel stays on its tile")
	v.hp = 10
	ok(not m.end_turn(v), "revived: ticks again")
	eq(v.fade_clock.turns_left, 1, "-1 at the end of its turn")
	m.move_unit(v, Vector2i(7, 6))
	ok(m.end_turn(v), "untethered at 0")
	ok(not v.on_field and not g.is_occupied(Vector2i(7, 6)), "untethered vessel leaves the grid")
	eq(vd.sever_count, 1, "sever count +1")
	ok(vd.loadout.temp_relic == null, "Temp-Relic slot emptied")
	eq(m.summon_error(vd, Vector2i(7, 6)) if m.prop_at(Vector2i(7, 6)) else "removed this battle", "removed this battle", "cannot be summoned again this battle")
	if events.back():
		ok(m.secured.has(r) and m.prop_at(Vector2i(7, 6)) == null, "25% hit: relic went home")
	else:
		ok(m.prop_at(Vector2i(7, 6)).relic == r, "miss: relic reappears where the vessel stood")
		var other := m.summon_vessel(vessel("Other"), Vector2i(7, 6))
		ok(other != null and other.temp_relic() == r, "another vessel can tether the reappeared relic")

	# rate of the 25% untether roll; every vessel used once
	var mr := manager(board())
	mr.rng.seed = 99
	mr.deploy_king(unit(KingData, "K") as KingData, Vector2i(5, 5))
	var home := 0
	var trials := 2000
	for i in trials:
		if mr.prop_at(Vector2i(6, 5)) == null:
			mr.place_relic(relic("x"), Vector2i(6, 5))
		var vx := mr.summon_vessel(vessel("x%d" % i, 1), Vector2i(6, 5))
		mr.end_turn(vx)
		if mr.prop_at(Vector2i(6, 5)) == null:
			home += 1
	var rate := float(home) / trials
	ok(rate > .22 and rate < .28, "about 25%% go home on untether (got %.3f)" % rate)
	eq(mr.secured.size(), home, "secured list matches")
	eq(mr.removed.size(), trials, "every untethered vessel is removed for the battle")


func end_of_battle() -> void:
	var m := manager(board())
	m.rng.seed = 12345
	var kd := unit(KingData, "King") as KingData
	var inv := relic("Inventory relic")
	kd.loadout.equip(EquipmentLoadout.Slot.RELIC_SLOT_1, inv)
	m.deploy_king(kd, Vector2i(5, 5))
	var lost := [0]
	m.relic_lost.connect(func(_r): lost[0] += 1)
	var trials := 2000
	var home := 0
	for i in trials:
		var r := relic("V")
		m.place_relic(r, Vector2i(6, 5))
		var vd := vessel("V%d" % i)
		var v := m.summon_vessel(vd, Vector2i(6, 5))
		var haul := m.end_battle()
		home += haul.size()
		ok(haul.is_empty() or haul == [r], "the vessel's own relic or nothing")
		ok(not v.on_field and vd.loadout.temp_relic == null, "vessel left, Temp-Relic emptied")
		eq(vd.sever_count, 0, "end of battle is not an untether")
	eq(home + lost[0], trials, "every relic accounted for")
	var rate := float(home) / trials
	ok(rate > .08 and rate < .12, "about 10%% come home at the end (got %.3f)" % rate)
	ok(kd.loadout.relic_slot_1 == inv, "inventory relics stay equipped after battle")
	m.place_relic(relic("left"), Vector2i(1, 1))
	eq(m.end_battle().size(), 0, "props left on the field are lost")
	eq(m.props.size(), 0, "field cleared")
	ok(m.removed.is_empty(), "removed list resets for the next battle")
