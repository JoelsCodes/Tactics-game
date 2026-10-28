class_name MentorshipMenu
extends Control
## Mentorship sub-menu for one human (King or Co-Captain): pick a vessel from the party roster, browse
## the skills its relics carry, and choose one to study. The rules live in Mentorship; this only shows
## them. Plain default controls until there is a menu art reference.

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


## Redraws everything from the current data, keeping the selected vessel and skill.
func refresh() -> void:
	if human == null:
		return
	title.text = "Mentorship  ·  %s" % human.display_name
	for c in prof_grid.get_children():
		c.queue_free()
	for cat in Proficiency.all():
		var l := Label.new()
		l.text = "%s  %d" % [Proficiency.display_name(cat), human.stats.proficiency_level(Proficiency.id(cat)) if human.stats else 0]
		prof_grid.add_child(l)
	var m := Mentorship.tree_of(human).active_study()
	if m == null:
		study_label.text = "Not studying anything"
		study_bar.value = 0
	else:
		var note := ""
		if m.is_studied():
			note = "  (needs %s %d)" % [Proficiency.display_name(m.skill.category), m.skill.required_level]
		study_label.text = "Studying %s from %s%s" % [m.skill.display_name, m.mentor_name, note]
		study_bar.value = m.progress
	var learned := Mentorship.tree_of(human).learned_skills()
	learned_label.text = "Learned: " + (", ".join(learned.map(func(s): return s.display_name)) if not learned.is_empty() else "none yet")
	var vi := _selected(vessel_list)
	var si := _selected(skill_list)
	_vessels = roster.vessels()
	vessel_list.clear()
	for v in _vessels:
		vessel_list.add_item("%s   (%d skills)" % [v.display_name, Mentorship.offers(v).size()])
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
		skill_list.add_item("%s   %s   %s" % [o.skill.display_name, Proficiency.short_name(o.skill.category), Mentorship.status_name(Mentorship.status(human, o.skill))])


func _show_detail() -> void:
	var s := selected_skill()
	if s == null:
		detail.text = "Pick a vessel and one of its skills."
		study_button.disabled = true
		study_button.text = "Study"
		return
	var o: Mentorship.Offer = _offers[_selected(skill_list)]
	var have: int = human.stats.proficiency_level(s.proficiency_id()) if human.stats else 0
	detail.text = "%s\n%s  ·  SP %d  ·  Power %d\nRelic: %s\nInherit at %s %d (you have %d)\n%s" % [
		s.display_name, Proficiency.display_name(s.category), s.sp_cost, s.base_power, o.relic.display_name,
		Proficiency.display_name(s.category), s.required_level, have, s.description]
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


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#10131c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	var head := HBoxContainer.new()
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(72, 44)
	back_button.pressed.connect(_on_back)
	head.add_child(back_button)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	head.add_child(title)
	col.add_child(head)

	col.add_child(_section("Proficiency levels"))
	prof_grid = GridContainer.new()
	prof_grid.columns = 2
	prof_grid.add_theme_constant_override("h_separation", 24)
	col.add_child(prof_grid)

	col.add_child(_section("Current study"))
	study_label = Label.new()
	study_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(study_label)
	study_bar = ProgressBar.new()
	study_bar.max_value = SkillMastery.STUDY_POINTS
	study_bar.custom_minimum_size.y = 18
	col.add_child(study_bar)

	col.add_child(_section("Vessels"))
	vessel_list = ItemList.new()
	vessel_list.custom_minimum_size.y = 120
	vessel_list.item_selected.connect(_on_vessel_selected)
	col.add_child(vessel_list)

	col.add_child(_section("Skills on its relics"))
	skill_list = ItemList.new()
	skill_list.custom_minimum_size.y = 100
	skill_list.item_selected.connect(func(_i): _show_detail())
	col.add_child(skill_list)

	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 96
	col.add_child(detail)
	study_button = Button.new()
	study_button.custom_minimum_size.y = 48
	study_button.pressed.connect(_on_study)
	col.add_child(study_button)

	learned_label = Label.new()
	learned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(learned_label)


static func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#9aa6c4"))
	return l
