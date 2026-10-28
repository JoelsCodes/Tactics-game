class_name BarracksScreen
extends Control
## Out-of-battle barracks: the party's humans (King, Co-Captains) and vessels. Each human has a
## Mentorship button that opens the MentorshipMenu sub-menu for them; vessels have no such button.
## Uses SampleParty until there is a save system. Plain default controls until there is a menu art
## reference.

var roster: PartyRoster
var mentorship: MentorshipMenu
var main: Control
var _list: VBoxContainer
var mentor_buttons: Array[Button] = []  ## one per human, in roster.humans() order


func _ready() -> void:
	if roster == null:
		roster = SampleParty.make()
	_build()
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	mentor_buttons.clear()
	_list.add_child(MentorshipMenu._section("Commanders"))
	for h in roster.humans():
		_list.add_child(_human_row(h))
	_list.add_child(MentorshipMenu._section("Vessels"))
	for v in roster.vessels():
		_list.add_child(_vessel_row(v))


func open_mentorship(human: UnitData) -> void:
	if not Mentorship.is_eligible(human):
		return
	main.hide()
	mentorship.open(human, roster)


func _on_mentorship_closed() -> void:
	refresh()
	main.show()


func _human_row(h: UnitData) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tree := Mentorship.tree_of(h)
	var study := tree.active_study()
	info.text = "%s  ·  %s\nHP %d  SP %d  ·  %d learned\n%s" % [
		h.display_name, h.role_name(), h.stats.max_hp(h.loadout), h.stats.max_sp(h.loadout), tree.learned_skills().size(),
		"Studying " + study.skill.display_name if study else "No study"]
	row.add_child(info)
	var b := Button.new()
	b.text = "Mentorship"
	b.custom_minimum_size = Vector2(120, 48)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(open_mentorship.bind(h))
	row.add_child(b)
	mentor_buttons.append(b)
	return panel


func _vessel_row(v: VesselData) -> Control:
	var panel := PanelContainer.new()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var relics := v.loadout.relics().map(func(r): return r.display_name) if v.loadout else []
	info.text = "%s  ·  Vessel\nTethered %d×  ·  Severed %d×\nRelics: %s" % [v.display_name, v.tether_count, v.sever_count, ", ".join(relics) if not relics.is_empty() else "none"]
	panel.add_child(info)
	return panel


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#10131c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	main = MarginContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		main.add_theme_constant_override("margin_" + side, 16)
	add_child(main)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	main.add_child(col)
	var title := Label.new()
	title.text = "Barracks"
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	mentorship = MentorshipMenu.new()
	mentorship.hide()
	mentorship.closed.connect(_on_mentorship_closed)
	add_child(mentorship)
