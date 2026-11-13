extends Node
## The stone-first summon card (owner, Nov 2026): the ranking rule (already learning first, then the fastest learner, then those who know it, the
## blocked last, ties to the last one summoned), and the flow on the battle screen (tap a stone, bars, Enter / click / Esc, the old Summon button).
## godot --headless --path godot res://tests/summon_picker_check.tscn
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
	SaveSystem.dir = "user://test_saves_summonpick"
	ordering()
	await flow()
	print("summon picker checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func _row(name: String, state: int, fill := 0.0, gain := 0, level := 0) -> Dictionary:
	var v := VesselData.new()
	v.display_name = name
	return {"vessel": v, "state": state, "fill": fill, "gain": gain, "level": level}


func _order(rows: Array) -> Array:
	var typed: Array[Dictionary] = []
	typed.assign(rows)
	typed.sort_custom(SummonRanking._before)
	return typed.map(func(r): return r.vessel.display_name)


func ordering() -> void:
	SummonRanking.last_used = ""
	var S := SummonRanking.State
	# someone already learning it beats a faster learner who has not started
	eq(_order([_row("Fast", S.FRESH, 0.0, 9), _row("Slow", S.LEARNING, 0.1, 2)]), ["Slow", "Fast"], "already learning comes before a fast learner")
	# the furthest along first
	eq(_order([_row("A", S.LEARNING, 0.2), _row("B", S.LEARNING, 0.7), _row("C", S.LEARNING, 0.4)]), ["B", "C", "A"], "the furthest along first")
	# nobody in progress: the fastest learner among those who have not learned it
	eq(_order([_row("A", S.FRESH, 0.0, 3), _row("B", S.FRESH, 0.0, 8), _row("C", S.FRESH, 0.0, 5)]), ["B", "C", "A"], "the fastest learner first")
	# those who know it are after those who can still learn it; the blocked are last
	eq(_order([_row("Knows", S.KNOWN, 1.0, 9, 3), _row("Blocked", S.BLOCKED), _row("Fresh", S.FRESH, 0.0, 1), _row("Learning", S.LEARNING, 0.1)]), ["Learning", "Fresh", "Knows", "Blocked"], "learning, fresh, knows it, blocked")
	# a tie goes to the vessel summoned last, then to the name
	SummonRanking.last_used = "B"
	eq(_order([_row("A", S.FRESH, 0.0, 5), _row("B", S.FRESH, 0.0, 5), _row("C", S.FRESH, 0.0, 5)]), ["B", "A", "C"], "a tie: the last one summoned first, then by name")
	SummonRanking.last_used = ""
	eq(_order([_row("Z", S.FRESH, 0.0, 5), _row("M", S.FRESH, 0.0, 5)]), ["M", "Z"], "a tie with no history: by name")
	# the one who knows it least well first among those who know it
	eq(_order([_row("Pro", S.KNOWN, 1.0, 5, 9), _row("Novice", S.KNOWN, 1.0, 5, 1)]), ["Novice", "Pro"], "among those who know it, the lower level first")
	eq(SummonRanking.short_reason("already on the field"), "On the field", "a refusal in a few words")
	eq(SummonRanking.short_reason("too far from the King"), "Out of reach", "...too far")


func flow() -> void:
	BattleStage.pending_game = FirstBattle.chamber_game(FirstBattle.game())
	BattleStage.pending_setup = Riverford.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
	await get_tree().create_timer(0.5).timeout
	var b := s.battle
	var dm := b.deployment
	var king := dm.king
	var guard := 0
	while b.current != king and guard < 80:  # the turns of the others go by until it is the King's
		if b.current != null and b.current.team == 0:
			s.end_turn()
		await get_tree().process_frame
		guard += 1
	await get_tree().create_timer(0.2).timeout
	ok(b.current == king and s.picker != null and not s.picker.visible, "the King's turn, and the card is closed")
	var vessels: Array = s.game.roster.vessels()
	ok(vessels.size() >= 2, "the party has vessels (%d)" % vessels.size())
	# a stone in reach and one out of reach
	var near := Vector2i(-1, -1)
	var far := Vector2i(-1, -1)
	for c in dm.props:
		if dm.in_summon_range(c) and grid_ok(s, c) and near.x < 0:
			near = c
		elif not dm.in_summon_range(c) and far.x < 0:
			far = c
	ok(near.x >= 0, "a stone in reach of the King: %s" % near)
	# the ranking on a real stone: Bram learning it -> Bram first
	var relic: RelicItem = dm.prop_at(near).relic
	var bram: VesselData = vessels[0]
	var lyra: VesselData = vessels[1]
	if bram.skill_tree == null:
		bram.skill_tree = SkillTree.new()
	bram.skill_tree.practice_skill(relic.skill, bram.stats, bram.loadout)
	var rows := SummonRanking.entries(dm, relic, near)
	eq(rows.size(), dm.owned_vessels.size(), "a bar for each vessel")
	var bm := SkillCollection.mastery(bram, relic.skill)
	ok(bm != null and (bm.progress > 0 or bm.is_mastered()), "Bram has started the stone's skill")
	if bm != null and bm.progress > 0 and not bm.is_mastered():
		eq(rows[0].vessel, bram, "Bram, already learning it, is first")
		eq(rows[0].state, SummonRanking.State.LEARNING, "and shown as learning")
		ok(String(rows[0].tag).begins_with("Learning"), "with its percentage in the tag (%s)" % rows[0].tag)
		eq(rows[1].vessel, lyra, "Lyra, who has not started it, is next")
	ok(rows[0].best and rows[0].available, "the first is the best and can be summoned")
	ok(rows[0].state in [SummonRanking.State.LEARNING, SummonRanking.State.KNOWN, SummonRanking.State.FRESH], "it has a state")
	# tap the stone: the card opens beside it
	s.tap_cell(near)
	ok(s.picker.visible and s.picker.cell == near, "tapping a stone in reach opens the card")
	eq(s.picker.rows.size(), dm.owned_vessels.size(), "with a bar for each vessel")
	ok(s.picker.position.x >= 0.0 and s.picker.position.y >= 0.0 and s.picker.position.x + s.picker.size.x <= 1920.0 + 1.0, "placed on the screen (%s, %s)" % [s.picker.position, s.picker.size])
	# the keyboard: Down moves to the next vessel that can be summoned, Enter summons it
	var first: int = s.picker.selected
	s.picker.move(1)
	ok(s.picker.selected != first or s.picker.rows.filter(func(r): return r.available).size() == 1, "Down moves the choice")
	s.picker.move(-1)
	eq(s.picker.selected, first, "Up moves it back")
	# a second tap on the same stone closes it
	s.tap_cell(near)
	ok(not s.picker.visible, "a second tap on the stone closes the card")
	# Esc closes it
	s.tap_cell(near)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	s._unhandled_input(esc)
	ok(not s.picker.visible, "Esc closes the card")
	# a tap on another stone switches the card
	if far.x >= 0:
		s.tap_cell(near)
		s.tap_cell(far)
		ok(s.picker.visible and s.picker.cell == far, "tapping another stone shows that one")
		ok(s.picker.rows.all(func(r): return not r.available), "a stone out of reach opens greyed: nothing can be summoned onto it")
		ok(not s.picker.confirm(), "Enter does nothing on it")
		eq(dm.summons_made, 0, "and nothing was summoned")
		s.cancel()
	# Enter summons the best vessel onto the stone
	s.tap_cell(near)
	var best: VesselData = s.picker.rows[0].vessel
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	s._unhandled_input(enter)
	ok(dm.is_deployed(best), "Enter summoned the best vessel (%s)" % best.display_name)
	eq(dm.summons_made, 1, "one summon was made")
	ok(not s.picker.visible, "the card closed")
	eq(SummonRanking.last_used, String(best.display_name), "it is remembered as the last one summoned")
	ok(dm.prop_at(near) == null, "the stone is spent")
	# the vessel on the field is now blocked on another stone's card
	var other := Vector2i(-1, -1)
	for c in dm.props:
		if dm.in_summon_range(c) and grid_ok(s, c):
			other = c
	if other.x >= 0 and vessels.size() >= 2:
		var rows2 := SummonRanking.entries(dm, dm.prop_at(other).relic, other)
		var mine: Dictionary = rows2.filter(func(r): return r.vessel == best)[0]
		eq(mine.state, SummonRanking.State.BLOCKED, "a vessel already on the field is blocked")
		eq(mine.tag, "On the field", "with its reason")
		ok(rows2[rows2.size() - 1].vessel == best or rows2.filter(func(r): return not r.available).size() > 1, "and last")
		# clicking a bar summons that vessel (the old Summon button path still works too)
		s.tap_cell(other)
		var pick: Dictionary = s.picker.rows.filter(func(r): return r.available)[0] if s.picker.rows.any(func(r): return r.available) else {}
		if not pick.is_empty():
			s.picker.selected = s.picker.rows.find(pick)
			ok(s.picker.confirm(), "choosing a bar summons that vessel")
			ok(dm.is_deployed(pick.vessel), "%s is on the field" % pick.vessel.display_name)
	s.queue_free()
	await get_tree().process_frame


func grid_ok(s: BattleStage, c: Vector2i) -> bool:
	return s.battle.grid.can_stand(c)
