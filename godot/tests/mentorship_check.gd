extends Node
## Headless checks for proficiencies, skill mastery, mentorship and the barracks menus:
## godot --headless --path godot res://tests/mentorship_check.tscn

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
	SaveSystem.dir = "user://test_saves_mentorship"  # an empty folder: the barracks starts a new game
	taxonomy()
	loadout_slots()
	mastery()
	mentorship_rules()
	await ui()
	print("mentorship checks: %d run, %d failed" % [count, fails])
	get_tree().quit(1 if fails else 0)


func taxonomy() -> void:
	eq(Proficiency.all().size(), 6, "six proficiencies")
	eq(Proficiency.all().map(func(c): return Proficiency.display_name(c)), ["Physical", "Elemental", "Healing", "Tactical", "Status", "Void"], "names")
	eq(Proficiency.id(Proficiency.Category.VOID), &"void", "ids")
	var s := SkillData.new()
	ok(s.is_physical() and s.proficiency_id() == &"physical", "skills default to Physical")
	s.category = Proficiency.Category.HEALING
	ok(not s.is_physical(), "healing is not physical")


func loadout_slots() -> void:
	eq(EquipmentLoadout.SLOT_COUNT, 5, "five slots")
	eq(EquipmentLoadout.SLOT_NAMES, ["Main Weapon", "Weapon Style", "Relic Slot 1", "Relic Slot 2", "Temp-Relic"], "slot names")


func mastery() -> void:
	var stats := CharacterStats.new()
	var sk := SkillData.new()
	sk.category = Proficiency.Category.ELEMENTAL
	var t := SkillTree.new()
	var m := t.start_study(sk, "Choir")
	ok(m != null and t.active_study() == m and m.level == 0, "starting a study: level 0")
	ok(t.can_use(sk) and t.usable_skills() == [sk], "usable the moment the study starts")
	ok(not t.is_learned(sk) and t.learned_skills().is_empty(), "not kept at level 0")
	var st := CharacterStats.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := uses_to_level(t, sk, st, rng)
	ok(n >= 10 and n <= 15, "C rank: 10-15 uses from level 0 to 1 (took %d)" % n)
	ok(m.level == 1 and t.is_learned(sk) and t.learned_skills() == [sk], "learned at level 1, kept for good")
	ok(t.active_study() == null and t.can_use(sk), "study slot freed, still usable")
	# levels 1 -> 99 by the same usage rule
	m.progress = 0
	n = uses_to_level(t, sk, st, rng)
	ok(n >= 10 and n <= 15, "C rank: 10-15 uses per level (took %d)" % n)
	st.set_rank(Proficiency.Category.ELEMENTAL, TacticalMath.Rank.S)
	m.progress = 0
	n = uses_to_level(t, sk, st, rng)
	ok(n >= 5 and n <= 6, "S rank: 5-6 uses per level (took %d)" % n)
	eq(t.skill_level(sk), 3, "level 3")
	st.set_rank(Proficiency.Category.ELEMENTAL, TacticalMath.Rank.F)
	m.progress = 0
	n = uses_to_level(t, sk, st, rng)
	ok(n >= 25 and n <= 100, "F rank: 25-100 uses per level (took %d)" % n)
	var before := m.progress
	t.use_skill(sk, st, 1, null, rng)
	ok(m.progress - before >= 1 and m.progress - before <= 4, "one F use gives 1-4 points")
	t.use_skill(sk, st, 50000, null, rng)
	eq(t.skill_level(sk), 99, "skills cap at 99")
	sk.base_power = 10
	eq(t.mastery_of(sk).power(), 30, "power scales with skill level")
	var unlearned := SkillData.new()
	ok(not t.can_use(unlearned), "never studied: not usable")
	eq(t.use_skill(unlearned, st), 0, "never studied: no levels")
	ok(t.active_study() == null, "study slot freed")
	eq(t.start_study(sk), null, "cannot study a learned skill again")
	var a := SkillData.new()
	var b := SkillData.new()
	t.start_study(a)
	t.use_skill(a, stats, 3)
	var kept := t.mastery_of(a).progress
	ok(kept >= 21 and kept <= 30, "3 uses at C: 21-30 points")
	t.start_study(b)
	eq(t.mastery_of(a).progress, kept, "switching keeps progress")
	ok(t.active_study().skill == b, "switched")
	ok(not t.can_use(a) and t.use_skill(a, stats) == 0, "a paused study cannot be used")
	t.start_study(a)
	eq(t.active_study().progress, kept, "resumed")
	eq(ResourceSaver.save(t, "user://tree_check.tres"), OK, "tree saves")
	var back: SkillTree = ResourceLoader.load("user://tree_check.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ok(back.masteries.size() == 3 and back.active_study() != null and back.active_study().progress == kept, "tree loads")


## Uses `skill` one at a time until it gains a level; returns how many uses it took.
func uses_to_level(t: SkillTree, skill: SkillData, st: CharacterStats, rng: RandomNumberGenerator) -> int:
	var n := 0
	while n < 1000:
		n += 1
		if t.use_skill(skill, st, 1, null, rng) > 0:
			break
	return n


func mentorship_rules() -> void:
	var p := SampleParty.make()
	eq(p.humans().size(), 3, "King and two Co-Captains")
	ok(p.humans()[0] == p.king, "King first")
	eq(p.vessels().size(), 8, "eight vessels (five placeholders)")
	var king := p.king
	var choir := p.vessels()[1]
	var offers := Mentorship.offers(choir)
	eq(offers.size(), 2, "two relic skills")
	var hymn: SkillData = offers[0].skill
	eq(Mentorship.study_error(choir, choir, hymn), "only the King and Co-Captains can study", "vessels cannot study")
	eq(Mentorship.study_error(king, p.vessels()[0], hymn), "this vessel does not carry that skill", "skill must come from that vessel")
	eq(Mentorship.status(king, hymn), Mentorship.Status.AVAILABLE, "available")
	ok(Mentorship.start_study(king, choir, hymn) != null, "start study")
	eq(Mentorship.status(king, hymn), Mentorship.Status.STUDYING, "studying")
	eq(Mentorship.study_error(king, choir, hymn), "already studying", "no double start")
	ok(king.skill_tree.can_use(hymn), "usable while studying")
	var dn := uses_to_level(king.skill_tree, hymn, king.stats, null)
	ok(dn >= 15 and dn <= 25, "Aldric is D in Elemental: 15-25 uses to level 1 (took %d)" % dn)
	eq(king.skill_tree.skill_level(hymn), 1, "level 1")
	eq(Mentorship.status(king, hymn), Mentorship.Status.LEARNED, "learned")
	eq(Mentorship.study_error(king, choir, hymn), "already learned", "cannot study again")
	var mira: UnitData = p.co_captains[0]
	ok(Mentorship.start_study(mira, choir, hymn) != null, "another human can study the same skill")
	var p2 := PartyRoster.new()
	var r := RelicItem.new()
	p2.receive_relics([r, r] as Array[RelicItem])
	eq(p2.relic_inventory.size(), 1, "inventory receives relics once")


func ui() -> void:
	var b: BarracksScreen = load("res://scenes/barracks.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	eq(b.mentor_buttons.size(), 3, "a Mentorship button per human")
	ok(not b.mentorship.visible, "sub-menu starts closed")
	var shown := []
	for n in b.find_children("*", "Label", true, false):
		shown.append(n.text)
	ok(shown.any(func(t): return t.contains("Tethered 5×  ·  Severed 2×")), "vessel rows show tether and sever counts")
	b.mentor_buttons[1].pressed.emit()  # Lyra
	var mm := b.mentorship
	ok(mm.visible and not b.main.visible and mm.human == b.roster.co_captains[0], "opened for Lyra")
	eq(mm.vessel_list.item_count, 8, "every vessel listed")
	ok(mm.selected_vessel() == b.roster.vessels()[0], "first vessel selected")
	eq(mm.skill_list.item_count, 2, "its relic skills listed")
	mm.vessel_list.select(2)
	mm.vessel_list.item_selected.emit(2)
	ok(mm.selected_skill().display_name == "Mend Light", "picked Lantern Wraith's first skill")
	ok(not mm.study_button.disabled, "study enabled")
	mm.study_button.pressed.emit()
	var tree: SkillTree = b.roster.co_captains[0].skill_tree
	ok(tree.active_study() != null and tree.active_study().skill.display_name == "Mend Light", "study started from the menu")
	ok(mm.study_button.disabled and mm.study_button.text == "Already Studying", "button reflects the state")
	ok(mm.study_label.text.begins_with("Studying Mend Light from Lantern Wraith"), "current study shown")
	mm.back_button.pressed.emit()
	await get_tree().process_frame
	ok(not mm.visible and b.main.visible, "back to the barracks")
	b.queue_free()
