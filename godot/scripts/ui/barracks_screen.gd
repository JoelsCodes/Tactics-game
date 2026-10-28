class_name BarracksScreen
extends Control
## Out-of-battle barracks: the party's Commanders (King, Co-Captains), the vessels and the spare
## relics. Each Commander has Mentorship and Loadout buttons; each vessel has an Active / Benched
## toggle (the squad brought to battle, up to 6) and a Loadout button, since a vessel's relics are the
## skills Commanders can study from it. Save and Load work on one slot; the game continues from the
## newest save when there is one. Plain default controls until there is a menu art reference.

const DEFAULT_SLOT := "slot1"

var game: SaveGame
var roster: PartyRoster
var slot := DEFAULT_SLOT
var main: Control
var mentorship: MentorshipMenu
var loadout_menu: LoadoutMenu
var status: Label
var save_button: Button
var load_button: Button
var mentor_buttons: Array[Button] = []  ## one per human, in roster.humans() order
var human_loadout_buttons: Array[Button] = []  ## one per human
var vessel_loadout_buttons: Array[Button] = []  ## one per vessel
var active_buttons: Array[Button] = []  ## one per vessel
var _list: VBoxContainer
var _first_status := ""


func _ready() -> void:
	if game == null:
		game = _start_game()
	roster = game.roster
	_build()
	status.text = _first_status
	refresh()


## Continues from the newest save, or starts a new game.
func _start_game() -> SaveGame:
	if roster != null:
		return SaveGame.new_game(roster)
	var newest := SaveSystem.newest_slot()
	if newest != "":
		var r := SaveSystem.load_slot(newest)
		if r.ok:
			_first_status = "Continued from %s" % newest
			return r.game
	return SaveGame.new_game()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	mentor_buttons.clear()
	human_loadout_buttons.clear()
	vessel_loadout_buttons.clear()
	active_buttons.clear()
	_list.add_child(MentorshipMenu._section("Commanders"))
	for h in roster.humans():
		_list.add_child(_human_row(h))
	_list.add_child(MentorshipMenu._section("Vessels  ·  %d / %d active" % [roster.active_vessels.size(), DeploymentManager.MAX_VESSELS]))
	for v in roster.vessels():
		_list.add_child(_vessel_row(v))
	_list.add_child(MentorshipMenu._section("Spare relics  ·  %d" % roster.relic_inventory.size()))
	if roster.relic_inventory.is_empty():
		_list.add_child(_label("None. Relics brought home from battle are kept here."))
	for r in roster.relic_inventory:
		var panel := PanelContainer.new()
		panel.add_child(_label(r.describe()))
		_list.add_child(panel)


func open_mentorship(human: UnitData) -> void:
	if not Mentorship.is_eligible(human):
		return
	main.hide()
	mentorship.open(human, roster)


func open_loadout(unit: UnitData) -> void:
	main.hide()
	loadout_menu.open(unit, roster)


func save_game() -> bool:
	var err := SaveSystem.save_slot(slot, game)
	say("Saved to %s" % slot if err == OK else "Save failed: %s" % error_string(err))
	return err == OK


func load_game() -> bool:
	var r := SaveSystem.load_slot(slot)
	if not r.ok:
		say("Load failed: %s" % r.error)
		return false
	game = r.game
	roster = game.roster
	refresh()
	var note := " (from the backup)" if r.from_backup else ""
	say("Loaded %s%s" % [slot, note] + ("  ·  %d warnings" % r.warnings.size() if not r.warnings.is_empty() else ""))
	return true


func say(text: String) -> void:
	status.text = text


func _on_sub_menu_closed() -> void:
	refresh()
	main.show()


func _toggle_active(v: VesselData) -> void:
	var on := not roster.active_vessels.has(v)
	var err := RosterManager.set_active(roster, v, on)
	say(err.capitalize() if err != "" else "%s %s" % [v.display_name, "joins the squad" if on else "is benched"])
	refresh()


func _human_row(h: UnitData) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var tree := Mentorship.tree_of(h)
	var study := tree.active_study()
	var info := _label("%s  ·  %s  ·  Lv %d\nHP %d  SP %d  ·  XP %s\n%d learned  ·  %s" % [
		h.display_name, h.role_name(), h.level, h.stats.max_hp(h.loadout), h.stats.max_sp(h.loadout), _xp_text(h), tree.learned_skills().size(),
		"Studying " + study.skill.display_name if study else "No study"])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	var m := _button("Mentorship", 120)
	m.pressed.connect(open_mentorship.bind(h))
	buttons.add_child(m)
	mentor_buttons.append(m)
	var e := _button("Loadout", 120)
	e.pressed.connect(open_loadout.bind(h))
	buttons.add_child(e)
	human_loadout_buttons.append(e)
	return panel


func _vessel_row(v: VesselData) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var relics := v.loadout.relics().map(func(r): return r.display_name) if v.loadout else []
	var info := _label("%s  ·  Vessel\nLv %d  ·  XP %s\nTethered %d×  ·  Severed %d×\nRelics: %s" % [v.display_name, v.level, _xp_text(v), v.tether_count, v.sever_count, ", ".join(relics) if not relics.is_empty() else "none"])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	var a := _button("Active" if roster.active_vessels.has(v) else "Benched", 100)
	a.pressed.connect(_toggle_active.bind(v))
	buttons.add_child(a)
	active_buttons.append(a)
	var e := _button("Loadout", 100)
	e.pressed.connect(open_loadout.bind(v))
	buttons.add_child(e)
	vessel_loadout_buttons.append(e)
	return panel


static func _xp_text(u: UnitData) -> String:
	return "%d / %d" % [u.exp, u.exp_to_next_level] if u.exp_to_next_level > 0 else "max"


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _button(text: String, width: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 44)
	return b


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
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Barracks"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	save_button = _button("Save", 72)
	save_button.pressed.connect(save_game)
	head.add_child(save_button)
	load_button = _button("Load", 72)
	load_button.pressed.connect(load_game)
	head.add_child(load_button)
	col.add_child(head)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("#9aa6c4"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
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
	mentorship.closed.connect(_on_sub_menu_closed)
	add_child(mentorship)
	loadout_menu = LoadoutMenu.new()
	loadout_menu.hide()
	loadout_menu.closed.connect(_on_sub_menu_closed)
	add_child(loadout_menu)
