class_name LoadoutMenu
extends Control
## Equipment sub-menu for one unit (human or vessel): the five slots, and for the two relic slots a
## choice of the spare relics in the inventory (or empty). The rules live in RosterManager. The other
## three slots are shown but fixed: the Main Weapon is bound to its unit, there are no spare Weapon
## Styles yet, and the Temp-Relic is filled only by tethering in battle. Plain default controls until
## there is a menu art reference.

signal closed
signal changed

var unit: UnitData
var roster: PartyRoster
var _choices: Array = []  ## RelicItem or null (empty), for the selected relic slot

var title: Label
var slot_list: ItemList
var choice_list: ItemList
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
			return "%s  ·  %s  ·  reach %d" % [TacticalMath.Geometry.keys()[s.geometry].capitalize(), StanceRules.stance_name(s.stance), s.reach] if s else "none"
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
			detail.text = "The weapon style sets the geometry (where it reaches) and the stance. There are no other styles to swap in yet."
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
	if RosterManager.equip_relic(roster, unit, slot, _selected_choice()) == "":
		changed.emit()
		refresh()


func _on_back() -> void:
	hide()
	closed.emit()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = HudStyle.BACKDROP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	margin.add_child(page)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(140, 52)
	back_button.pressed.connect(_on_back)
	head.add_child(back_button)
	title = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	head.add_child(title)
	page.add_child(head)

	# three columns: the five slots | spare relics | the selection and Equip
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 32)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var left := MentorshipMenu._panel(body, 0)
	left.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(MentorshipMenu._section("Slots"))
	slot_list = ItemList.new()
	slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_list.custom_minimum_size.y = 300
	slot_list.item_selected.connect(_on_slot_selected)
	left.add_child(slot_list)
	var mid := MentorshipMenu._panel(body, 0)
	mid.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(MentorshipMenu._section("Spare relics"))
	choice_list = ItemList.new()
	choice_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_list.custom_minimum_size.y = 300
	choice_list.item_selected.connect(_on_choice_selected)
	mid.add_child(choice_list)
	var right := MentorshipMenu._panel(body, 520)
	right.add_child(MentorshipMenu._section("Selected"))
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
	apply_button = Button.new()
	apply_button.custom_minimum_size.y = 60
	apply_button.pressed.connect(_on_apply)
	right.add_child(apply_button)
