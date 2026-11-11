extends Node
## Headless checks for the collecting side of skills: what a vessel can teach (relic skills and the ones it mastered), Mentor Bonds,
## the Skill Journal, new skills on stones, the training a battle records, the battle's skill menu (rows with levels and bars, the
## detail pane with a description), the progress strip, the SKILL MASTERED card and the skill bars on the results.
## godot --headless --path godot res://tests/collect_check.tscn
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
	SaveSystem.dir = "user://test_saves_collect_check"
	teaching()
	bonds()
	journal()
	collection()
	await battle_flow()
	await menu_order()
	print("collect checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func party() -> SaveGame:
	return FirstBattle.chamber_game(FirstBattle.game())


func teaching() -> void:
	var g := party()
	var bram: VesselData = g.roster.vessels()[0]
	var king := g.roster.king
	var before := Mentorship.offers(bram).size()
	var jab := SkillLibrary.find("Quick Jab")
	ok(not Mentorship.offers(bram).any(func(o): return o.skill == jab), "a vessel does not offer a skill it has only heard of")
	ok(Mentorship.study_error(king, bram, jab) != "", "and it cannot be studied from it")
	var m := SkillMastery.make(jab)
	Mentorship.tree_of(bram).masteries.append(m)
	m.progress = 50
	eq(Mentorship.offers(bram).size(), before, "a skill still being practised is not offered")
	m.level = 1
	var offers := Mentorship.offers(bram)
	eq(offers.size(), before + 1, "a mastered skill is offered")
	var mine: Mentorship.Offer = offers.filter(func(o): return o.skill == jab)[0]
	ok(mine.relic == null, "with no relic: the vessel teaches it itself")
	eq(Mentorship.study_error(king, bram, jab), "", "the King can study it")
	var study := Mentorship.start_study(king, bram, jab)
	ok(study != null and study.mentor_name == bram.display_name, "and the study remembers who teaches it")
	ok(SkillCollection.describe(jab) != "", "every skill has a description")
	var bare := SkillData.new()
	bare.display_name = "Nameless"
	ok(SkillCollection.describe(bare).length() > 20, "a skill with no text gets a plain line made from what it is")


func bonds() -> void:
	var g := party()
	var bram: VesselData = g.roster.vessels()[0]
	var king := g.roster.king
	var jab := SkillLibrary.find("Quick Jab")
	var vm := SkillMastery.make(jab)
	vm.level = 1
	Mentorship.tree_of(bram).masteries.append(vm)
	var tree := Mentorship.tree_of(king)
	eq(tree.bond_level(bram.display_name), 0, "no bond before any study")
	Mentorship.start_study(king, bram, jab)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var uses := 0
	while not tree.is_learned(jab) and uses < 60:
		tree.use_skill(jab, king.stats, 1, king.loadout, rng)
		uses += 1
	ok(tree.is_learned(jab), "the King learns the skill by using it (%d uses)" % uses)
	var pts := tree.bond_points(bram.display_name)
	ok(pts >= SkillTree.BOND_PER_LEVEL + SkillTree.BOND_LEARN - 1, "studying it grew the bond: the bar's points plus the bonus for learning it (%d)" % pts)
	ok(tree.bond_level(bram.display_name) >= 1, "which is at least bond level 1")
	ok(is_equal_approx(tree.bond_bonus(bram.display_name), SkillTree.BOND_BONUS * tree.bond_level(bram.display_name)), "each level is worth 3% study speed")
	var after := tree.bond_points(bram.display_name)
	tree.use_skill(jab, king.stats, 3, king.loadout, rng)
	eq(tree.bond_points(bram.display_name), after, "using a skill already learned does not grow the bond")
	tree.add_bond(bram.display_name, 99999)
	eq(tree.bond_level(bram.display_name), SkillTree.BOND_MAX, "the bond stops at its top level")
	eq(tree.bond_bar(bram.display_name), [0, 0], "and has no bar left")
	eq(tree.add_bond("", 50), 0, "a skill with no mentor grows no bond")
	# faster study with a bond: the same rolls give more points
	var slow := SkillTree.new()
	var fast := SkillTree.new()
	fast.add_bond("Bram", SkillTree.BOND_PER_LEVEL * SkillTree.BOND_MAX)
	var hop := SkillLibrary.find("Hop")
	slow.start_study(hop, "Bram")
	fast.start_study(hop, "Bram")
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 9
	r2.seed = 9
	slow.use_skill(hop, king.stats, 1, king.loadout, r1)
	fast.use_skill(hop, king.stats, 1, king.loadout, r2)
	ok(fast.mastery_of(hop).progress + fast.mastery_of(hop).level * 100 > slow.mastery_of(hop).progress + slow.mastery_of(hop).level * 100, "a full bond makes the study bar fill faster")
	var back := SaveCodec.decode(SaveCodec.encode(g))
	ok(back.ok and back.game.roster.king.skill_tree.bond_level(bram.display_name) == SkillTree.BOND_MAX, "bonds are saved and loaded")
	var lines := BarracksScreen.journal_lines(g)
	ok(lines.any(func(l): return l.contains("Mentor Bond") and l.contains(bram.display_name)), "the Records page lists the bond")


func journal() -> void:
	var g := party()
	var c := g.campaign
	ok(c.record_skill("Quick Jab", "Bram", "a summon stone", "1: The Back Alleys"), "a mastered skill goes into the journal")
	ok(not c.record_skill("Quick Jab", "Bram", "a summon stone", "elsewhere"), "once per unit and skill")
	ok(c.record_skill("Quick Jab", "Alaric", "studied from Bram", ""), "another unit's mastery is its own entry")
	ok(not c.record_skill("", "Bram", "", ""), "nothing without a skill")
	eq(c.skill_journal.size(), 2, "two entries")
	var back := SaveCodec.decode(SaveCodec.encode(g))
	ok(back.ok and back.game.campaign.skill_journal.size() == 2 and back.game.campaign.skill_journal[0].source == "a summon stone", "the journal is saved and loaded")
	var old := SaveCodec.encode(g)
	(old["campaign"] as Dictionary).erase("skill_journal")
	var loaded := SaveCodec.decode(old)
	ok(loaded.ok and loaded.game.campaign.skill_journal.is_empty(), "a save from before the journal loads with none")
	var lines := BarracksScreen.journal_lines(g)
	ok(lines[0].contains("Alaric mastered Quick Jab"), "the Records page shows the newest first")


func collection() -> void:
	var g := party()
	var bram: VesselData = g.roster.vessels()[0]
	var jab := SkillLibrary.find("Quick Jab")
	ok(SkillCollection.is_new(g, jab), "a skill nobody has mastered is new")
	var n0 := SkillCollection.collected(g)
	var m := SkillMastery.make(jab)
	m.level = 1
	Mentorship.tree_of(bram).masteries.append(m)
	ok(not SkillCollection.is_new(g, jab) and SkillCollection.collected(g) == n0 + 1, "once mastered it counts as collected")
	ok(SkillCollection.total() >= 150, "out of every skill in the game (%d)" % SkillCollection.total())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var changed := 0
	for i in 40:
		var relic := RelicItem.new()
		relic.skill = jab
		var other := RelicItem.new()
		other.skill = SkillLibrary.find("Hop")
		var relics := [[relic, Vector2i(0, 0)], [other, Vector2i(1, 0)]]
		changed += SkillCollection.freshen(relics, g, rng)
		ok(relic.skill.rank == jab.rank, "a freshened stone keeps its rank")
		ok(relic.skill == jab or SkillCollection.is_new(g, relic.skill), "and carries a skill that is new to the party")
		ok(other.skill == SkillLibrary.find("Hop"), "a stone whose skill is still new is left alone")
	ok(changed > 10 and changed < 40, "some stones with a mastered skill, not all, become new ones (%d of 40)" % changed)


func make_stage() -> BattleStage:
	BattleStage.pending_game = party()
	BattleStage.pending_setup = WorldData.setup_for("alley", 1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.enemy_delay = 0.0
	s.animate = false
	add_child(s)
	s.battle.miss_chance = 0.0
	s.battle.crit_scale = 0.0
	return s


func until(s: BattleStage, unit: BattleUnit) -> void:
	var guard := 0
	while s.battle.current != unit and guard < 300:
		guard += 1
		if s.battle.current != null and s.battle.current.team == 0:
			s.end_turn()
		await get_tree().process_frame


func bring(s: BattleStage, e: BattleUnit, to: BattleUnit) -> void:
	var c := to.cell + to.facing
	var o = s.grid.occupant(c)
	if o != null and o != e:
		s.grid.remove(o)
	s.grid.move_occupant(e, c)
	e.cell = c


func battle_flow() -> void:
	var s := make_stage()
	var dm := s.battle.deployment
	var king := dm.king
	await until(s, king)
	eq(dm.props.size(), 5, "a world-map battle has five summon stones")
	var prizes := 0
	for c in dm.props:
		if StonePlacement.is_prize(dm.props[c].relic):
			prizes += 1
	eq(prizes, 1, "one of them is the prize stone")
	ok(s.prop_views.values().all(func(n): return n.has_meta("skill")), "every stone shows its skill")
	ok(s.prop_views.values().any(func(n): return bool(n.get_meta("fresh", false))), "and whether it is new to the party")
	# Bram onto a stone in reach that carries Quick Jab, almost learned
	var jab := SkillLibrary.find("Quick Jab")
	var spot := Vector2i(-1, -1)
	for c in dm.props:
		if dm.in_summon_range(c) and s.grid.can_stand(c):
			spot = c
	ok(spot != Vector2i(-1, -1), "a stone is in reach at the start")
	dm.props[spot].relic.skill = jab
	var bram: VesselData = s.game.roster.vessels()[0]
	var m := SkillMastery.make(jab)
	m.progress = 40
	Mentorship.tree_of(bram).masteries.append(m)
	s._on_summon_chosen(bram)
	s._summon_at(spot)
	var unit: BattleUnit = dm.vessels[0]
	await until(s, unit)
	# the skill menu
	var pal := s.hud.palette
	pal.open_list("abilities")
	ok(pal.detail.visible and pal.list_buttons.size() == pal.list_actions.size() and pal.list_buttons.size() >= 1, "ABILITIES lists the unit's skills beside a detail pane")
	var row_i := -1
	for i in pal.list_actions.size():
		if (pal.list_actions[i] as BattleAction).skill == jab:
			row_i = i
	ok(row_i >= 0, "the stone's skill is in the list")
	var bars: Array = pal.list_buttons[row_i].find_children("*", "ProgressBar", true, false)
	ok(bars.size() == 1 and is_equal_approx((bars[0] as ProgressBar).value, 0.4), "its row has a bar at the unit's progress (40%)")
	pal.show_detail(pal.list_actions[row_i])
	eq(pal.detail_name.text, "Quick Jab", "the detail pane names the skill")
	ok(pal.detail_text.text == jab.description and jab.description != "", "shows its description")
	ok(pal.detail_kind.text.contains("Physical") and pal.detail_kind.text.contains("Rank E"), "its proficiency and rank")
	ok(pal.detail_level.text == "Level 0" and pal.detail_points.text.begins_with("40 / 100"), "and the unit's level and bar")
	ok(is_equal_approx(pal.detail_bar.value, 0.4), "as a bar")
	for b in pal.list_buttons:
		ok(b.custom_minimum_size.y >= CommandPalette.SKILL_ROW, "every skill row is a full row")
	pal.list_buttons[row_i].mouse_entered.emit()
	eq(pal.detail_action.skill, jab, "pointing at a row shows it in the pane")
	s.cancel()
	# one use: the strip and the summary
	var foe: BattleUnit = s.battle.enemies[0]
	bring(s, foe, unit)
	foe.hp = foe.max_hp()
	var act: BattleAction = s.battle.actions(unit).filter(func(a): return a.skill == jab)[0]
	var r: ActionResult = await s._resolve(unit, act, foe.cell)
	ok(r.ok and r.skill_before == [0, 40] and (int(r.skill_after[0]) > 0 or int(r.skill_after[1]) > 40), "a use records the bar before and after (%s -> %s)" % [r.skill_before, r.skill_after])
	ok(s.hud.feed.last_progress.get("skill") == jab and s.hud.feed.strip.visible, "the progress strip shows it")
	ok(s.battle.summary.skill_progress.has(unit) and s.battle.summary.skill_progress[unit].has(jab), "the battle's summary keeps the training")
	# the use that masters it
	if not m.is_mastered():
		m.progress = 99
		s.battle.acted = false
		unit.sp = unit.max_sp()
		r = await s._resolve(unit, act, foe.cell)
	ok(m.is_mastered() and (r.skill_learned == jab or s.hud.feed.last_mastered.get("skill") == jab), "the skill reaches level 1")
	var card: Dictionary = s.hud.feed.last_mastered
	ok(card.get("skill") == jab and card.get("who") == bram.display_name and s.hud.feed.card.visible, "the SKILL MASTERED card shows")
	ok(String(card.get("note", "")).contains("Alaric") and String(card.get("note", "")).contains("study"), "and says Alaric can now study it (%s)" % card.get("note", ""))
	ok(s.game.campaign.skill_journal.any(func(e): return e.skill == "Quick Jab" and e.who == bram.display_name and e.source == "a summon stone"), "the journal records it and where it came from")
	var p: Array = s.battle.summary.skill_progress[unit][jab]
	ok(int(p[0]) == 0 and int(p[1]) == 40 and int(p[2]) >= 1, "the summary holds the first bar and the last (%s)" % [p])
	ok(Mentorship.offers(bram).any(func(o): return o.skill == jab), "and the vessel can teach it")
	# win: the results show the skill bars
	for e in s.battle.enemies:
		if e.is_down():
			continue
		bring(s, e, unit)
		e.hp = 1
		s.battle.acted = false
		await s._resolve(unit, BattleAction.attack(), e.cell)
	ok(s._check_end(), "the battle is won")
	var res: ResultScreen = s.hud.result
	var row: Dictionary = res._rows.filter(func(x): return x.unit == unit)[0]
	eq((row.skills as Array).size(), 1, "the vessel's row on the results has a bar for the skill it trained")
	var labels: Array = (row.holder as Control).find_children("*", "Label", true, false)
	ok(labels.any(func(l): return (l as Label).text.begins_with("LEARNED")), "marked LEARNED")
	ok(res.rewards_box.get_children().any(func(ch): return (ch.get_child(0) as Label).text.begins_with("Skills collected")), "and the rewards count the collection")
	s.queue_free()
	await get_tree().process_frame


## The battle menu's Favorites tab and the "being learned" pin (owner, Nov 2026): a starred skill gets a Favorites tab (first, and only while any is starred), and a
## skill that is being learned sits at the top of All (and of every tab it is in) until it reaches level 1.
func menu_order() -> void:
	var s := make_stage()
	var dm := s.battle.deployment
	await until(s, dm.king)
	var jab := SkillLibrary.find("Quick Jab")
	var spot := Vector2i(-1, -1)
	for c in dm.props:
		if dm.in_summon_range(c) and s.grid.can_stand(c):
			spot = c
	dm.props[spot].relic.skill = jab
	var bram: VesselData = s.game.roster.vessels()[0]
	var m := SkillMastery.make(jab)
	m.progress = 30
	Mentorship.tree_of(bram).masteries.append(m)
	s._on_summon_chosen(bram)
	s._summon_at(spot)
	var unit: BattleUnit = dm.vessels[0]
	await until(s, unit)
	var pal := s.hud.palette
	pal.tab = CommandPalette.TAB_ALL
	pal.open_list("abilities")
	ok(pal.list_actions.size() >= 2, "the vessel has several skills (%d)" % pal.list_actions.size())
	eq((pal.list_actions[0] as BattleAction).skill, jab, "the skill being learned is first on All")
	var headings := []
	for c in pal.columns.get_children():
		if c is Label:
			headings.append((c as Label).text)
	ok(headings.size() > 0 and headings[0] == "Learning", "under a Learning heading (%s)" % [headings])
	ok(not pal.tab_buttons.has(CommandPalette.TAB_FAVORITES), "no Favorites tab while nothing is starred")
	# star another skill
	var other: SkillData = null
	for a in pal.list_actions:
		if (a as BattleAction).skill != jab:
			other = (a as BattleAction).skill
	ok(other != null, "there is a second skill")
	pal.toggle_favorite(other)
	ok(pal.tab_buttons.has(CommandPalette.TAB_FAVORITES) and pal.tabs.get_child(0) == pal.tab_buttons[CommandPalette.TAB_FAVORITES], "the first star creates a Favorites tab, before All")
	ok(unit.data.favorite_skills.has(other.display_name), "the unit remembers it")
	eq(pal.tab, CommandPalette.TAB_ALL, "starring does not change the tab")
	eq((pal.list_actions[0] as BattleAction).skill, jab, "the skill being learned is still first on All")
	pal.tab_buttons[CommandPalette.TAB_FAVORITES].pressed.emit()
	eq(pal.list_actions.size(), 1, "the Favorites tab shows only starred skills")
	eq((pal.list_actions[0] as BattleAction).skill, other, "that one")
	pal.toggle_favorite(jab)
	eq(pal.list_actions.size(), 2, "both starred")
	eq((pal.list_actions[0] as BattleAction).skill, jab, "the one being learned comes first on Favorites too")
	var back := SaveCodec.decode(SaveCodec.encode(s.game))
	var bram2: VesselData = back.game.roster.vessels()[0]
	ok(back.ok and bram2.favorite_skills.has("Quick Jab") and bram2.favorite_skills.has(other.display_name), "favorites are saved and loaded")
	pal.toggle_favorite(jab)
	pal.toggle_favorite(other)
	eq(pal.tab, CommandPalette.TAB_ALL, "un-starring the last favorite takes the tab away and falls back to All")
	ok(not pal.tab_buttons.has(CommandPalette.TAB_FAVORITES), "no Favorites tab again")
	# learned: the pin ends
	m.level = 1
	m.progress = 0
	pal.open_list("abilities")
	headings.clear()
	for c in pal.columns.get_children():
		if c is Label:
			headings.append((c as Label).text)
	ok(not headings.has("Learning"), "once learned the skill is not pinned any more")
	s.queue_free()
	await get_tree().process_frame
