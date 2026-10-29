class_name BarracksScreen
extends Control
## Out-of-battle barracks, laid out for a 16:9 screen in three columns: the party's Commanders (King,
## Co-Captains), the vessels and the spare relics. Each Commander has Mentorship and Loadout buttons.
## The King goes on every mission; the Co-Captain rows have a button to choose who goes with him. Vessels
## are not picked here: in battle the King can summon any vessel he owns. Each vessel has a Loadout
## button, since a vessel's relics are the skills Commanders can study from it. Save and Load work on
## one slot; the game continues from the newest save when there is one. The Battle button starts the
## mission map straight away (there is no pre-battle screen). Plain default controls until there is a
## menu art reference.

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
var battle_button: Button
var mentor_buttons: Array[Button] = []  ## one per human, in roster.humans() order
var human_loadout_buttons: Array[Button] = []  ## one per human
var vessel_loadout_buttons: Array[Button] = []  ## one per vessel
var captain_buttons: Array[Button] = []  ## one per Co-Captain: makes them the active Co-Captain
var _humans_list: VBoxContainer
var _vessels_list: VBoxContainer
var _relics_list: VBoxContainer
var _vessels_title: Label
var _relics_title: Label
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
	for l in [_humans_list, _vessels_list, _relics_list]:
		for c in l.get_children():
			c.queue_free()
	mentor_buttons.clear()
	human_loadout_buttons.clear()
	vessel_loadout_buttons.clear()
	captain_buttons.clear()
	for h in roster.humans():
		_humans_list.add_child(_human_row(h))
	_vessels_title.text = "VESSELS  ·  %d OWNED  ·  THE KING SUMMONS ANY, UP TO %d A BATTLE" % [roster.vessels().size(), DeploymentManager.DEFAULT_SUMMON_LIMIT]
	for v in roster.vessels():
		_vessels_list.add_child(_vessel_row(v))
	_relics_title.text = "SPARE RELICS  ·  %d" % roster.relic_inventory.size()
	if roster.relic_inventory.is_empty():
		_relics_list.add_child(_label("None. Relics brought home from battle are kept here."))
	for r in roster.relic_inventory:
		var panel := PanelContainer.new()
		panel.add_child(_label(r.describe()))
		_relics_list.add_child(panel)


func open_mentorship(human: UnitData) -> void:
	if not Mentorship.is_eligible(human):
		return
	main.hide()
	mentorship.open(human, roster)


func open_loadout(unit: UnitData) -> void:
	main.hide()
	loadout_menu.open(unit, roster)


## Opens the test battle (SampleBattle on the demo battlefield) with this party.
func start_battle() -> void:
	BattleStage.pending_game = game
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


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


func _choose_captain(c: CoCaptainData) -> void:
	var err := RosterManager.set_active_co_captain(roster, c)
	say(err.capitalize() if err != "" else "%s goes with the King on missions" % c.display_name)
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
	var m := _button("Mentorship", 180)
	m.pressed.connect(open_mentorship.bind(h))
	buttons.add_child(m)
	mentor_buttons.append(m)
	var e := _button("Loadout", 180)
	e.pressed.connect(open_loadout.bind(h))
	buttons.add_child(e)
	human_loadout_buttons.append(e)
	if h is CoCaptainData:
		var on := roster.deployed_co_captain() == h
		var c := _button("On missions" if on else "Send on missions", 180)
		c.disabled = on
		c.pressed.connect(_choose_captain.bind(h as CoCaptainData))
		buttons.add_child(c)
		captain_buttons.append(c)
	else:
		var k := _label("Goes on every mission")
		k.theme_type_variation = &"SmallLabel"
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		buttons.add_child(k)
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
	var e := _button("Loadout", 160)
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
	b.custom_minimum_size = Vector2(width, 52)
	return b


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = HudStyle.theme()
	add_child(HudStyle.backdrop())
	main = MarginContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		main.add_theme_constant_override("margin_" + side, 48)
	add_child(main)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	main.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "Barracks"
	title.theme_type_variation = &"HeadingLabel"
	head.add_child(title)
	status = Label.new()
	status.theme_type_variation = &"SmallLabel"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.clip_text = true
	head.add_child(status)
	save_button = _button("Save", 140)
	save_button.pressed.connect(save_game)
	head.add_child(save_button)
	load_button = _button("Load", 140)
	load_button.pressed.connect(load_game)
	head.add_child(load_button)
	battle_button = _button("Battle", 180)
	battle_button.pressed.connect(start_battle)
	head.add_child(battle_button)
	page.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 32)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var c1 := _column(body, "Commanders")
	_humans_list = c1[1]
	var c2 := _column(body, "Vessels")
	_vessels_title = c2[0]
	_vessels_list = c2[1]
	var c3 := _column(body, "Spare relics")
	_relics_title = c3[0]
	_relics_list = c3[1]
	mentorship = MentorshipMenu.new()
	mentorship.hide()
	mentorship.closed.connect(_on_sub_menu_closed)
	add_child(mentorship)
	loadout_menu = LoadoutMenu.new()
	loadout_menu.hide()
	loadout_menu.closed.connect(_on_sub_menu_closed)
	add_child(loadout_menu)


## A column: a heading and a scrolling list. Returns [heading, list].
func _column(parent: Control, heading: String) -> Array:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	parent.add_child(col)
	var t := HudStyle.section(heading)
	col.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	return [t, list]
