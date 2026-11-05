extends Node
## Headless: every unit has the same skills menu (Alaric, a Co-Captain, a vessel); only the humans have a Mentor button. And a lost battle gives back what it earned.
## godot --headless --path godot res://tests/skills_menu_check.tscn
var fails := 0
var count := 0


func ok(cond: bool, what: String) -> void:
	count += 1
	if not cond:
		fails += 1
		printerr("FAIL ", what)


func eq(a, b, what: String) -> void:
	ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ready() -> void:
	SaveSystem.dir = "user://test_saves_skills_menu"
	var g := Crucible.unlock_party(Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game())))
	var menu := SkillsMenu.new()
	add_child(menu)
	await get_tree().process_frame
	var king := g.roster.king
	var lyra: CoCaptainData = g.roster.co_captains[0]
	var bram: VesselData = g.roster.king.vessel_roster.filter(func(v): return v.display_name == "Bram")[0]
	var jab := SkillLibrary.find("Pin Down")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# Bram has learned one skill and is part way through another
	var t := Mentorship.tree_of(bram)
	for i in 60:
		t.practice_skill(jab, bram.stats, bram.loadout, rng)
	t.practice_skill(SkillLibrary.find("Bonk"), bram.stats, bram.loadout, rng)
	for u in [king, lyra, bram]:
		menu.open(u)
		ok(menu.visible and menu.title.text.contains(u.display_name), "the menu opens for %s" % u.display_name)
		ok(menu.list.item_count >= 1, "%s: the list is filled (%d lines)" % [u.display_name, menu.list.item_count])
		eq(menu.mentor_button.visible, u.is_human(), "%s: the Mentor button is there for Alaric and the Co-Captains only" % u.display_name)
	var bram_lines := SkillsMenu.entries_of(bram)
	ok(bram_lines.any(func(e): return e.skill.display_name == "Pin Down" and e.level >= 1 and e.group == 0), "Bram: the learned skill is listed with its level")
	ok(bram_lines.any(func(e): return e.skill.display_name == "Bonk" and e.level == 0 and e.progress > 0 and e.group == 1), "Bram: the skill in progress is listed with its bar")
	ok(bram_lines.any(func(e): return e.group == 2), "Bram: the skills his relics carry are listed")
	var lyra_lines := SkillsMenu.entries_of(lyra)
	ok(lyra_lines.filter(func(e): return e.group == 3).size() == 3, "Lyra the Co-Captain: her three signature skills")
	# the detail panel
	menu.open(bram)
	var first := -1
	for i in menu.list.item_count:
		if menu.list.get_item_metadata(i) != null:
			first = i
			break
	menu.list.select(first)
	menu.list.item_selected.emit(first)
	ok(menu.detail.text.contains("rank") and menu.bar.visible, "picking a skill shows its details and its bar")
	var requested := []
	menu.mentor_requested.connect(func(h): requested.append(h))
	menu.open(king)
	menu.mentor_button.pressed.emit()
	eq(requested, [king], "Mentor opens the mentorship window for the human")
	# the barracks gets a Skills button on every row
	var screen := BarracksScreen.new()
	screen.game = g
	add_child(screen)
	await get_tree().process_frame
	eq(screen.skills_buttons.size(), g.roster.humans().size() + g.roster.vessels().size(), "the barracks has a Skills button for every human and every vessel")
	screen.open_skills(bram)
	ok(screen.skills_menu.visible and not screen.main.visible, "it opens the unit's skills")
	screen.queue_free()
	await lost_battle_gives_back()
	print("skills menu checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


## A lost battle takes back what it earned: skill progress made in it is gone, whether the player retries or leaves.
func lost_battle_gives_back() -> void:
	var g := Riverford.add_merc(FirstBattle.chamber_game(FirstBattle.game()))
	BattleStage.pending_game = g
	BattleStage.pending_setup = Riverford.setup(1)
	var s: BattleStage = load("res://scenes/battle.tscn").instantiate()
	s.animate = false
	s.enemy_delay = 1000.0
	add_child(s)
	await get_tree().process_frame
	var bram: VesselData = s.game.roster.king.vessel_roster.filter(func(v): return v.display_name == "Bram")[0]
	var tr := Mentorship.tree_of(bram)
	var rng := RandomNumberGenerator.new()
	for i in 5:
		tr.practice_skill(SkillLibrary.find("Bonk"), bram.stats, bram.loadout, rng)
	ok(tr.mastery_of(SkillLibrary.find("Bonk")).progress > 0, "progress was made in the battle")
	var before_game := s.game
	for u in s.battle.deployment.field_units():
		u.hp = 0  # the party falls
	s.battle._check_outcome()
	s._check_end()
	eq(s.battle.outcome, BattleController.Outcome.LOST, "the battle is lost")
	ok(s.game != before_game, "the game is replaced by what it was before the battle")
	var bram2: VesselData = s.game.roster.king.vessel_roster.filter(func(v): return v.display_name == "Bram")[0]
	var m: SkillMastery = null
	if bram2.skill_tree != null:
		for mm in bram2.skill_tree.masteries:
			if mm.skill.display_name == "Bonk":
				m = mm
	ok(m == null, "the progress made in the lost battle is gone")
	ok(SaveSystem.load_slot(SaveSystem.AUTOSAVE).ok, "and the autosave holds the restored game")
	s.queue_free()
	await get_tree().process_frame
