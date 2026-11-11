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
	teachers_rule()
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
	ok(n >= 5 and n <= 7, "C rank: 5-7 uses from level 0 to 1 while studying (x1.5; took %d)" % n)
	ok(m.level == 1 and t.is_learned(sk) and t.learned_skills() == [sk], "learned at level 1, kept for good")
	ok(t.active_study() == null and t.can_use(sk), "study slot freed, still usable")
	# levels 1 -> 99 by the same usage rule
	m.progress = 0
	n = uses_to_level(t, sk, st, rng)
	ok(n >= 8 and n <= 10, "C rank: 8-10 uses per level, about 9 (took %d)" % n)
	st.set_rank(Proficiency.Category.ELEMENTAL, TacticalMath.Rank.S)
	m.progress = 0
	n = uses_to_level(t, sk, st, rng)
	ok(n == 4, "S rank: 4 uses per level (took %d)" % n)
	eq(t.skill_level(sk), 3, "level 3")
	st.set_rank(Proficiency.Category.ELEMENTAL, TacticalMath.Rank.F)
	m.progress = 0
	n = uses_to_level(t, sk, st, rng)
	ok(n >= 13 and n <= 20, "F rank: 13-20 uses per level, about 16 (took %d)" % n)
	var before := m.progress
	t.use_skill(sk, st, 1, null, rng)
	ok(m.progress - before >= 5 and m.progress - before <= 8, "one F use gives 5-8 points")
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
	ok(kept >= 45 and kept <= 60, "3 study uses at C: 15-20 points each while studying (%d)" % kept)
	# the 1.5 rate is only while studying: a learned skill's uses count at 1.0
	var c := SkillData.new()
	t.start_study(c)
	var mc := t.mastery_of(c)
	t.use_skill(c, stats, 1)
	var first := mc.progress
	ok(first >= 15 and first <= 20, "one study use at C: 10-13 x 1.5 = 15-20 (%d)" % first)
	mc.level = 1
	mc.progress = 0
	t.use_skill(c, stats, 1)
	ok(mc.progress >= 10 and mc.progress <= 13, "once learned, a use at C gives 10-13 again (%d)" % mc.progress)
	t.start_study(a)
	t.start_study(b)
	eq(t.mastery_of(a).progress, kept, "switching keeps progress")
	ok(t.active_study().skill == b, "switched")
	ok(not t.can_use(a) and t.use_skill(a, stats) == 0, "a paused study cannot be used")
	t.start_study(a)
	eq(t.active_study().progress, kept, "resumed")
	eq(ResourceSaver.save(t, "user://tree_check.tres"), OK, "tree saves")
	var back: SkillTree = ResourceLoader.load("user://tree_check.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	ok(back.masteries.size() == 4 and back.active_study() != null and back.active_study().progress == kept, "tree loads")


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
	ok(dn >= 7 and dn <= 10, "Alaric is D in Elemental: 7-10 uses to level 1 while studying (x1.5; took %d)" % dn)
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
	b.roster = SampleParty.make()  # the sample party: a King and two Co-Captains
	add_child(b)
	await get_tree().process_frame
	eq(b.mentor_buttons.size(), 3, "a Mentorship button per human")
	ok(not b.mentorship.visible, "sub-menu starts closed")
	var shown := []
	for n in b.find_children("*", "Label", true, false):
		shown.append(n.text)
	ok(shown.any(func(t): return t.contains("Tethered 5×  ·  Severed 2×")), "vessel rows show tether and sever counts")
	b.mentor_buttons[1].pressed.emit()  # the Sorceress
	var mm := b.mentorship
	ok(mm.visible and not b.main.visible and mm.human == b.roster.co_captains[0], "opened for the Sorceress")
	# choose a skill -> see its teachers -> compare -> choose a teacher
	var taught := Mentorship.taught_skills(b.roster)
	ok(mm.skill_list.item_count >= 1 and mm.tab_buttons.has(-1), "every skill some vessel teaches is listed, with an All tab")
	eq(mm.tab_buttons[-1].text, "All  %d" % taught.size(), "the All tab counts them")
	var cats := {}
	for sk in taught:
		cats[sk.category] = true
	eq(mm.tab_buttons.size(), cats.size() + 1, "and there is one tab per proficiency that has skills")
	var some_cat: int = cats.keys()[0]
	mm.tab_buttons[some_cat].pressed.emit()
	ok(mm.tab == some_cat and mm._skills.all(func(sk): return sk.category == some_cat) and not mm._skills.is_empty(), "a proficiency tab shows only its skills")
	mm.tab_buttons[-1].pressed.emit()
	var mend := -1
	for i in mm._skills.size():
		if mm._skills[i].display_name == "Mend Light":
			mend = i
	ok(mend >= 0, "Mend Light is in the list")
	mm.skill_list.select(mend)
	mm.skill_list.item_selected.emit(mend)
	ok(mm.selected_skill().display_name == "Mend Light", "picked Mend Light")
	ok(mm.teacher_list.item_count >= 1 and mm.selected_vessel() != null, "its teachers are listed and one is chosen")
	ok(mm.compare_label.text.contains("Mentor Bond") and mm.compare_label.text.contains("study speed"), "with what each lesson is worth")
	ok(mm.skill_title.text.begins_with("Mend Light") and mm.skill_label.text.contains("Healing"), "and the skill's details")
	var lunar_i := -1
	for i in mm._teachers.size():
		if mm._teachers[i].vessel.display_name == "Lunar":
			lunar_i = i
	ok(lunar_i >= 0, "Lunar teaches it")
	mm.teacher_list.select(lunar_i)
	mm.teacher_list.item_selected.emit(lunar_i)
	ok(not mm.study_button.disabled and mm.study_button.text == "Study with Lunar", "the button names the chosen teacher (%s)" % mm.study_button.text)
	mm.study_button.pressed.emit()
	var tree: SkillTree = b.roster.co_captains[0].skill_tree
	ok(tree.active_study() != null and tree.active_study().skill.display_name == "Mend Light" and tree.active_study().mentor_name == "Lunar", "study started from the menu, with Lunar")
	ok(mm.study_button.disabled and mm.study_button.text == "Already Studying", "button reflects the state")
	ok(mm.study_label.text.begins_with("Studying Mend Light from Lunar"), "current study shown")
	ok(mm.teacher_list.get_item_text(mm.teacher_list.get_selected_items()[0]).contains("teaching you"), "the teacher row says so")
	mm.back_button.pressed.emit()
	await get_tree().process_frame
	ok(not mm.visible and b.main.visible, "back to the barracks")
	b.queue_free()


## The teacher comparison (owner, Nov 2026): every vessel that can teach a skill, what studying with each is worth, best first, and switching teacher.
func teachers_rule() -> void:
	var roster := SampleParty.make()
	var human: UnitData = roster.co_captains[0]
	var skill: SkillData = null
	for s in Mentorship.taught_skills(roster):
		if Mentorship.teachers(human, roster, s).size() >= 1:
			skill = s
	ok(skill != null, "some skill has a teacher")
	# a second teacher: another vessel masters the same skill, higher level
	var vessels := roster.vessels()
	var other: VesselData = null
	for v in vessels:
		if Mentorship.offers(v).all(func(o): return o.skill != skill):
			other = v
			break
	var m := SkillMastery.make(skill)
	m.level = 40
	Mentorship.tree_of(other).masteries.append(m)
	var list := Mentorship.teachers(human, roster, skill)
	ok(list.any(func(t): return t.vessel == other and t.relic == null and t.level == 40), "a vessel that has mastered the skill teaches it with no relic")
	var top := list[0]
	ok(top.vessel == other and is_equal_approx(top.teach_bonus, 0.04), "a level 40 master is the best teacher at +4% (%s %.2f)" % [top.vessel.display_name, top.teach_bonus])
	for i in range(1, list.size()):
		ok(list[i - 1].total >= list[i].total - 0.0001, "teachers are listed best first")
	eq(SkillTree.teach_bonus(5), 0.0, "under level 9 a teacher adds nothing")
	eq(SkillTree.teach_bonus(99), SkillTree.TEACH_CAP, "and the bonus stops at +10%")
	# studying with the master records its level, and the study fills faster than with a novice
	var tree := Mentorship.tree_of(human)
	var started := Mentorship.start_study(human, other, skill)
	ok(started != null and started.mentor_name == other.display_name and started.mentor_level == 40, "the study remembers the teacher and the teacher's level")
	ok(Mentorship.teachers(human, roster, skill).filter(func(t): return t.current).size() == 1, "and exactly one teacher is marked as teaching now")
	var novice: Mentorship.Teacher = null
	for t in Mentorship.teachers(human, roster, skill):
		if t.vessel != other:
			novice = t
	if novice != null:
		eq(Mentorship.study_error(human, novice.vessel, skill), "", "studying the same skill with another teacher is allowed")
		var sw := Mentorship.start_study(human, novice.vessel, skill)
		ok(sw != null and sw.mentor_name == novice.vessel.display_name and tree.active_study() == sw, "it switches teacher and keeps the study")
		eq(Mentorship.study_error(human, novice.vessel, skill), "already studying", "but not with the one it already has")
	var fast := SkillTree.new()
	var slow := SkillTree.new()
	fast.start_study(skill, "Master", 90)
	slow.start_study(skill, "Novice", 0)
	var stats := CharacterStats.new()
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 4
	r2.seed = 4
	fast.use_skill(skill, stats, 1, null, r1)
	slow.use_skill(skill, stats, 1, null, r2)
	ok(fast.mastery_of(skill).progress >= slow.mastery_of(skill).progress, "a master teaches at least as fast as a novice")
	var back := SaveCodec.decode(SaveCodec.encode(SaveGame.new_game()))
	ok(back.ok, "saves still round-trip")
