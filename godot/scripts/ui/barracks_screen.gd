class_name BarracksScreen
extends Control
## The Company Headquarters (the out-of-battle barracks), the visual reference for every menu (MenuKit). Left: the sections (Company,
## Formation, Skills, Equipment, Campaign, Records, System). Centre: the page; Company shows every member as a card (portrait, name,
## class and style, level, HP/SP and XP progress) and a selected card is the one Skills and Equipment open. Right: the next mission, the
## chapter and the company's real numbers. Bottom: context hints. Formation is the roster with the Mentorship, Skills and Loadout buttons
## of every member and the Co-Captain choice; Campaign starts the battle or returns to the base; System saves and loads (one slot; the
## game continues from the newest save when there is one). The King goes on every mission; Co-Captain wording appears only once one is
## unlocked; vessels are not picked here (the King summons any he owns in battle). No company rank or treasury: the save has none.
## Mouse, keyboard and controller: focus moves with the arrows / d-pad, Q and E (or the shoulder buttons) change section, Esc / B goes back.

const DEFAULT_SLOT := "slot1"

var game: SaveGame
var roster: PartyRoster
var slot := DEFAULT_SLOT
var main: Control
var mentorship: MentorshipMenu
var loadout_menu: LoadoutMenu
var skills_menu: SkillsMenu  ## the skills of any unit: the same menu for Alaric, the Co-Captains and the vessels (humans also have a Mentor button in it)
var skills_buttons: Array[Button] = []  ## one per human, then one per vessel
var status: Label
var save_button: Button
var load_button: Button
var battle_button: Button
var base_button: Button  ## back to the base
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
## the new layout
const SECTIONS := ["Company", "Formation", "Skills", "Equipment", "Campaign", "Records", "System"]
var nav_buttons: Array[Button] = []
var card_buttons: Array[Button] = []  ## one per member on the Company page, in _members() order
var selected_unit: UnitData  ## the member Skills and Equipment open (the King until another card is chosen)
var section := "Company"
var _pages := {}  ## section -> Control
var _cards: GridContainer
var _side: VBoxContainer
var _footer: HBoxContainer
var _records: VBoxContainer
var _records_b: VBoxContainer
var _records_units: GridContainer
var _journal_box: VBoxContainer  ## Records: the Skill Journal (newest first) and the Mentor Bonds
var _world_box: VBoxContainer
var _system_box: VBoxContainer
var _mission_box: VBoxContainer
var _subtitle: Label


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
	if GameSession.game != null:
		return GameSession.game
	var newest := SaveSystem.newest_slot()
	if newest != "":
		var r := SaveSystem.load_slot(newest)
		if r.ok:
			_first_status = "Continued from %s" % newest
			return r.game
	return GameSession.current()  # no save: the story's party (Alaric and his vessels, no Co-Captain until one is unlocked)


func refresh() -> void:
	for l in [_humans_list, _vessels_list, _relics_list]:
		for c in l.get_children():
			c.queue_free()
	mentor_buttons.clear()
	human_loadout_buttons.clear()
	vessel_loadout_buttons.clear()
	captain_buttons.clear()
	skills_buttons.clear()
	if selected_unit == null or not roster.all_units().has(selected_unit):
		selected_unit = roster.king
	_fill_cards()
	_fill_side()
	_fill_records()
	_fill_mission()
	for h in roster.humans():
		_humans_list.add_child(_human_row(h))
	_vessels_title.text = "VESSELS  ·  %d OWNED  ·  UP TO %d SUMMONS A BATTLE" % [roster.vessels().size(), DeploymentManager.DEFAULT_SUMMON_LIMIT]
	for v in roster.vessels():
		_vessels_list.add_child(_vessel_row(v))
	_relics_title.text = "SPARE RELICS  ·  %d" % roster.relic_inventory.size()
	if roster.relic_inventory.is_empty():
		_relics_list.add_child(_label("None. Relics brought home from battle are kept here."))
	for r in roster.relic_inventory:
		var f := MenuKit.frame(true, 12)
		f[1].add_child(_label(r.describe()))
		_relics_list.add_child(f[0])


func open_mentorship(human: UnitData) -> void:
	if not Mentorship.is_eligible(human):
		return
	main.hide()
	mentorship.open(human, roster)


func open_skills(unit: UnitData) -> void:
	main.hide()
	skills_menu.open(unit)


func _on_mentor_from_skills(human: UnitData) -> void:
	skills_menu.hide()
	open_mentorship(human)


func open_loadout(unit: UnitData) -> void:
	main.hide()
	loadout_menu.open(unit, roster)


## Opens the test battle (SampleBattle on the demo battlefield) with this party.
func go_to_base() -> void:
	GameSession.game = game
	get_tree().change_scene_to_file("res://scenes/base_area.tscn")


func start_battle() -> void:
	GameSession.game = game
	BattleStage.pending_game = game
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func save_game() -> bool:
	var err := SaveSystem.save_slot(slot, game)
	say("Saved to %s" % slot if err == OK else "Save failed: %s" % error_string(err))
	if _system_box != null:
		_fill_system()
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


func _stand_down(c: CoCaptainData) -> void:
	roster.stand_down = true
	say("%s stands down: she can be summoned as a vessel" % c.display_name)
	refresh()


func _choose_captain(c: CoCaptainData) -> void:
	var err := RosterManager.set_active_co_captain(roster, c)
	say(err.capitalize() if err != "" else "%s joins the active party" % c.display_name)
	refresh()


func _human_row(h: UnitData) -> Control:
	var f := MenuKit.frame(true, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	f[1].add_child(row)
	row.add_child(_portrait(h, 72))
	var tree := Mentorship.tree_of(h)
	var study := tree.active_study()
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(MenuKit.label(h.display_name, MenuKit.BODY + 2, MenuKit.GOLD_BRIGHT, true, true))
	info.add_child(_label("%s  ·  Lv %d\nHP %d  ·  SP %d\nXP %s\n%d learned  ·  %s" % [
		h.role_name(), h.level, h.stats.max_hp(h.loadout), h.stats.max_sp(h.loadout), _xp_text(h), tree.learned_skills().size(),
		"Studying " + study.skill.display_name if study else "No study"]))
	row.add_child(info)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	var m := _button("Mentorship", 170)
	m.pressed.connect(open_mentorship.bind(h))
	buttons.add_child(m)
	mentor_buttons.append(m)
	var sk := _button("Skills", 170)
	sk.pressed.connect(open_skills.bind(h))
	buttons.add_child(sk)
	skills_buttons.append(sk)
	var e := _button("Loadout", 170)
	e.pressed.connect(open_loadout.bind(h))
	buttons.add_child(e)
	human_loadout_buttons.append(e)
	if h is CoCaptainData:
		var on := roster.deployed_co_captain() == h
		var vessel_twin := roster.vessels().any(func(v): return v.id == h.id)  # a Co-Captain who is also a vessel slot: one or the other
		var c := _button(("Stand down (summon as a vessel)" if vessel_twin else "In active party") if on else "Join active party", 170)
		c.disabled = on and not vessel_twin
		c.pressed.connect(_stand_down.bind(h as CoCaptainData) if on else _choose_captain.bind(h as CoCaptainData))
		buttons.add_child(c)
		captain_buttons.append(c)
	if not h is CoCaptainData and not roster.co_captains.is_empty():  # (the note only matters once there is a Co-Captain to choose)
		var k := MenuKit.label("Always in the active party", MenuKit.SMALL, MenuKit.PARCHMENT_DIM)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		buttons.add_child(k)
	return f[0]


func _vessel_row(v: VesselData) -> Control:
	var f := MenuKit.frame(true, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	f[1].add_child(row)
	row.add_child(_portrait(v, 64))
	var relics := v.loadout.relics().map(func(r): return r.display_name) if v.loadout else []
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(MenuKit.label(v.display_name, MenuKit.BODY + 2, MenuKit.TEAL, true, true))
	info.add_child(_label("Vessel  ·  Lv %d  ·  XP %s\nTethered %d×  ·  Severed %d×\nRelics: %s" % [v.level, _xp_text(v), v.tether_count, v.sever_count, ", ".join(relics) if not relics.is_empty() else "none"]))
	row.add_child(info)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	var sk := _button("Skills", 140)
	sk.pressed.connect(open_skills.bind(v))
	buttons.add_child(sk)
	skills_buttons.append(sk)
	var e := _button("Loadout", 140)
	e.pressed.connect(open_loadout.bind(v))
	buttons.add_child(e)
	vessel_loadout_buttons.append(e)
	return f[0]


static func _xp_text(u: UnitData) -> String:
	return "%d / %d" % [u.exp, u.exp_to_next_level] if u.exp_to_next_level > 0 else "max"


static func _label(text: String) -> Label:
	var l := MenuKit.label(text, MenuKit.BODY - 2, MenuKit.PARCHMENT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _button(text: String, width: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 46)
	MenuKit.liven(b)
	return b


## A member's portrait in a gold-rimmed frame (the sheet's own painted portrait, or its idle crop).
static func _portrait(u: UnitData, side: int) -> Control:
	var frame := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#0a0f1c")
	s.border_color = MenuKit.GOLD if u.is_human() else MenuKit.TEAL
	s.set_border_width_all(2)
	s.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", s)
	var t := TextureRect.new()
	t.texture = UnitLook.portrait(UnitLook.sheet_for(u))
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(t)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## The members in company order: the King, the Co-Captain in the field, the other Co-Captains, then the vessels.
func _members() -> Array[UnitData]:
	var out: Array[UnitData] = [roster.king]
	var cap := roster.deployed_co_captain()
	if cap != null:
		out.append(cap)
	for c in roster.co_captains:
		if c != cap:
			out.append(c)
	for v in roster.vessels():
		out.append(v)
	return out


## The member's weapon style and stance ("Rook Impact"), or "" without one.
static func _class_line(u: UnitData) -> String:
	if u.loadout != null and u.loadout.weapon_style != null:
		var ws := u.loadout.weapon_style
		return "%s %s" % [StanceRules.style_name(ws.geometry), StanceRules.stance_name(ws.stance)]
	return ""


## One member's card on the Company page: a focusable toggle (selected = the one Skills and Equipment open).
func _card(u: UnitData) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = u == selected_unit
	b.custom_minimum_size = Vector2(0, 214)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = "%s: select to open Skills or Equipment for this member" % u.display_name
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(_portrait(u, 76))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_constant_override("separation", 2)
	top.add_child(who)
	var name := MenuKit.label(u.display_name, MenuKit.HEADING - 2, MenuKit.GOLD_BRIGHT if u.is_human() else MenuKit.TEAL, true, true)
	name.clip_text = true
	who.add_child(name)
	var role := "King  ·  Commander" if u == roster.king else ("Co-Captain  ·  in the field" if u == roster.deployed_co_captain() else ("Co-Captain" if u is CoCaptainData else "Vessel"))
	who.add_child(MenuKit.label(role, MenuKit.SMALL, MenuKit.TEAL if u is VesselData else MenuKit.GOLD, true))
	var cls := MenuKit.label("Style: " + _class_line(u) if _class_line(u) != "" else "", MenuKit.SMALL, MenuKit.PARCHMENT_DIM)
	cls.clip_text = true
	who.add_child(cls)
	who.add_child(MenuKit.label("LV %d" % u.level, MenuKit.BODY, MenuKit.PARCHMENT, true, true))
	v.add_child(MenuKit.stat_bar("HP", u.stats.max_hp(u.loadout), u.stats.max_hp(u.loadout), MenuKit.HP))
	v.add_child(MenuKit.stat_bar("SP", u.stats.max_sp(u.loadout), u.stats.max_sp(u.loadout), MenuKit.SP))
	v.add_child(MenuKit.stat_bar("XP", u.exp, u.exp_to_next_level, MenuKit.XP))
	var tree := Mentorship.tree_of(u)
	var study := tree.active_study() if u.is_human() else null
	var foot := "%d skills learned" % tree.learned_skills().size()
	if study != null:
		foot += "  ·  studying %s" % study.skill.display_name
	elif u is VesselData:
		foot += "  ·  tethered %d×" % (u as VesselData).tether_count
	var fl := MenuKit.label(foot, MenuKit.SMALL, MenuKit.PARCHMENT_DIM)
	fl.clip_text = true
	v.add_child(fl)
	for c in v.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("normal", _card_box(false))
	b.add_theme_stylebox_override("hover", _card_box(false, true))
	b.add_theme_stylebox_override("pressed", _card_box(true))
	b.add_theme_stylebox_override("hover_pressed", _card_box(true, true))
	b.add_theme_stylebox_override("focus", MenuKit.focus_box())
	b.toggled.connect(func(on): if on: _select(u))
	MenuKit.liven(b)
	return b


static func _card_box(selected: bool, hover := false) -> StyleBoxFlat:
	var s := MenuKit.panel_box(true, 0)
	s.bg_color = Color("#0b1d3a") if selected else (Color("#1f2b3a") if hover else MenuKit.NAVY_2)
	s.border_color = MenuKit.TEAL if selected else (MenuKit.GOLD if hover else Color("#566a82"))
	s.set_border_width_all(2 if selected else 1)
	return s


func _select(u: UnitData) -> void:
	selected_unit = u
	for i in card_buttons.size():
		card_buttons[i].set_pressed_no_signal(_members()[i] == u)
	_update_footer()


func _fill_cards() -> void:
	if _cards == null:
		return
	for c in _cards.get_children():
		c.queue_free()
	card_buttons.clear()
	for u in _members():
		var b := _card(u)
		_cards.add_child(b)
		card_buttons.append(b)


## The next story mission on the world map (the first open map not yet cleared), or {} when there is none.
func _next_mission() -> Dictionary:
	for p in WorldData.PLACES:
		for m in p.maps:
			if WorldData.map_state(game.campaign, String(m.id)) == "mission":
				return {"place": p, "map": m}
	return {}


func _fill_side() -> void:
	if _side == null:
		return
	for c in _side.get_children():
		c.queue_free()
	var nm := _next_mission()
	var f := MenuKit.frame(false, 20)
	f[1].add_child(MenuKit.heading("Next mission"))
	if nm.is_empty():
		f[1].add_child(_label("No story mission is open. Replay a cleared map from the world map."))
	else:
		f[1].add_child(MenuKit.label(String(nm.map.name), MenuKit.HEADING - 2, MenuKit.GOLD_BRIGHT, true, true))
		f[1].add_child(MenuKit.label(String(nm.place.name), MenuKit.SMALL, MenuKit.TEAL, true))
		var bl := _label(String(nm.map.get("blurb", "")))
		f[1].add_child(bl)
	_side.add_child(f[0])
	var g := MenuKit.frame(false, 20)
	g[1].add_child(MenuKit.heading("Chapter"))
	var place_text := String(nm.place.get("blurb", "")) if not nm.is_empty() else "The story so far is complete."
	g[1].add_child(MenuKit.label(String(nm.place.name) if not nm.is_empty() else "—", MenuKit.BODY + 1, MenuKit.PARCHMENT, true, true))
	g[1].add_child(_label(place_text))
	_side.add_child(g[0])
	var h := MenuKit.frame(false, 20)
	h[1].add_child(MenuKit.heading("The company"))
	var c := game.campaign
	for row in [["Members", str(_members().size())], ["Vessels", str(roster.vessels().size())], ["Spare relics", str(roster.relic_inventory.size())],
			["Missions done", str(c.missions_completed.size())], ["Battles won", "%d / %d" % [c.battles_won, c.battles_fought]]]:
		h[1].add_child(_pair(row[0], row[1]))
	_side.add_child(h[0])
	if _subtitle != null:
		_subtitle.text = "The Hollowmark Company" + ("  ·  " + String(nm.place.name) if not nm.is_empty() else "")


static func _pair(k: String, v: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	var a := MenuKit.label(k, MenuKit.SMALL + 1, MenuKit.PARCHMENT_DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	r.add_child(MenuKit.label(v, MenuKit.BODY, MenuKit.PARCHMENT, true))
	return r


func _fill_records() -> void:
	if _records == null:
		return
	for c in _records.get_children():
		c.queue_free()
	var c := game.campaign
	for c2 in _records_b.get_children() + _records_units.get_children():
		c2.queue_free()
	for row in [["Battles fought", c.battles_fought], ["Battles won", c.battles_won], ["Battles lost", c.battles_lost], ["Missions completed", c.missions_completed.size()],
			["Maps cleared", c.maps_cleared.size()], ["Places opened", c.areas_unlocked.size()]]:
		_records.add_child(_pair(String(row[0]), str(row[1])))
	for row in [["Vessels summoned", c.vessels_tethered], ["Vessels faded", c.vessels_severed], ["Relics secured", c.relics_secured], ["Relics lost", c.relics_lost],
			["Skills learned", c.skills_learned], ["Skills collected", "%d / %d" % [SkillCollection.collected(game), SkillCollection.total()]], ["Spare relics now", roster.relic_inventory.size()]]:
		_records_b.add_child(_pair(String(row[0]), str(row[1])))
	for u in _members():  # every member's level and what it has learned
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_portrait(u, 36))
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		t.add_child(MenuKit.label(u.display_name, MenuKit.SMALL + 1, MenuKit.GOLD_BRIGHT if u.is_human() else MenuKit.TEAL, true))
		t.add_child(MenuKit.label("Lv %d  ·  %d skills" % [u.level, Mentorship.tree_of(u).learned_skills().size()], MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
		cell.add_child(t)
		_records_units.add_child(cell)
	if _journal_box != null:  # who mastered what, where it came from, newest first; then the bonds between students and their mentors
		for c3 in _journal_box.get_children():
			c3.queue_free()
		for line in journal_lines(game):
			_journal_box.add_child(MenuKit.label(line, MenuKit.SMALL + 1, MenuKit.PARCHMENT))


## The Records page's journal: Mentor Bonds first, then the last JOURNAL_SHOWN mastered skills, newest first.
const JOURNAL_SHOWN := 10


static func journal_lines(g: SaveGame) -> Array[String]:
	var out: Array[String] = []
	for h in g.roster.humans():
		if h.skill_tree == null:
			continue
		for mentor in h.skill_tree.mentor_bonds:
			var lv: int = h.skill_tree.bond_level(mentor)
			var bar: Array = h.skill_tree.bond_bar(mentor)
			out.append("Mentor Bond  ·  %s and %s  ·  Level %d%s  ·  +%d%% study speed" % [h.display_name, mentor, lv, "  (%d / %d)" % [bar[0], bar[1]] if int(bar[1]) > 0 else "  (max)", roundi(h.skill_tree.bond_bonus(mentor) * 100.0)])
	var j: Array = g.campaign.skill_journal
	if j.is_empty() and out.is_empty():
		out.append("No skill has been mastered yet. A vessel masters a skill by using it in battle; %s by studying it from a vessel." % ("Alaric" if g.roster.co_captains.is_empty() else "Alaric and the Co-Captains"))  # no Co-Captain wording before one is unlocked
	for i in range(j.size() - 1, maxi(-1, j.size() - 1 - JOURNAL_SHOWN), -1):
		var e: Dictionary = j[i]
		out.append("%s mastered %s  ·  %s%s  ·  battle %d" % [e.who, e.skill, e.source, "  ·  " + String(e.place) if String(e.place) != "" else "", int(e.battle)])
	if j.size() > JOURNAL_SHOWN:
		out.append("... and %d earlier" % (j.size() - JOURNAL_SHOWN))
	return out


func _fill_mission() -> void:
	if _mission_box == null:
		return
	_fill_world()
	_fill_system()
	for c in _mission_box.get_children():
		c.queue_free()
	var nm := _next_mission()
	_mission_box.add_child(MenuKit.label(String(nm.map.name) if not nm.is_empty() else "No open story mission", MenuKit.HEADING, MenuKit.GOLD_BRIGHT, true, true))
	if not nm.is_empty():
		_mission_box.add_child(MenuKit.label(String(nm.place.name), MenuKit.BODY, MenuKit.TEAL, true))
		_mission_box.add_child(_label(String(nm.map.get("blurb", ""))))
		for lv in nm.map.get("levels", []):
			_mission_box.add_child(MenuKit.label("•  " + String(lv), MenuKit.SMALL + 1, MenuKit.PARCHMENT_DIM))


## The places on the world map: open ones with how many of their maps are cleared, the rest as not yet reached.
func _fill_world() -> void:
	for c in _world_box.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 6)
	_world_box.add_child(grid)
	for p in WorldData.PLACES:
		var open := game.campaign.is_area_unlocked(p.id)
		var maps: Array = p.maps
		var cleared := maps.filter(func(m): return game.campaign.is_map_cleared(String(m.id))).size()
		var r := _pair(String(p.name) if open else "Not yet reached", ("%d / %d maps" % [cleared, maps.size()]) if open and not maps.is_empty() else ("open" if open else "—"))
		r.custom_minimum_size.x = 420
		if not open:
			r.modulate = Color(1, 1, 1, 0.45)
		grid.add_child(r)


## The save slots on disk and when each was written.
func _fill_system() -> void:
	for c in _system_box.get_children():
		c.queue_free()
	var list := SaveSystem.slots()
	if list.is_empty():
		_system_box.add_child(_label("No saved games yet."))
	for info in list:
		var when := Time.get_datetime_string_from_unix_time(int(info.get("saved_at", 0)), true) if int(info.get("saved_at", 0)) > 0 else "unknown time"
		_system_box.add_child(_pair(String(info.get("slot", "")) + ("  (this slot)" if String(info.get("slot", "")) == slot else ""), when))


## Shows a section's page (Skills and Equipment open the selected member's menu instead).
func show_section(name: String) -> void:
	match name:
		"Skills":
			open_skills(selected_unit if selected_unit != null else roster.king)
			return
		"Equipment":
			open_loadout(selected_unit if selected_unit != null else roster.king)
			return
	section = name
	for k in _pages:
		_pages[k].visible = k == name
	for b in nav_buttons:
		b.set_pressed_no_signal(b.text == name)
	_update_footer()
	if _pages.has(name):
		MenuKit.reveal(_pages[name])


func _update_footer() -> void:
	if _footer == null:
		return
	for c in _footer.get_children():
		c.queue_free()
	var hints := [["↑↓←→", "Move"], ["Enter", "Select"], ["Q / E", "Section"], ["Esc", "Back to Company"]]
	match section:
		"Company":
			hints = [["↑↓←→", "Choose a member"], ["Enter", "Select"], ["Q / E", "Section"],
				["", "Selected: %s · Skills and Equipment open this member" % (selected_unit.display_name if selected_unit else "—")]]
		"Formation":
			hints = [["↑↓", "Move"], ["Enter", "Mentorship · Skills · Loadout"], ["Q / E", "Section"], ["Esc", "Back"]]
		"Campaign":
			hints = [["Enter", "Deploy or return to the base"], ["Q / E", "Section"], ["Esc", "Back"]]
		"System":
			hints = [["Enter", "Save or load (%s)" % slot], ["Q / E", "Section"], ["Esc", "Back"]]
	for h in hints:
		if h[0] == "":
			_footer.add_child(MenuKit.label(h[1], MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
		else:
			_footer.add_child(MenuKit.hint(h[0], h[1]))


func _unhandled_input(e: InputEvent) -> void:
	if not main.visible:
		return
	var step := 0
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_Q:
			step = -1
		elif e.keycode == KEY_E:
			step = 1
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	if step != 0:
		var pages := ["Company", "Formation", "Campaign", "Records", "System"]
		var i := pages.find(section)
		show_section(pages[(i + step + pages.size()) % pages.size()])
		_focus_page()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel") and section != "Company":
		show_section("Company")
		_focus_page()
		get_viewport().set_input_as_handled()


func _focus_page() -> void:
	if section == "Company" and not card_buttons.is_empty():
		card_buttons[0].grab_focus.call_deferred()
	else:
		for b in nav_buttons:
			if b.text == section:
				b.grab_focus.call_deferred()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuKit.theme()
	add_child(MenuKit.backdrop())
	main = MarginContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		main.add_theme_constant_override("margin_" + side, 40)
	main.add_theme_constant_override("margin_top", 22)
	main.add_theme_constant_override("margin_bottom", 18)
	add_child(main)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	main.add_child(page)
	# header: the title and the status line
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(MenuKit.label("Company Headquarters", MenuKit.TITLE, MenuKit.GOLD_BRIGHT, true, true))
	_subtitle = MenuKit.label("The Hollowmark Company", MenuKit.SMALL + 1, MenuKit.TEAL, true)
	titles.add_child(_subtitle)
	head.add_child(titles)
	status = MenuKit.label("", MenuKit.SMALL + 1, MenuKit.PARCHMENT_DIM)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.clip_text = true
	head.add_child(status)
	page.add_child(head)
	page.add_child(MenuKit.Rule.new())
	# body: navigation | page | side information
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var nav := MenuKit.frame(false, 16)
	nav[0].custom_minimum_size.x = 250
	nav[1].add_theme_constant_override("separation", 8)
	nav[1].add_child(MenuKit.heading("Headquarters"))
	for name in SECTIONS:
		var b := Button.new()
		b.text = name
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_override("font", MenuKit.font(true, true))
		b.tooltip_text = {"Company": "Your company at a glance", "Formation": "Roster, Co-Captain, Mentorship and Loadouts",
			"Skills": "The selected member's skills", "Equipment": "The selected member's loadout", "Campaign": "Deploy, or return to the base",
			"Records": "The campaign so far", "System": "Save and load"}[name]
		b.pressed.connect(show_section.bind(name))
		MenuKit.liven(b)
		nav[1].add_child(b)
		nav_buttons.append(b)
	body.add_child(nav[0])
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stack)
	# Company: the member cards
	var company := _page(stack, "Company")
	company[1].add_child(MenuKit.heading("Active company"))
	var cscroll := ScrollContainer.new()
	cscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	company[1].add_child(cscroll)
	_cards = GridContainer.new()
	_cards.columns = 2
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)
	cscroll.add_child(_cards)
	# Formation: the roster with every member's buttons
	var formation := _page(stack, "Formation")
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	formation[1].add_child(cols)
	var c1 := _column(cols, "Commanders", 1.35)
	_humans_list = c1[1]
	var c2 := _column(cols, "Vessels", 1.2)
	_vessels_title = c2[0]
	_vessels_list = c2[1]
	var c3 := _column(cols, "Spare relics", 0.75)
	_relics_title = c3[0]
	_relics_list = c3[1]
	# Campaign: the next mission, deploy, the base
	var campaign := _page(stack, "Campaign")
	campaign[1].add_child(MenuKit.heading("Next mission"))
	_mission_box = VBoxContainer.new()
	_mission_box.add_theme_constant_override("separation", 8)
	campaign[1].add_child(_mission_box)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 14)
	battle_button = _button("Deploy to Battle", 260)
	battle_button.pressed.connect(start_battle)
	acts.add_child(battle_button)
	base_button = _button("Return to the Base", 260)
	base_button.pressed.connect(go_to_base)
	acts.add_child(base_button)
	campaign[1].add_child(acts)
	campaign[1].add_child(MenuKit.heading("The world"))
	_world_box = VBoxContainer.new()
	_world_box.add_theme_constant_override("separation", 8)
	campaign[1].add_child(_world_box)
	# Records: the campaign's numbers
	var records := _page(stack, "Records")
	records[1].add_child(MenuKit.heading("Campaign records"))
	var rec := GridContainer.new()
	rec.columns = 2
	rec.add_theme_constant_override("h_separation", 48)
	rec.add_theme_constant_override("v_separation", 12)
	records[1].add_child(rec)
	_records = VBoxContainer.new()  # battles and missions
	_records.add_theme_constant_override("separation", 12)
	_records.custom_minimum_size.x = 420
	rec.add_child(_records)
	_records_b = VBoxContainer.new()  # vessels, relics, skills
	_records_b.add_theme_constant_override("separation", 12)
	_records_b.custom_minimum_size.x = 420
	rec.add_child(_records_b)
	records[1].add_child(MenuKit.heading("Members"))
	_records_units = GridContainer.new()
	_records_units.columns = 4
	_records_units.add_theme_constant_override("h_separation", 36)
	_records_units.add_theme_constant_override("v_separation", 8)
	records[1].add_child(_records_units)
	records[1].add_child(MenuKit.heading("Skill journal"))
	_journal_box = VBoxContainer.new()
	_journal_box.add_theme_constant_override("separation", 4)
	records[1].add_child(_journal_box)
	# System: save and load
	var system := _page(stack, "System")
	system[1].add_child(MenuKit.heading("Save and load"))
	system[1].add_child(_label("One save slot (%s). The game continues from the newest save when it starts." % slot))
	var sl := HBoxContainer.new()
	sl.add_theme_constant_override("separation", 14)
	save_button = _button("Save", 200)
	save_button.pressed.connect(save_game)
	sl.add_child(save_button)
	load_button = _button("Load", 200)
	load_button.pressed.connect(load_game)
	sl.add_child(load_button)
	system[1].add_child(sl)
	system[1].add_child(MenuKit.heading("Saved games"))
	_system_box = VBoxContainer.new()
	_system_box.add_theme_constant_override("separation", 8)
	system[1].add_child(_system_box)
	# side information
	_side = VBoxContainer.new()
	_side.custom_minimum_size.x = 380
	_side.add_theme_constant_override("separation", 16)
	body.add_child(_side)
	# footer: context hints
	page.add_child(MenuKit.Rule.new())
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 26)
	page.add_child(_footer)
	mentorship = MentorshipMenu.new()
	mentorship.hide()
	mentorship.closed.connect(_on_sub_menu_closed)
	add_child(mentorship)
	skills_menu = SkillsMenu.new()
	skills_menu.hide()
	skills_menu.closed.connect(_on_sub_menu_closed)
	skills_menu.mentor_requested.connect(_on_mentor_from_skills)
	add_child(skills_menu)
	loadout_menu = LoadoutMenu.new()
	loadout_menu.hide()
	loadout_menu.closed.connect(_on_sub_menu_closed)
	add_child(loadout_menu)
	show_section.call_deferred("Company")
	_focus_page.call_deferred()


## A page of the centre stack: a framed panel filling it. Returns [panel, body].
func _page(stack: Control, name: String) -> Array:
	var f := MenuKit.frame(false, 22)
	f[0].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f[0].visible = name == "Company"
	stack.add_child(f[0])
	_pages[name] = f[0]
	return f


## A column: a heading and a scrolling list. Returns [heading label, list].
func _column(parent: Control, heading: String, ratio := 1.0) -> Array:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = ratio
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)
	var h := MenuKit.heading(heading)
	col.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return [h.get_child(0), list]
