class_name LoadoutMenu
extends Control
## Equipment sub-menu for one unit (human or vessel): the five slots, and for the two relic slots a
## choice of the spare relics in the inventory (or empty). The rules live in RosterManager. The other
## three slots are shown but fixed: the Main Weapon is bound to its unit, there are no spare Weapon
## Styles yet, and the Temp-Relic is filled only by tethering in battle. Built on MenuKit's sub-screen
## shell (the Company Headquarters look), with the member's equipped stats under the slots; Esc / B goes back.

signal closed
signal changed

var unit: UnitData
var roster: PartyRoster
var _choices: Array = []  ## RelicItem or null (empty), for the selected relic slot

var title: Label
var slot_list: ItemList
var choice_list: ItemList
var choice_heading: Control
var detail: Label
var apply_button: Button
var back_button: Button


func _ready() -> void:
	_build()


func open(u: UnitData, party: PartyRoster) -> void:
	unit = u
	roster = party
	refresh()
	slot_list.select(2)
	_on_slot_selected(2)
	show()
	MenuKit.set_plate(_plate, unit)
	MenuKit.reveal(_body, 14.0)
	slot_list.grab_focus.call_deferred()


## Redraws from the current data, keeping the selected slot.
func refresh() -> void:
	if unit == null:
		return
	title.text = "Equipment  ·  %s" % unit.display_name
	var keep := selected_slot()
	slot_list.clear()
	var l := unit.loadout
	for slot in EquipmentLoadout.SLOT_COUNT:
		slot_list.add_item("%s:  %s" % [EquipmentLoadout.SLOT_NAMES[slot], _slot_text(l, slot)])
		var fixed := slot == EquipmentLoadout.Slot.MAIN_WEAPON or slot == EquipmentLoadout.Slot.TEMP_RELIC
		slot_list.set_item_custom_fg_color(slot_list.item_count - 1, MenuKit.PARCHMENT_DIM if fixed else MenuKit.PARCHMENT)
	_fill_stats()
	if keep >= 0:
		slot_list.select(keep)
	_fill_choices()
	_show_detail()


## The selected slot (an EquipmentLoadout.Slot), or -1.
func selected_slot() -> int:
	var sel := slot_list.get_selected_items()
	return sel[0] if sel.size() > 0 else -1


func _slot_text(l: EquipmentLoadout, slot: int) -> String:
	if l == null:
		return "-"
	match slot:
		EquipmentLoadout.Slot.MAIN_WEAPON:
			var w := l.main_weapon
			return "%s  (%s %d)" % [w.display_name if w.display_name != "" else "Unnamed weapon", w.tier_name(), w.power()] if w else "none"
		EquipmentLoadout.Slot.WEAPON_STYLE:
			var s := l.weapon_style
			return "%s  ·  %s" % [StanceRules.style_name(s.geometry), StanceRules.stance_name(s.stance)] if s else "none"
		EquipmentLoadout.Slot.TEMP_RELIC:
			return l.temp_relic.display_name if l.temp_relic else "empty (battle only)"
	var r := l.get_slot(slot) as RelicItem
	return r.display_name if r else "empty"


func _on_slot_selected(_i: int) -> void:
	_fill_choices()
	_show_detail()


func _fill_choices() -> void:
	choice_list.clear()
	_choices = []
	var slot := selected_slot()
	if choice_heading is Label:
		(choice_heading as Label).text = "FOUND STYLES" if slot == EquipmentLoadout.Slot.WEAPON_STYLE else "SPARE RELICS"
	if slot == EquipmentLoadout.Slot.WEAPON_STYLE and unit.loadout != null:  # the styles this unit has found
		var now := PartyRoster.style_key(unit.loadout.weapon_style.geometry, unit.loadout.weapon_style.stance) if unit.loadout.weapon_style else ""
		var rest: Array[String] = unit.known_style_keys().filter(func(k: String) -> bool: return k != now)
		rest.sort()
		var keys: Array[String] = []
		if now != "":
			keys.append(now)  # what is equipped comes first, and is selected
		keys.append_array(rest)
		for k in keys:
			var st := PartyRoster.style_from_key(k)
			_choices.append(k)
			choice_list.add_item("%s  ·  %s%s" % [StanceRules.style_name(st.geometry), StanceRules.stance_name(st.stance), "  (equipped)" if k == now else ""])
		if not keys.is_empty():
			choice_list.select(0)
		return
	if slot != EquipmentLoadout.Slot.RELIC_SLOT_1 and slot != EquipmentLoadout.Slot.RELIC_SLOT_2:
		return
	var current := unit.loadout.get_slot(slot) as RelicItem if unit.loadout else null
	if current != null:  # first, and selected: keeping what is equipped
		_choices.append(current)
		choice_list.add_item("%s  (equipped)" % current.display_name)
	_choices.append(null)
	choice_list.add_item("— Empty —")
	for r in roster.relic_inventory:
		_choices.append(r)
		choice_list.add_item(r.display_name)
	choice_list.select(0)


func _on_choice_selected(_i: int) -> void:
	_show_detail()


func _selected_choice() -> Variant:
	var sel := choice_list.get_selected_items()
	return _choices[sel[0]] if sel.size() > 0 and sel[0] < _choices.size() else null


func _show_detail() -> void:
	var slot := selected_slot()
	apply_button.disabled = true
	apply_button.text = "Equip"
	if slot < 0 or unit.loadout == null:
		detail.text = "Pick a slot."
		return
	match slot:
		EquipmentLoadout.Slot.MAIN_WEAPON:
			detail.text = "Bound to %s. Smithing upgrades it; it cannot be swapped." % unit.display_name
			return
		EquipmentLoadout.Slot.WEAPON_STYLE:
			var pick = _selected_choice()
			var st := PartyRoster.style_from_key(String(pick)) if pick is String else null
			var cur := unit.loadout.weapon_style
			detail.text = "The weapon style sets where the weapon reaches; the stance is how it hits. Find more by ending a turn on a sword an enemy drops: only the unit that does gets it.\n\nNow: %s" % (StanceRules.describe(cur.geometry, cur.stance) if cur else "none")
			if st != null:
				detail.text += "\n\nSelected: %s %s\n%s" % [StanceRules.style_name(st.geometry), StanceRules.stance_name(st.stance), StanceRules.describe(st.geometry, st.stance)]
				var same := cur != null and cur.geometry == st.geometry and cur.stance == st.stance
				apply_button.disabled = same
				apply_button.text = "Already equipped" if same else "Equip"
			return
		EquipmentLoadout.Slot.TEMP_RELIC:
			var t := unit.loadout.temp_relic
			detail.text = "The relic a summoned vessel is tethered to.\n%s\nFilled only by tethering in battle." % (t.describe() if t else "Empty between battles.")
			return
	var choice = _selected_choice()
	var current := unit.loadout.get_slot(slot) as RelicItem
	detail.text = "Now: %s\n\nSelected: %s" % [current.describe() if current else "empty", choice.describe() if choice else "empty the slot"]
	if choice == current:
		apply_button.text = "Already equipped"
		return
	var err := RosterManager.equip_error(roster, unit, slot, choice)
	apply_button.disabled = err != ""
	apply_button.text = "Equip" if err == "" else err.capitalize()
	if err == "" and choice == null:
		apply_button.text = "Unequip"


func _on_apply() -> void:
	var slot := selected_slot()
	if slot == EquipmentLoadout.Slot.WEAPON_STYLE:
		var pick = _selected_choice()
		var st := PartyRoster.style_from_key(String(pick)) if pick is String else null
		if st != null and unit.loadout != null and unit.knows_style(st.geometry, st.stance):
			var old := unit.loadout.weapon_style
			if old != null:
				unit.learn_style(old.geometry, old.stance)  # what it held stays in the collection
			unit.loadout.weapon_style = st
			changed.emit()
			refresh()
		return
	if RosterManager.equip_relic(roster, unit, slot, _selected_choice()) == "":
		changed.emit()
		refresh()


func _on_back() -> void:
	hide()
	closed.emit()


var _plate: Control
var _body: Control
var _stats: GridContainer


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


## The member's stats with what it has equipped now.
func _fill_stats() -> void:
	if _stats == null or unit == null or unit.stats == null:
		return
	for c in _stats.get_children():
		c.queue_free()
	var st := unit.stats
	var l := unit.loadout
	for pair in [["HP", StatModifier.Stat.MAX_HP], ["SP", StatModifier.Stat.MAX_SP], ["Attack", StatModifier.Stat.ATTACK], ["Defense", StatModifier.Stat.DEFENSE],
			["Magic", StatModifier.Stat.MAGIC], ["Resistance", StatModifier.Stat.RESISTANCE], ["Speed", StatModifier.Stat.SPEED], ["Will", StatModifier.Stat.WILL],
			["Move", StatModifier.Stat.MOVE], ["Jump", StatModifier.Stat.JUMP]]:
		var base := roundi(st.base_stat(pair[1]))
		var now := st.final_stat(pair[1], l)
		var row := HBoxContainer.new()
		var k := MenuKit.label(pair[0], MenuKit.SMALL + 1, MenuKit.PARCHMENT_DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var col := MenuKit.PARCHMENT if now == base else (MenuKit.HP if now > base else Color("#e07a6a"))
		row.add_child(MenuKit.label(str(now) + ("  (%+d)" % (now - base) if now != base else ""), MenuKit.BODY, col, true))
		row.custom_minimum_size.x = 190
		_stats.add_child(row)


func _build() -> void:
	var sh := MenuKit.screen(self, "Equipment")
	back_button = sh.back
	back_button.pressed.connect(_on_back)
	title = sh.title
	_plate = sh.plate
	_body = sh.body
	(sh.subtitle as Label).text = "Main Weapon, Weapon Style and two Relic Slots (the Temp-Relic fills in battle)"
	MenuKit.set_hints(sh.footer, [["↑↓", "Choose"], ["←→", "Slots · choices · equip"], ["Enter", "Equip"], ["Esc", "Back"]])
	var body: HBoxContainer = sh.body
	# three columns: the five slots and the stats | spare relics or found styles | the selection and Equip
	var left := MentorshipMenu._panel(body, 0)
	left.add_child(MentorshipMenu._section("Slots"))
	slot_list = ItemList.new()
	slot_list.custom_minimum_size.y = 250
	MenuKit.style_list(slot_list)
	slot_list.item_selected.connect(_on_slot_selected)
	left.add_child(slot_list)
	left.add_child(MentorshipMenu._section("Stats with this equipment"))
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 28)
	_stats.add_theme_constant_override("v_separation", 4)
	left.add_child(_stats)
	var mid := MentorshipMenu._panel(body, 0)
	var ch := MentorshipMenu._section("Spare relics")
	choice_heading = ch.get_child(0)  # the heading's label: it says "Found styles" for the Weapon Style slot
	mid.add_child(ch)
	choice_list = ItemList.new()
	choice_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_list.custom_minimum_size.y = 300
	MenuKit.style_list(choice_list)
	choice_list.item_selected.connect(_on_choice_selected)
	mid.add_child(choice_list)
	var right := MentorshipMenu._panel(body, 500)
	right.add_child(MentorshipMenu._section("Selected"))
	detail = MenuKit.body_text()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
	apply_button = MenuKit.action_button("Equip")
	apply_button.pressed.connect(_on_apply)
	right.add_child(apply_button)
	slot_list.focus_neighbor_right = choice_list.get_path()
	choice_list.focus_neighbor_left = slot_list.get_path()
	choice_list.focus_neighbor_right = apply_button.get_path()
