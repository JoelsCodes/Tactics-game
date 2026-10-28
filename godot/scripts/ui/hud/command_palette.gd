class_name CommandPalette
extends PanelContainer
## Bottom center of the battle HUD: the commands for the unit whose turn it is.
##   Abilities  -> opens a wide panel with one column per group: Weapon (the free Attack), each of the
##                 six proficiencies the unit has skills in (fixed SP cost; greyed out when SP is short)
##                 and, for the King, Summon (a vessel of the active squad onto a relic).
##   Wait / End Turn
## Moving is done by clicking a blue tile. Weapon styles and loadouts are fixed in battle; there is no
## command to change them. While aiming, the palette shows a hint and Cancel.

signal action_chosen(action: BattleAction)
signal summon_chosen(vessel: VesselData)
signal end_turn_pressed
signal cancel_pressed

enum State { HIDDEN, COMMANDS, LIST, AIMING, ENEMY }

const COLUMN_WIDTH := 250

var state := State.HIDDEN
var abilities_button: Button
var end_button: Button
var back_button: Button
var cancel_button: Button
var hint: Label
var columns: HBoxContainer  ## one VBox per group
var list_buttons: Array[Button] = []  ## one per entry, in order
var list_actions: Array = []  ## BattleAction or VesselData, per entry
var _commands: HBoxContainer
var _list_panel: ScrollContainer
var _title: Label


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_title = Label.new()
	_title.theme_type_variation = &"SectionLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_list_panel = ScrollContainer.new()
	_list_panel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_panel.custom_minimum_size = Vector2(0, 300)
	col.add_child(_list_panel)
	columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	_list_panel.add_child(columns)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = 560
	col.add_child(hint)
	_commands = HBoxContainer.new()
	_commands.add_theme_constant_override("separation", 12)
	_commands.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_commands)
	abilities_button = _button("Abilities", func(): open_list())
	end_button = _button("Wait", func(): end_turn_pressed.emit())
	back_button = _button("Back", func(): _set_state(State.COMMANDS))
	cancel_button = _button("Cancel", func(): cancel_pressed.emit())
	_set_state(State.HIDDEN)


## Shows the commands for `bu`.
func show_commands(bu: BattleUnit, battle: BattleController) -> void:
	_fill_list(bu, battle)
	end_button.text = "End Turn" if battle.moved or battle.acted else "Wait"
	abilities_button.disabled = list_buttons.all(func(b): return b.disabled)
	_title.text = "%s  ·  SP %d / %d" % [bu.data.display_name, bu.sp, bu.max_sp()]
	_set_state(State.COMMANDS)


func open_list() -> void:
	_set_state(State.LIST)


func show_aiming(text: String) -> void:
	hint.text = text
	_set_state(State.AIMING)


func show_enemy_turn(bu: BattleUnit) -> void:
	_title.text = "%s's turn" % bu.data.display_name
	_set_state(State.ENEMY)


func hide_palette() -> void:
	_set_state(State.HIDDEN)


func _fill_list(bu: BattleUnit, battle: BattleController) -> void:
	for c in columns.get_children():
		c.queue_free()
	list_buttons.clear()
	list_actions.clear()
	var actions := battle.actions(bu)
	var weapon := _column("Weapon")
	_entry(weapon, actions[0], "Attack  ·  free", battle.acted)
	for cat in Proficiency.all():
		var group := actions.filter(func(a): return a.skill != null and a.skill.category == cat)
		if group.is_empty():
			continue
		var column := _column(Proficiency.display_name(cat))
		for a in group:
			var lv: int = battle.skill_level(bu, a.skill)
			var studying: bool = bu.data.skill_tree != null and bu.data.skill_tree.active_study() != null and bu.data.skill_tree.active_study().skill == a.skill
			var text := "%s  ·  %d SP%s" % [a.skill.display_name, a.sp_cost(), "  ·  studying" if studying else ("  ·  Lv %d" % lv if lv > 0 else "")]
			_entry(column, a, text, battle.acted or bu.sp < a.sp_cost())
	if bu.is_king() and not bu.is_down():
		var dm := battle.deployment
		var squad := dm.allowed_vessels if dm.limit_to_allowed else []
		var any_prop := dm.props.keys().any(func(c): return dm.in_summon_range(c) and battle.grid.can_stand(c))
		var column: VBoxContainer = null
		for v in squad:
			if dm.is_deployed(v) or dm.removed.has(v):
				continue
			if column == null:
				column = _column("Summon  ·  free")
			_entry(column, v, v.display_name, not any_prop or dm.vessel_slots_left() == 0)
	# size the panel to its columns (up to most of the screen width), so nothing hides behind a scrollbar
	var n := columns.get_child_count()
	var tallest := 0
	for c in columns.get_children():
		tallest = maxi(tallest, c.get_child_count())
	_list_panel.custom_minimum_size = Vector2(mini(n * (COLUMN_WIDTH + 14), 1080), mini(48 + (tallest - 1) * 52, 380))


func _column(title: String) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = COLUMN_WIDTH
	c.add_theme_constant_override("separation", 6)
	c.add_child(HudStyle.section(title))
	columns.add_child(c)
	return c


func _entry(column: VBoxContainer, what: Variant, text: String, disabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 46
	b.disabled = disabled
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text = text
	b.pressed.connect(_on_entry.bind(what))
	column.add_child(b)
	list_buttons.append(b)
	list_actions.append(what)


func _on_entry(what: Variant) -> void:
	if what is BattleAction:
		action_chosen.emit(what)
	elif what is VesselData:
		summon_chosen.emit(what)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 58)
	b.pressed.connect(on_press)
	_commands.add_child(b)
	return b


func _set_state(s: State) -> void:
	state = s
	visible = s != State.HIDDEN
	_list_panel.visible = s == State.LIST
	hint.visible = s == State.AIMING or s == State.ENEMY
	if s == State.ENEMY:
		hint.text = "Enemy turn"
	abilities_button.visible = s == State.COMMANDS
	end_button.visible = s == State.COMMANDS
	back_button.visible = s == State.LIST
	cancel_button.visible = s == State.AIMING
	_title.visible = s != State.AIMING
