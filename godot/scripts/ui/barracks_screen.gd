class_name BarracksScreen
extends Control
## The Company Headquarters (the out-of-battle main menu), the visual reference for every menu (MenuKit). Tabs along the top: Roster, Equipment,
## Abilities, Campaign, Records, System. Roster (owner's layout, Nov 2026; mockup `docs/mockups/menus/roster_page.png`): the company list on the left (portrait,
## name, level, HP and SP), the selected member in the centre (a vertical portrait strip, name, role, level, HP / SP / XP and the eight attributes) and their
## equipment and skills on the right. Equipment and Abilities open the selected member's loadout and skills menus. Campaign starts the battle or returns to
## the base; System saves and loads. **The main menu does not pick the battle party: the Formation pop-up before every battle does** (FormationPopup).
## Mouse, keyboard and controller: focus moves with the arrows, Q and E (or the shoulder buttons) change tab, Esc / B goes back to the Roster.

const DEFAULT_SLOT := "slot1"

var game: SaveGame
var roster: PartyRoster
var slot := DEFAULT_SLOT
var main: Control
var loadout_menu: LoadoutMenu
var skills_menu: SkillsMenu  ## the skills of any unit: the same menu for everyone
var status: Label
var save_button: Button
var load_button: Button
var battle_button: Button
var base_button: Button  ## back to the base
## the new layout
const SECTIONS := ["Roster", "Equipment", "Abilities", "Campaign", "Records", "System"]
const PAGES := ["Roster", "Campaign", "Records", "System"]  ## the tabs that show a page (Equipment and Abilities open the selected member's menus)
var nav_buttons: Array[Button] = []
var card_buttons: Array[Button] = []  ## one per member in the Roster's list, in _members() order
var selected_unit: UnitData  ## the member shown in the centre, and the one Equipment and Abilities open (the King until another is chosen)
var section := "Roster"
var _pages := {}  ## section -> Control
var _list: VBoxContainer
var _list_title: Label
var _detail: VBoxContainer
var _equip_box: VBoxContainer
var _skills_box: VBoxContainer
var _footer: HBoxContainer
var _records: VBoxContainer
var _records_b: VBoxContainer
var _records_units: GridContainer
var _journal_box: VBoxContainer  ## Records: the Skill Journal (newest first)
var _world_box: VBoxContainer
var _system_box: VBoxContainer
var _mission_box: VBoxContainer
var _first_status := ""
var _subtitle: Label  ## the chapter's place, top right
var _chapter_name: Label


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
	return GameSession.current()  # no save: the story's party (Alaric alone, then the companions who join)


func refresh() -> void:
	if selected_unit == null or not roster.all_units().has(selected_unit):
		selected_unit = roster.king
	_fill_list()
	_fill_detail()
	_fill_chapter()
	_fill_records()
	_fill_mission()


func open_skills(unit: UnitData) -> void:
	main.hide()
	skills_menu.open(unit)


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


## The members in company order: the King, then his companions.
func _members() -> Array[UnitData]:
	var out: Array[UnitData] = [roster.king]
	out.append_array(roster.company())
	return out


## The member's weapon style and stance ("Rook Impact"), or "" without one.
static func _class_line(u: UnitData) -> String:
	if u.loadout != null and u.loadout.weapon_style != null:
		var ws := u.loadout.weapon_style
		return "%s %s" % [StanceRules.style_name(ws.geometry), StanceRules.stance_name(ws.stance)]
	return ""


static func _thin_bar(value: int, max_value: int, fill: Color, w := 200.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = Color("#070b12")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(back)
	var f := ColorRect.new()
	f.color = fill
	f.size = Vector2(w * clampf(float(value) / maxf(max_value, 1), 0.0, 1.0), 8)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(f)
	return c


static func _role_line(u: UnitData) -> String:
	return FormationPopup.role_text(u)


## One member's row in the Roster's company list: a focusable toggle (the lit one is shown in the centre and is the one Equipment and Abilities open).
func _row(u: UnitData) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = u == selected_unit
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = "%s: shown on the right; Equipment and Abilities open this member" % u.display_name
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -12
	h.offset_top = 8
	h.offset_bottom = -8
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	h.add_child(_portrait(u, 66))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var top := HBoxContainer.new()
	var name := MenuKit.label(u.display_name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT, true, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	top.add_child(name)
	top.add_child(MenuKit.label("LV %d" % u.level, MenuKit.SMALL, MenuKit.TEAL, true))
	v.add_child(top)
	v.add_child(_thin_bar(u.stats.max_hp(u.loadout), u.stats.max_hp(u.loadout), MenuKit.HP))
	v.add_child(_thin_bar(u.stats.max_sp(u.loadout), u.stats.max_sp(u.loadout), MenuKit.SP))
	for c in b.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var off := HudStyle.slim_panel(0, 0)
	var lit := HudStyle.lit_panel(0, 0)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("focus", MenuKit.focus_box())
	b.toggled.connect(func(on): if on: _select(u))
	b.focus_entered.connect(func(): if selected_unit != u: _select(u))  # arrowing down the list browses the members
	MenuKit.liven(b)
	return b


func _select(u: UnitData) -> void:
	selected_unit = u
	var members := _members()
	for i in card_buttons.size():
		card_buttons[i].set_pressed_no_signal(members[i] == u)
	_fill_detail()
	_update_footer()


func _fill_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	card_buttons.clear()
	_list_title.text = "Company  ·  %d members" % _members().size()
	for u in _members():
		var b := _row(u)
		_list.add_child(b)
		card_buttons.append(b)


const ATTRIBUTES := [["Attack", StatModifier.Stat.ATTACK], ["Defense", StatModifier.Stat.DEFENSE], ["Magic", StatModifier.Stat.MAGIC],
		["Resistance", StatModifier.Stat.RESISTANCE], ["Speed", StatModifier.Stat.SPEED], ["Will", StatModifier.Stat.WILL],
		["Move", StatModifier.Stat.MOVE], ["Jump", StatModifier.Stat.JUMP]]


## The strip: the middle of the painted portrait, full height, in a steel-blue rim (a tall crop, not a full figure).
static func _strip(u: UnitData, size: Vector2) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0a0f1c")
	st.border_color = MenuKit.GOLD_BRIGHT
	st.set_border_width_all(2)
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)
	var t := TextureRect.new()
	var tex := UnitLook.portrait(UnitLook.sheet_for(u))
	if tex != null:
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		var at := AtlasTexture.new()
		at.atlas = tex
		var keep := minf(w, h * size.x / size.y)
		at.region = Rect2((w - keep) * 0.5, 0, keep, h)
		tex = at
	t.texture = tex
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(t)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return frame


func _stat_row(caption: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var c := MenuKit.label(caption, MenuKit.BODY, MenuKit.PARCHMENT_DIM, true)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	h.add_child(MenuKit.label(value, MenuKit.BODY, MenuKit.PARCHMENT, true))
	return h


## The centre and the right of the Roster for the selected member.
func _fill_detail() -> void:
	if _detail == null:
		return
	for box in [_detail, _equip_box, _skills_box]:
		for c in box.get_children():
			c.queue_free()
	var u := selected_unit if selected_unit != null else roster.king
	var head := HBoxContainer.new()
	var nm := MenuKit.label(u.display_name, MenuKit.TITLE - 8, MenuKit.GOLD_BRIGHT, true, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(MenuKit.label("%s  ·  Level %d" % [_role_line(u), u.level], MenuKit.BODY, MenuKit.TEAL, true))
	_detail.add_child(head)
	_detail.add_child(MenuKit.Rule.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(body)
	body.add_child(_strip(u, Vector2(250, 640)))
	var nums := VBoxContainer.new()
	nums.add_theme_constant_override("separation", 6)
	nums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(nums)
	nums.add_child(MenuKit.stat_bar("HP", u.stats.max_hp(u.loadout), u.stats.max_hp(u.loadout), MenuKit.HP))
	nums.add_child(MenuKit.stat_bar("SP", u.stats.max_sp(u.loadout), u.stats.max_sp(u.loadout), MenuKit.SP))
	nums.add_child(MenuKit.stat_bar("XP", u.exp, u.exp_to_next_level, MenuKit.XP))
	nums.add_child(Control.new())
	for a in ATTRIBUTES:
		nums.add_child(_stat_row(a[0], str(u.stats.final_stat(a[1], u.loadout))))
		nums.add_child(MenuKit.Rule.new())
	if _class_line(u) != "":
		nums.add_child(MenuKit.label("Weapon style   " + _class_line(u), MenuKit.BODY, MenuKit.PARCHMENT, true))
	# equipment
	_equip_box.add_child(MenuKit.heading("Equipment"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	_equip_box.add_child(g)
	var l := u.loadout
	var weapon: String = l.main_weapon.display_name if l != null and l.main_weapon != null else "None"
	var r1: String = l.relic_slot_1.display_name if l != null and l.relic_slot_1 != null else "Empty"
	var r2: String = l.relic_slot_2.display_name if l != null and l.relic_slot_2 != null else "Empty"
	g.add_child(_slot_tile("Main weapon", weapon))
	g.add_child(_slot_tile("Weapon style", FormationPopup.style_text(u) if _class_line(u) != "" else "None"))
	g.add_child(_slot_tile("Relic 1", r1))
	g.add_child(_slot_tile("Relic 2", r2))
	# skills
	_skills_box.add_child(MenuKit.heading("Abilities & skills"))
	var learned := SkillTree.of(u).learned_skills()
	if learned.is_empty():
		_skills_box.add_child(_label("No skills learned yet."))
	var shown := 0
	for sk in learned:
		if shown >= 7:
			break
		_skills_box.add_child(_skill_row(sk))
		shown += 1
	if learned.size() > shown:
		_skills_box.add_child(MenuKit.label("+ %d more in Abilities" % (learned.size() - shown), MenuKit.SMALL, MenuKit.PARCHMENT_DIM))


func _slot_tile(caption: String, text: String) -> Control:
	var f := MenuKit.frame(true, 10)
	f[1].add_theme_constant_override("separation", 2)
	f[1].add_child(MenuKit.label(caption, MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	var t := MenuKit.label(text, MenuKit.BODY, MenuKit.GOLD_BRIGHT if text not in ["Empty", "None"] else MenuKit.GOLD_DIM, true)
	t.clip_text = true
	f[1].add_child(t)
	f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f[0]


func _skill_row(sk: SkillData) -> Control:
	var f := MenuKit.frame(true, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var badge := MenuKit.label(String(SkillData.Rank.keys()[sk.rank]), MenuKit.HEADING - 4, MenuKit.rank_color(int(sk.rank)), true, true)
	badge.custom_minimum_size.x = 30
	h.add_child(badge)
	var n := MenuKit.label(sk.display_name, MenuKit.BODY, MenuKit.PARCHMENT, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	h.add_child(MenuKit.label(String(Proficiency.Category.keys()[sk.category]).capitalize(), MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	f[1].add_child(h)
	f[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f[0]


## The next story mission on the world map (the first open map not yet cleared), or {} when there is none.
func _next_mission() -> Dictionary:
	for p in WorldData.PLACES:
		for m in p.maps:
			if WorldData.map_state(game.campaign, String(m.id)) == "mission":
				return {"place": p, "map": m}
	return {}


## The chapter's place, top right.
func _fill_chapter() -> void:
	if _subtitle == null:
		return
	var nm := _next_mission()
	_chapter_name.text = String(nm.place.name) if not nm.is_empty() else "The story so far is complete"
	_subtitle.text = "The next chapter" if not nm.is_empty() else "Chapter"


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
	for row in [["Relics secured", c.relics_secured], ["Relics lost", c.relics_lost],
			["Skills learned", c.skills_learned], ["Skills collected", "%d / %d" % [SkillCollection.collected(game), SkillCollection.total()]], ["Spare relics now", roster.relic_inventory.size()]]:
		_records_b.add_child(_pair(String(row[0]), str(row[1])))
	for u in _members():  # every member's level and what it has learned
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_portrait(u, 36))
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		t.add_child(MenuKit.label(u.display_name, MenuKit.SMALL + 1, MenuKit.GOLD_BRIGHT if u.is_human() else MenuKit.TEAL, true))
		t.add_child(MenuKit.label("Lv %d  ·  %d skills" % [u.level, SkillTree.of(u).learned_skills().size()], MenuKit.SMALL, MenuKit.PARCHMENT_DIM))
		cell.add_child(t)
		_records_units.add_child(cell)
	if _journal_box != null:  # who mastered what, where it came from, newest first
		for c3 in _journal_box.get_children():
			c3.queue_free()
		for line in journal_lines(game):
			_journal_box.add_child(MenuKit.label(line, MenuKit.SMALL + 1, MenuKit.PARCHMENT))


## The Records page's journal: the last JOURNAL_SHOWN mastered skills, newest first.
const JOURNAL_SHOWN := 10


static func journal_lines(g: SaveGame) -> Array[String]:
	var out: Array[String] = []
	var j: Array = g.campaign.skill_journal
	if j.is_empty():
		out.append("No skill has been mastered yet. Equip a relic and use its skill in battle to learn it for good.")
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


## Shows a tab's page (Equipment and Abilities open the selected member's menu instead).
func show_section(name: String) -> void:
	match name:
		"Abilities":
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
		if c != status:
			c.queue_free()
	var hints := [["↑↓←→", "Move"], ["Enter", "Select"], ["Q / E", "Tab"], ["Esc", "Back to Roster"]]
	match section:
		"Roster":
			hints = [["↑↓", "Choose a member"], ["Q / E", "Tab"], ["", "Shown: %s  ·  Equipment and Abilities open this member" % (selected_unit.display_name if selected_unit else "—")]]
		"Campaign":
			hints = [["Enter", "Deploy or return to the base"], ["Q / E", "Tab"], ["Esc", "Back"]]
		"System":
			hints = [["Enter", "Save or load (%s)" % slot], ["Q / E", "Tab"], ["Esc", "Back"]]
	var at := 0
	for h in hints:
		var n: Control = MenuKit.label(h[1], MenuKit.SMALL, MenuKit.PARCHMENT_DIM) if h[0] == "" else MenuKit.hint(h[0], h[1])
		_footer.add_child(n)
		_footer.move_child(n, at)
		at += 1


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
		var i := PAGES.find(section)
		show_section(PAGES[(i + step + PAGES.size()) % PAGES.size()])
		_focus_page()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel") and section != "Roster":
		show_section("Roster")
		_focus_page()
		get_viewport().set_input_as_handled()


func _focus_page() -> void:
	if section == "Roster" and not card_buttons.is_empty():
		var i := _members().find(selected_unit)
		card_buttons[maxi(i, 0)].grab_focus.call_deferred()
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
	# header: the tabs, and the chapter on the right
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	for name in SECTIONS:
		var b := Button.new()
		b.text = name
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(170, 52)
		b.tooltip_text = {"Roster": "Your company at a glance", "Equipment": "The selected member's loadout", "Abilities": "The selected member's skills",
			"Campaign": "Deploy, or return to the base", "Records": "The campaign so far", "System": "Save and load"}[name]
		b.pressed.connect(show_section.bind(name))
		MenuKit.liven(b)
		head.add_child(b)
		nav_buttons.append(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var ch := VBoxContainer.new()
	ch.add_theme_constant_override("separation", 0)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	_subtitle = MenuKit.label("", MenuKit.SMALL, MenuKit.TEAL, true)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ch.add_child(_subtitle)
	_chapter_name = MenuKit.label("", MenuKit.BODY, MenuKit.PARCHMENT, true, true)
	_chapter_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ch.add_child(_chapter_name)
	head.add_child(ch)
	page.add_child(head)
	page.add_child(MenuKit.Rule.new())
	# the pages
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(stack)
	# Roster: the company list | the selected member | equipment and skills
	var roster_page := HBoxContainer.new()
	roster_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roster_page.add_theme_constant_override("separation", 22)
	stack.add_child(roster_page)
	_pages["Roster"] = roster_page
	var left := MenuKit.column(roster_page, "Company", 420, 0.0)
	_list_title = left.get_child(0).get_child(0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_detail = MenuKit.column(roster_page, "", 0, 1.1)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 478
	right.add_theme_constant_override("separation", 16)
	roster_page.add_child(right)
	var eq := MenuKit.frame(false, 20)
	_equip_box = eq[1]
	right.add_child(eq[0])
	var sk := MenuKit.frame(false, 20)
	sk[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_box = sk[1]
	right.add_child(sk[0])
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
	_records_b = VBoxContainer.new()  # relics and skills
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
	# footer: context hints, and the status line on the right
	page.add_child(MenuKit.Rule.new())
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 26)
	page.add_child(_footer)
	status = MenuKit.label("", MenuKit.SMALL + 1, MenuKit.PARCHMENT_DIM)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.clip_text = true
	_footer.add_child(status)
	skills_menu = SkillsMenu.new()
	skills_menu.hide()
	skills_menu.closed.connect(_on_sub_menu_closed)
	add_child(skills_menu)
	loadout_menu = LoadoutMenu.new()
	loadout_menu.hide()
	loadout_menu.closed.connect(_on_sub_menu_closed)
	add_child(loadout_menu)
	show_section.call_deferred("Roster")
	_focus_page.call_deferred()


## A page of the stack: a framed panel filling it. Returns [panel, body].
func _page(stack: Control, name: String) -> Array:
	var f := MenuKit.frame(false, 22)
	f[0].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f[0].visible = false
	stack.add_child(f[0])
	_pages[name] = f[0]
	return f
