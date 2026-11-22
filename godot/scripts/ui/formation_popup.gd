class_name FormationPopup
extends Control
## The Formation pop-up before a battle (owner, Nov 2026; mockup `docs/mockups/menus/formation_popup.png`, layout A): the company on the left, the battle
## party's slots on the right with Alaric always leading, Back and Fight below. A card toggles a member in or out of the party (up to PartyRoster.PARTY_SIZE);
## Fight remembers the pick in the save (PartyRoster.set_party, autosaved) and emits `fight`. Nothing about the party is picked in the main menu.
## Mouse, keyboard and controller: focus moves with the arrows, Enter toggles, Esc goes back.

signal fight
signal closed

var game: SaveGame
var roster: PartyRoster
var chosen: Array[UnitData] = []  ## the party being built (never the King)
var heading := "Formation"
var subtitle := ""
var card_buttons := {}  ## UnitData -> Button
var remove_buttons: Array[Button] = []
var fight_button: Button
var back_button: Button
var message: Label
var count_label: Label
var _slots: VBoxContainer
var _grid: GridContainer


## Builds the pop-up for `g` (call after adding it to the tree or before; it fills itself in `_ready`).
static func create(g: SaveGame, sub := "") -> FormationPopup:
	var p := FormationPopup.new()
	p.game = g
	p.roster = g.roster
	p.subtitle = sub
	return p


## Whether a battle should open the pop-up: there has to be someone to choose.
static func needed(g: SaveGame) -> bool:
	return g != null and g.roster != null and not g.roster.company().is_empty()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuKit.theme()
	chosen = roster.party()
	var back_drop := ColorRect.new()
	back_drop.color = Color(0, 0, 0, 0.6)
	back_drop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back_drop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var f := MenuKit.frame(false, 26)
	f[0].custom_minimum_size = Vector2(1460, 800)
	center.add_child(f[0])
	_build(f[1])
	refresh()
	(card_buttons.values()[0] as Control).grab_focus() if not card_buttons.is_empty() else fight_button.grab_focus()


func _build(box: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(MenuKit.label(heading, MenuKit.TITLE - 8, MenuKit.GOLD_BRIGHT, true, true))
	var sub := subtitle + ("  ·  " if subtitle != "" else "") + "Your last party is remembered"
	t.add_child(MenuKit.label(sub, MenuKit.SMALL + 1, MenuKit.TEAL, true))
	head.add_child(t)
	count_label = MenuKit.label("", MenuKit.BODY, MenuKit.PARCHMENT, true)
	head.add_child(count_label)
	box.add_child(head)
	box.add_child(MenuKit.Rule.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var left := MenuKit.column(body, "Company", 0, 1.25)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	left.add_child(_grid)
	var right := MenuKit.column(body, "Battle party", 500, 0.0)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	right.add_child(_slots)
	message = MenuKit.label("Choose someone on the left to swap them in. Alaric always leads.", MenuKit.SMALL, MenuKit.PARCHMENT_DIM)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(message)
	box.add_child(MenuKit.Rule.new())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	back_button = Button.new()
	back_button.text = "‹  Back"
	back_button.custom_minimum_size = Vector2(190, 56)
	MenuKit.liven(back_button)
	back_button.pressed.connect(_close)
	foot.add_child(back_button)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	foot.add_child(MenuKit.label("Enter  Add or remove", MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	fight_button = MenuKit.action_button("Fight")
	fight_button.custom_minimum_size = Vector2(260, 60)
	fight_button.pressed.connect(confirm)
	foot.add_child(fight_button)
	box.add_child(foot)


## Redraws the cards, the slots and the counter from `chosen`.
func refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	card_buttons.clear()
	for u in roster.company():
		var b := _card(u, chosen.has(u))
		_grid.add_child(b)
		card_buttons[u] = b
	for c in _slots.get_children():
		c.queue_free()
	remove_buttons.clear()
	_slots.add_child(_slot(roster.king, "★", true))
	for i in PartyRoster.PARTY_SIZE:
		_slots.add_child(_slot(chosen[i] if i < chosen.size() else null, str(i + 1), false))
	count_label.text = "Party  %d / %d" % [chosen.size(), PartyRoster.PARTY_SIZE]


## Adds a member to the party, or takes them out when they are in. Returns false when the party is full.
func toggle(u: UnitData) -> bool:
	if chosen.has(u):
		chosen.erase(u)
		message.text = "%s stays in reserve." % u.display_name
	elif chosen.size() >= PartyRoster.PARTY_SIZE:
		message.text = "The party is full: send someone back to reserve first."
		return false
	else:
		chosen.append(u)
		message.text = "%s joins the party." % u.display_name
	refresh()
	if card_buttons.has(u):
		(card_buttons[u] as Control).grab_focus.call_deferred()
	return true


## Fight: remembers the pick in the save and goes on.
func confirm() -> void:
	roster.set_party(chosen)
	SaveSystem.save_slot(SaveSystem.AUTOSAVE, game)
	fight.emit()
	queue_free()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


# ---------- pieces ----------

static func style_text(u: UnitData) -> String:
	var ws: WeaponStyle = u.loadout.weapon_style if u.loadout != null else null
	if ws == null:
		return ""
	return "%s  ·  %s" % [String(TacticalMath.Geometry.keys()[ws.geometry]).capitalize(), String(WeaponStyle.Stance.keys()[ws.stance]).capitalize()]


static func role_text(u: UnitData) -> String:
	match u.role():
		UnitData.Role.KING:
			return "King"
		UnitData.Role.CO_CAPTAIN:
			return "Co-Captain"
	return "Companion"


func _portrait(u: UnitData, size: Vector2, rim: Color) -> Control:
	var frame := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0a0f1c")
	st.border_color = rim
	st.set_border_width_all(2)
	st.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", st)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = UnitLook.portrait(UnitLook.sheet_for(u))
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(t)
	return frame


func _card(u: UnitData, in_party: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	var face := MenuKit.steel_plate(10, in_party)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, face)
	b.add_theme_stylebox_override("focus", MenuKit.focus_box())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = 8
	row.offset_right = -10
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait(u, Vector2(100, 100), MenuKit.GOLD if in_party else MenuKit.GOLD_DIM))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_ignore(MenuKit.label(u.display_name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT, true, true)))
	v.add_child(_ignore(MenuKit.label("%s  ·  LV %d" % [role_text(u), u.level], MenuKit.SMALL, MenuKit.TEAL, true)))
	v.add_child(_ignore(MenuKit.label(style_text(u), MenuKit.SMALL, MenuKit.PARCHMENT_DIM)))
	v.add_child(_ignore(MenuKit.label("IN PARTY" if in_party else "RESERVE", MenuKit.SMALL, MenuKit.GOLD_BRIGHT if in_party else MenuKit.PARCHMENT_DIM, true)))
	row.add_child(v)
	b.add_child(row)
	if not in_party:
		b.modulate = Color(1, 1, 1, 0.78)
	b.pressed.connect(toggle.bind(u))
	return b


func _ignore(l: Control) -> Control:
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _slot(u: UnitData, n: String, fixed: bool) -> Control:
	var f := MenuKit.frame(true, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var num := MenuKit.label(n, MenuKit.HEADING, MenuKit.TEAL if fixed else MenuKit.GOLD, true, true)
	num.custom_minimum_size.x = 34
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(num)
	if u == null:
		var empty := MenuKit.label("Empty slot", MenuKit.BODY, MenuKit.GOLD_DIM, true)
		empty.custom_minimum_size.y = 64
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(empty)
		f[1].add_child(row)
		return f[0]
	row.add_child(_portrait(u, Vector2(64, 64), MenuKit.TEAL if fixed else MenuKit.GOLD))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(MenuKit.label(u.display_name, MenuKit.HEADING - 6, MenuKit.GOLD_BRIGHT, true, true))
	v.add_child(MenuKit.label("%s  ·  LV %d" % [role_text(u), u.level], MenuKit.SMALL, MenuKit.PARCHMENT_DIM, true))
	row.add_child(v)
	if not fixed:
		var rm := Button.new()
		rm.text = "Remove"
		rm.flat = true
		rm.focus_mode = Control.FOCUS_ALL
		rm.pressed.connect(toggle.bind(u))
		row.add_child(rm)
		remove_buttons.append(rm)
	f[1].add_child(row)
	return f[0]
