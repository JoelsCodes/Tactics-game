class_name CommandPalette
extends VBoxContainer
## Bottom center of the battle HUD: a title plaque (the acting unit and its SP) over a sleek panel with
## the commands for the unit whose turn it is, laid out left to right:
##   ATTACK     a large gold-framed button: aim the free weapon attack on the board
##   ABILITIES  an always-open list: the unit's skills grouped by proficiency with their fixed SP cost
##              (greyed out when SP is short or the unit has acted) and, for the King, Summon (any
##              vessel he owns, onto a relic, while the map's summon limit has summons left)
##   ITEMS      greyed out: there are no consumable items yet
##   DEFEND     guard (half damage) until the unit's next turn; ends the turn
##   WAIT       ends the turn ("End Turn" once the unit has moved or acted)
##   MOVE       shows the walkable tiles again (they glow at the start of a turn anyway)
## Weapon styles and loadouts are fixed in battle; there is no command to change them. While aiming,
## the panel shows a hint and Cancel.

signal action_chosen(action: BattleAction)
signal summon_chosen(vessel: VesselData)
signal end_turn_pressed
signal cancel_pressed
signal defend_pressed
signal move_pressed

enum State { HIDDEN, COMMANDS, AIMING, ENEMY }

const SLOT := Vector2(104, 150)  ## ITEMS / DEFEND / WAIT / MOVE at 1080p
const ATTACK := Vector2(132, 172)
const LIST_SIZE := Vector2(268, 150)

var state := State.HIDDEN
var attack_button: Button
var items_button: Button
var defend_button: Button
var end_button: Button  ## WAIT / End Turn
var move_button: Button
var cancel_button: Button
var hint: Label
var title: Label  ## on the plaque
var columns: VBoxContainer  ## the ABILITIES list: group headings (Label) and entries (Button)
var list_buttons: Array[Button] = []  ## one per entry, in order
var list_actions: Array = []  ## BattleAction or VesselData, per entry
var body: PanelContainer
var _commands: HBoxContainer
var _aim_row: HBoxContainer
var _plaque: PanelContainer
var _list_style := {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", -6)
	_plaque = HudStyle.plaque("")
	title = _plaque.get_node("Text")
	add_child(_plaque)
	body = PanelContainer.new()
	body.add_theme_stylebox_override("panel", HudStyle.slim_panel(16, 14))
	add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	body.add_child(col)
	_commands = HBoxContainer.new()
	_commands.add_theme_constant_override("separation", 10)
	col.add_child(_commands)
	attack_button = _slot("Attack", "attack", ATTACK, func(): action_chosen.emit(BattleAction.attack()))
	for st in ["normal", "hover"]:
		attack_button.add_theme_stylebox_override(st, HudStyle.slot_box("primary" if st == "normal" else "hover"))
	attack_button.add_theme_font_size_override("font_size", 22)
	_commands.add_child(_ability_list())
	items_button = _slot("Items", "items", SLOT, func(): pass)
	items_button.disabled = true
	items_button.tooltip_text = "No items yet"
	defend_button = _slot("Defend", "defend", SLOT, func(): defend_pressed.emit())
	defend_button.tooltip_text = "Guard until your next turn: half damage. Ends the turn."
	end_button = _slot("Wait", "wait", SLOT, func(): end_turn_pressed.emit())
	move_button = _slot("Move", "move", SLOT, func(): move_pressed.emit())
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = 600
	col.add_child(hint)
	_aim_row = HBoxContainer.new()
	_aim_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_aim_row)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(200, 52)
	cancel_button.pressed.connect(func(): cancel_pressed.emit())
	_aim_row.add_child(cancel_button)
	_set_state(State.HIDDEN)


## Shows the commands for `bu`.
func show_commands(bu: BattleUnit, battle: BattleController) -> void:
	_fill_list(bu, battle)
	end_button.text = "END TURN" if battle.moved or battle.acted else "WAIT"
	attack_button.disabled = battle.acted
	defend_button.disabled = battle.acted
	move_button.disabled = battle.moved
	title.text = "%s  ·  SP %d / %d" % [bu.data.display_name, bu.sp, bu.max_sp()]
	_set_state(State.COMMANDS)


func show_aiming(text: String) -> void:
	hint.text = text
	_set_state(State.AIMING)


func show_enemy_turn(bu: BattleUnit) -> void:
	title.text = "%s's turn" % bu.data.display_name
	hint.text = "Enemy turn"
	_set_state(State.ENEMY)


func hide_palette() -> void:
	_set_state(State.HIDDEN)


## The ABILITIES column: a heading and a scrolling list.
func _ability_list() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := Label.new()
	head.text = "ABILITIES"
	head.add_theme_font_override("font", HudStyle.font(true, true))
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color("#e9dcc0"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HudStyle.box(Color(0, 0, 0, 0.32), Color(HudStyle.GOLD, 0.22), 4, 1, 4, 4))
	box.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	columns = VBoxContainer.new()
	columns.add_theme_constant_override("separation", 1)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	_list_style = {
		"normal": HudStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3, 0, 8, 3),
		"hover": HudStyle.box(Color(HudStyle.GOLD, 0.16), Color(HudStyle.GOLD, 0.45), 3, 1, 8, 3),
		"pressed": HudStyle.box(Color(HudStyle.GOLD, 0.3), HudStyle.GOLD, 3, 1, 8, 3),
		"disabled": HudStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3, 0, 8, 3),
	}
	return box


func _fill_list(bu: BattleUnit, battle: BattleController) -> void:
	for c in columns.get_children():
		columns.remove_child(c)
		c.queue_free()
	list_buttons.clear()
	list_actions.clear()
	var actions := battle.actions(bu)
	for cat in Proficiency.all():
		var group := actions.filter(func(a): return a.skill != null and a.skill.category == cat)
		if group.is_empty():
			continue
		_heading(Proficiency.display_name(cat))
		for a in group:
			var lv: int = battle.skill_level(bu, a.skill)
			var studying: bool = bu.data.skill_tree != null and bu.data.skill_tree.active_study() != null and bu.data.skill_tree.active_study().skill == a.skill
			var note := "  (studying)" if studying else ("  Lv %d" % lv if lv > 0 else "")
			_entry(a, "%s%s" % [a.skill.display_name, note], "%d SP" % a.sp_cost(), "abilities", battle.acted or bu.sp < a.sp_cost())
	if bu.is_king() and not bu.is_down():
		var dm := battle.deployment
		var any_prop := dm.props.keys().any(func(c): return dm.in_summon_range(c) and battle.grid.can_stand(c))
		var headed := false
		for v in dm.owned_vessels:
			if dm.is_deployed(v) or dm.removed.has(v):
				continue
			if not headed:
				_heading("Summon  ·  free  ·  %d left" % dm.summons_left())
				headed = true
			_entry(v, v.display_name, "", "abilities", not any_prop or dm.summons_left() == 0)
	if list_buttons.is_empty():
		var none := Label.new()
		none.text = "No skills yet"
		none.theme_type_variation = &"SmallLabel"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columns.add_child(none)


func _heading(text: String) -> void:
	var l := HudStyle.section(text)
	l.add_theme_font_size_override("font_size", 13)
	columns.add_child(l)


## One list entry: icon, name, and the SP cost at the right.
func _entry(what: Variant, text: String, cost: String, icon_name: String, disabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.icon = load(HudStyle.UI_DIR + "icon_%s.png" % icon_name)
	b.add_theme_constant_override("icon_max_width", 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 32
	b.add_theme_font_size_override("font_size", 18)
	for k in _list_style:
		b.add_theme_stylebox_override(k, _list_style[k])
	b.add_theme_color_override("icon_normal_color", Color(HudStyle.GOLD, 0.85))
	b.add_theme_color_override("icon_disabled_color", Color(HudStyle.GOLD, 0.25))
	b.disabled = disabled
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text = text + ("  ·  " + cost if cost != "" else "")
	b.pressed.connect(_on_entry.bind(what))
	if cost != "":
		var c := Label.new()
		c.text = cost
		c.add_theme_font_size_override("font_size", 15)
		c.add_theme_color_override("font_color", HudStyle.SP.lightened(0.3) if not disabled else Color(HudStyle.MUTED, 0.5))
		c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		c.offset_left = -64
		c.offset_right = -8
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
	columns.add_child(b)
	list_buttons.append(b)
	list_actions.append(what)


func _on_entry(what: Variant) -> void:
	if what is BattleAction:
		action_chosen.emit(what)
	elif what is VesselData:
		summon_chosen.emit(what)


## A command slot: gold icon over a small-caps label.
func _slot(text: String, icon_name: String, size: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.icon = load(HudStyle.UI_DIR + "icon_%s.png" % icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = size
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.add_theme_font_override("font", HudStyle.font(true, true))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_constant_override("h_separation", 6)
	b.add_theme_constant_override("icon_max_width", 56 if size == ATTACK else 46)
	for k in ["icon_normal_color", "icon_focus_color"]:
		b.add_theme_color_override(k, Color("#efe2c4"))
	b.add_theme_color_override("icon_hover_color", Color("#fff3d0"))
	b.add_theme_color_override("icon_pressed_color", HudStyle.INK)
	b.add_theme_color_override("icon_disabled_color", Color(HudStyle.GOLD, 0.22))
	b.pressed.connect(on_press)
	_commands.add_child(b)
	return b


func _set_state(s: State) -> void:
	state = s
	visible = s != State.HIDDEN
	_commands.visible = s == State.COMMANDS
	hint.visible = s == State.AIMING or s == State.ENEMY
	_aim_row.visible = s == State.AIMING
	cancel_button.visible = s == State.AIMING
	_plaque.visible = s != State.AIMING
