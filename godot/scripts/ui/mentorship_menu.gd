class_name MentorshipMenu
extends Control
## Mentorship sub-menu for one human (King or Co-Captain): pick a vessel from the party roster, browse
## the skills its relics carry, and choose one to study. The rules live in Mentorship; this only shows
## them. Built on MenuKit's sub-screen shell (the Company Headquarters look); Esc / B goes back.

signal closed
signal study_started(human: UnitData, skill: SkillData)

var human: UnitData
var roster: PartyRoster
var _vessels: Array[VesselData] = []
var _offers: Array = []  ## Array[Mentorship.Offer] for the selected vessel

var title: Label
var prof_grid: GridContainer
var study_label: Label
var study_bar: ProgressBar
var vessel_list: ItemList
var skill_list: ItemList
var detail: Label
var study_button: Button
var learned_label: Label
var back_button: Button


func _ready() -> void:
	_build()


func open(unit: UnitData, party: PartyRoster) -> void:
	human = unit
	roster = party
	Mentorship.tree_of(human)
	refresh()
	if not _vessels.is_empty():
		vessel_list.select(0)
		_on_vessel_selected(0)
	show()
	MenuKit.set_plate(_plate, human)
	MenuKit.reveal(_body, 14.0)
	vessel_list.grab_focus.call_deferred()


## Redraws everything from the current data, keeping the selected vessel and skill.
func refresh() -> void:
	if human == null:
		return
	title.text = "Mentorship  ·  %s" % human.display_name
	for c in prof_grid.get_children():
		c.queue_free()
	for cat in Proficiency.all():  # each proficiency with its rank as a coloured letter
		var row := HBoxContainer.new()
		var n := MenuKit.label(Proficiency.display_name(cat), MenuKit.BODY - 1, MenuKit.PARCHMENT)
		n.custom_minimum_size.x = 130
		row.add_child(n)
		var r := human.stats.rank_of(cat) if human.stats else 0
		var letter := TacticalMath.rank_letter(r) if human.stats else "-"
		row.add_child(MenuKit.label(letter, MenuKit.HEADING - 2, MenuKit.rank_color(5 - mini(r, 5)) if human.stats else MenuKit.PARCHMENT_DIM, true, true))
		var l := Label.new()  # (kept for anything that reads the plain text)
		l.text = "%s  %s" % [Proficiency.display_name(cat), letter]
		l.visible = false
		row.add_child(l)
		prof_grid.add_child(row)
	var m := Mentorship.tree_of(human).active_study()
	if m == null:
		study_label.text = "Not studying anything"
		study_bar.value = 0
	else:
		study_label.text = "Studying %s from %s  ·  usable now, kept at Lv 1" % [m.skill.display_name, m.mentor_name]
		study_bar.value = m.progress
	var learned := Mentorship.tree_of(human).learned_skills()
	var tree := Mentorship.tree_of(human)
	learned_label.text = "Learned: " + (", ".join(learned.map(func(s): return "%s Lv %d" % [s.display_name, tree.skill_level(s)])) if not learned.is_empty() else "none yet")
	var vi := _selected(vessel_list)
	var si := _selected(skill_list)
	_vessels = roster.vessels()
	vessel_list.clear()
	for v in _vessels:
		var bond := Mentorship.tree_of(human).bond_level(v.display_name)
		vessel_list.add_item("%s   (%d skills)%s" % [v.display_name, Mentorship.offers(v).size(), "   Bond %d" % bond if bond > 0 else ""], UnitLook.portrait(UnitLook.sheet_for(v)))
	if vi >= 0 and vi < _vessels.size():
		vessel_list.select(vi)
		_fill_skills()
		if si >= 0 and si < _offers.size():
			skill_list.select(si)
	_show_detail()


func selected_vessel() -> VesselData:
	var i := _selected(vessel_list)
	return _vessels[i] if i >= 0 else null


func selected_skill() -> SkillData:
	var i := _selected(skill_list)
	return _offers[i].skill if i >= 0 and i < _offers.size() else null


func _on_vessel_selected(_i: int) -> void:
	_fill_skills()
	if not _offers.is_empty():
		skill_list.select(0)
	_show_detail()


func _fill_skills() -> void:
	skill_list.clear()
	_offers = Mentorship.offers(selected_vessel())
	for o in _offers:
		var st := Mentorship.status(human, o.skill)
		skill_list.add_item("%s   %s   %s%s" % [o.skill.display_name, Proficiency.short_name(o.skill.category), Mentorship.status_name(st), "" if o.relic != null else "   (mastered)"])
		var i := skill_list.item_count - 1
		skill_list.set_item_custom_fg_color(i, MenuKit.PARCHMENT_DIM if st == Mentorship.Status.LEARNED else (MenuKit.GOLD_BRIGHT if st == Mentorship.Status.STUDYING else MenuKit.rank_color(o.skill.rank)))
		skill_list.set_item_tooltip(i, "Rank %s  ·  %d SP" % [SkillData.Rank.keys()[o.skill.rank], o.skill.sp_cost])


func _show_detail() -> void:
	var s := selected_skill()
	if s == null:
		detail.text = "Pick a vessel and one of its skills."
		study_button.disabled = true
		study_button.text = "Study"
		return
	var o: Mentorship.Offer = _offers[_selected(skill_list)]
	var m := Mentorship.tree_of(human).mastery_of(s)
	var lv := "Lv %d (learned)" % m.level if m and m.is_mastered() else "Lv 0, %d / %d studied" % [m.progress if m else 0, TacticalMath.PROGRESS_PER_LEVEL]
	lv += "  ·  your %s rank %s" % [Proficiency.display_name(s.category), TacticalMath.rank_letter(human.stats.rank_of(s.category)) if human.stats else "-"]
	var v := selected_vessel()
	var tree := Mentorship.tree_of(human)
	var bar: Array = tree.bond_bar(v.display_name)
	var bond := "Mentor Bond with %s: Level %d%s  ·  study speed +%d%%" % [v.display_name, tree.bond_level(v.display_name), "  (%d / %d to the next)" % [bar[0], bar[1]] if int(bar[1]) > 0 else "  (max)", roundi(tree.bond_bonus(v.display_name) * 100.0)]
	detail.text = "%s\n%s  ·  Rank %s  ·  SP %d  ·  Power %d\n%s\nMastery: %s\n%s\n%s" % [
		s.display_name, Proficiency.display_name(s.category), SkillCollection.rank_letter(s), s.sp_cost, s.base_power,
		"Relic: %s" % o.relic.display_name if o.relic != null else "Mastered by %s: taught without a relic" % v.display_name, lv, bond, SkillCollection.describe(s)]
	var err := Mentorship.study_error(human, selected_vessel(), s)
	study_button.disabled = err != ""
	study_button.text = "Study this skill" if err == "" else err.capitalize()
	if Mentorship.status(human, s) == Mentorship.Status.PAUSED:
		study_button.text = "Resume study"


func _on_study() -> void:
	var s := selected_skill()
	if Mentorship.start_study(human, selected_vessel(), s) != null:
		study_started.emit(human, s)
		refresh()


func _on_back() -> void:
	hide()
	closed.emit()


static func _selected(list: ItemList) -> int:
	var sel := list.get_selected_items()
	return sel[0] if sel.size() > 0 else -1


var _plate: Control
var _body: Control


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var sh := MenuKit.screen(self, "Mentorship")
	back_button = sh.back
	back_button.pressed.connect(_on_back)
	title = sh.title
	_plate = sh.plate
	_body = sh.body
	(sh.subtitle as Label).text = "Study a skill a vessel carries: use it in battle until it is learned for good"
	MenuKit.set_hints(sh.footer, [["↑↓", "Choose"], ["←→", "Change column"], ["Enter", "Study"], ["Esc", "Back"]])
	var body: HBoxContainer = sh.body
	# three columns: the human (ranks, study, learned) | vessels and their skills | the chosen skill
	var left := _panel(body, 430)
	left.add_child(_section("Proficiency ranks"))
	prof_grid = GridContainer.new()
	prof_grid.columns = 2
	prof_grid.add_theme_constant_override("h_separation", 28)
	prof_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(prof_grid)
	left.add_child(_section("Current study"))
	study_label = MenuKit.body_text()
	left.add_child(study_label)
	study_bar = ProgressBar.new()
	study_bar.max_value = TacticalMath.PROGRESS_PER_LEVEL
	study_bar.custom_minimum_size.y = 14
	study_bar.show_percentage = false
	_style_bar(study_bar, MenuKit.XP)
	left.add_child(study_bar)
	left.add_child(_section("Learned"))
	learned_label = MenuKit.body_text()
	learned_label.add_theme_color_override("font_color", MenuKit.PARCHMENT_DIM)
	left.add_child(learned_label)

	var mid := _panel(body, 0)
	mid.add_child(_section("Vessels"))
	vessel_list = ItemList.new()
	vessel_list.custom_minimum_size.y = 250
	vessel_list.fixed_icon_size = Vector2i(40, 40)
	MenuKit.style_list(vessel_list)
	vessel_list.item_selected.connect(_on_vessel_selected)
	mid.add_child(vessel_list)
	mid.add_child(_section("Skills on its relics"))
	skill_list = ItemList.new()
	skill_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_list.custom_minimum_size.y = 220
	MenuKit.style_list(skill_list)
	skill_list.item_selected.connect(func(_i): _show_detail())
	mid.add_child(skill_list)

	var right := _panel(body, 500)
	right.add_child(_section("Skill"))
	detail = MenuKit.body_text()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
	study_button = MenuKit.action_button("Study")
	study_button.pressed.connect(_on_study)
	right.add_child(study_button)
	vessel_list.focus_neighbor_right = skill_list.get_path()
	skill_list.focus_neighbor_left = vessel_list.get_path()
	skill_list.focus_neighbor_right = study_button.get_path()


## A bar in the kit's look.
static func _style_bar(b: ProgressBar, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(MenuKit.GOLD_DIM, 0.5)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)


## A framed column in `parent` (fixed `width`, or 0 to share the free space) holding a VBox. (Also used by LoadoutMenu.)
static func _panel(parent: Control, width: int) -> VBoxContainer:
	var col := MenuKit.column(parent, "", width)
	col.add_theme_constant_override("separation", 12)
	return col


static func _section(text: String) -> Control:
	return MenuKit.heading(text)
