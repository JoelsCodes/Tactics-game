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


## A relic that manifests into its own vessel.
func relic(name: String, fade := 5) -> RelicItem:
	var r := RelicItem.new()
	r.display_name = name
	r.vessel = unit(VesselData, name + " vessel") as VesselData
	r.vessel.fade_turns = fade
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
	eq(m.deploy_error(unit(VesselData, "V"), Vector2i(3, 3)), "vessels are summoned from relics (summon_vessel)", "vessels only from relics")
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
	eq(m.summon_error(Vector2i(0, 0)), "no relic on that tile", "needs a relic")
	var r0 := p.relic
	var v := m.summon_vessel(Vector2i(2, 8))
	ok(v != null and v.is_vessel() and v.data == r0.vessel, "relic manifests into its vessel")
	ok(v.relic == r0 and v.anchor == kb, "vessel carries its relic, anchored to the King")
	ok(v.cell == Vector2i(2, 8) and g.occupant(Vector2i(2, 8)) == v, "vessel stands on the relic's tile")
	ok(m.prop_at(Vector2i(2, 8)) == null, "prop used up")
	eq(v.fade_clock.turns_left, 5, "fade clock starts at fade_turns")
	for i in range(1, 6):
		ok(m.summon_vessel(Vector2i(2 + i, 8)) != null, "vessel %d" % i)
	eq(m.vessel_slots_left(), 0, "six vessels")
	eq(m.summon_error(Vector2i(8, 8)), "only 6 Vessels", "seventh refused")
	eq(m.field_units().size(), 7, "King and 6 vessels")

	# summon range: 30% of the longer side (10 x 6 map -> 3 tiles), straight-line from the King
	var g2 := TacticalGrid.from_rows(["g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0", "g0 g0 g0 g0 g0 g0 g0 g0 g0 g0"])
	var m2 := manager(g2)
	for c in [Vector2i(8, 2), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 2), Vector2i(9, 0), Vector2i(6, 2)]:
		m2.place_relic(relic("r"), c)
	eq(m2.summon_error(Vector2i(8, 2)), "the King must be on the field to summon", "no King, no summon")
	ok(is_equal_approx(m2.summon_radius(), 3.0), "radius is 30% of the longer side")
	var k2 := m2.deploy_king(unit(KingData, "K") as KingData, Vector2i(5, 2))
	ok(m2.can_summon(Vector2i(8, 2)), "exactly 3 tiles away")
	ok(m2.can_summon(Vector2i(7, 4)), "2.8 tiles diagonally")
	eq(m2.summon_error(Vector2i(8, 4)), "too far from the King", "3.6 tiles away")
	eq(m2.summon_error(Vector2i(9, 2)), "too far from the King", "4 tiles away")
	m2.move_unit(k2, Vector2i(9, 3))
	ok(m2.can_summon(Vector2i(9, 0)), "range follows the King")
	m2.move_unit(k2, Vector2i(6, 2))
	eq(m2.summon_error(Vector2i(6, 2)), "tile is blocked or occupied", "someone stands on the relic")
	k2.hp = 0
	eq(m2.summon_error(Vector2i(8, 2)), "the King must be on the field to summon", "a fallen King cannot summon")


func untether_cycle() -> void:
	var g := board()
	var m := manager(g)
	m.rng.seed = 7
	var events := []
	m.vessel_untethered.connect(func(v, home): events.append(home))
	var kb := m.deploy_king(unit(KingData, "King") as KingData, Vector2i(5, 5))
	var cap := m.deploy_co_captain(unit(CoCaptainData, "Cap") as CoCaptainData, Vector2i(4, 4))
	var r := relic("Banner", 2)
	m.place_relic(r, Vector2i(6, 6))
	var v := m.summon_vessel(Vector2i(6, 6))
	ok(not m.end_turn(kb) and not m.end_turn(cap), "human turns do not touch it")
	eq(v.fade_clock.turns_left, 2, "only its own turns count")
	ok(not m.end_turn(v), "ends turn 1")
	eq(v.fade_clock.turns_left, 1, "-1 at the end of its turn")
	ok(cap.fade_clock == null, "co-captain has no fade clock")

	# keep cycling the same relic until it goes home: each untether is +1 sever, a miss puts it back
	var cycles := 0
	while true:
		m.move_unit(v, Vector2i(7, 6))  # vessels can walk off the relic's original tile
		while not m.end_turn(v):
			pass
		cycles += 1
		ok(not v.on_field and not g.is_occupied(Vector2i(7, 6)), "untethered vessel leaves the grid")
		eq(r.vessel.sever_count, cycles, "sever count +1 per untether")
		if events.back():
			ok(m.prop_at(Vector2i(7, 6)) == null and m.secured.has(r), "25% hit: relic went home")
			break
		ok(m.prop_at(Vector2i(7, 6)) != null and m.prop_at(Vector2i(7, 6)).relic == r, "miss: relic reappears where the vessel stood")
		v = m.summon_vessel(Vector2i(7, 6))
		ok(v != null and v.fade_clock.turns_left == 2, "summoned again with a fresh fade clock")
		if cycles > 50:
			break
	ok(cycles >= 1 and cycles <= 50, "relic eventually went home (%d cycles)" % cycles)

	# rate of the 25% untether roll
	var mr := manager(board())
	mr.rng.seed = 99
	mr.deploy_king(unit(KingData, "K") as KingData, Vector2i(5, 5))
	var home := 0
	var trials := 2000
	for i in trials:
		mr.place_relic(relic("x", 1), Vector2i(6, 5))
		var vx := mr.summon_vessel(Vector2i(6, 5))
		mr.end_turn(vx)
		if mr.prop_at(Vector2i(6, 5)) == null:
			home += 1
		else:
			mr.props[Vector2i(6, 5)].queue_free()
			mr.props.erase(Vector2i(6, 5))
	var rate := float(home) / trials
	ok(rate > .22 and rate < .28, "about 25%% go home on untether (got %.3f)" % rate)
	eq(mr.secured.size(), home, "secured list matches")


func end_of_battle() -> void:
	var m := manager(board())
	m.rng.seed = 12345
	m.deploy_king(unit(KingData, "King") as KingData, Vector2i(5, 5))
	var lost := [0]
	m.relic_lost.connect(func(_r): lost[0] += 1)
	var trials := 2000
	var home := 0
	for i in trials:
		var r := relic("V")
		m.place_relic(r, Vector2i(6, 5))
		var v := m.summon_vessel(Vector2i(6, 5))
		var haul := m.end_battle()
		home += haul.size()
		ok(haul.is_empty() or haul == [r], "the vessel's own relic or nothing")
		ok(not v.on_field and v.relic == null, "vessel left the field")
		eq(r.vessel.sever_count, 0, "end of battle is not an untether")
	eq(home + lost[0], trials, "every relic accounted for")
	var rate := float(home) / trials
	ok(rate > .08 and rate < .12, "about 10%% come home at the end (got %.3f)" % rate)
	m.place_relic(relic("left"), Vector2i(1, 1))
	eq(m.end_battle().size(), 0, "props left on the field are lost")
	eq(m.props.size(), 0, "field cleared")
