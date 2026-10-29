class_name CommandPalette
extends VBoxContainer
## Bottom center of the battle HUD: a title plaque (the acting unit and its SP) over a sleek panel with
## the commands for the unit whose turn it is, laid out left to right:
##   ATTACK     a large gold-framed button: aim the free weapon attack on the board
##   ABILITIES  opens a list above the bar: the unit's skills grouped by proficiency with their fixed SP
##              cost (greyed out when SP is short or the unit has acted)
##   ITEMS      greyed out: there are no consumable items yet
##   DEFEND     guard (half damage) until the unit's next turn; ends the turn
##   SUMMON     the King has this in DEFEND's place: opens a list of the vessels he owns (onto a relic,
##              while the map's summon limit has summons left; free)
##   WAIT       ends the turn ("End Turn" once the unit has moved or acted)
##   MOVE       shows the walkable tiles again (they glow at the start of a turn anyway)
## Icons come from HudStyle.icon (the owner's own PNGs in assets/ui/icons/ win over the generated ones).
## Weapon styles and loadouts are fixed in battle; there is no command to change them. While aiming,
## the panel shows a hint and Cancel.

signal action_chosen(action: BattleAction)
signal summon_chosen(vessel: VesselData)
signal end_turn_pressed
signal cancel_pressed
signal defend_pressed
signal move_pressed

enum State { HIDDEN, COMMANDS, LIST, AIMING, ENEMY }

const SLOT := Vector2(112, 150)  ## the small command slots at 1080p
const ATTACK := Vector2(136, 172)
const LIST_SIZE := Vector2(380, 230)

var state := State.HIDDEN
var list_kind := ""  ## "abilities" or "summon" while a list is open
var attack_button: Button
var abilities_button: Button
var items_button: Button
var defend_button: Button
var summon_button: Button  ## the King's, in DEFEND's place
var end_button: Button  ## WAIT / End Turn
var move_button: Button
var back_button: Button
var cancel_button: Button
var hint: Label
var title: Label  ## on the plaque
var columns: VBoxContainer  ## the open list: group headings (Label) and entries (Button)
var list_buttons: Array[Button] = []  ## one per entry, in order
var list_actions: Array = []  ## BattleAction or VesselData, per entry
var body: PanelContainer
var menu: PanelContainer  ## the list panel above the bar
var _menu_title: Label
var _scroll: ScrollContainer
var _commands: HBoxContainer
var _aim_row: HBoxContainer
var _plaque: PanelContainer
var _list_style := {}
var _unit: BattleUnit
var _battle: BattleController


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", -6)
	_build_menu()
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
	attack_button.add_theme_stylebox_override("normal", HudStyle.slot_box("primary"))
	attack_button.add_theme_font_size_override("font_size", 22)
	abilities_button = _slot("Abilities", "abilities", SLOT, func(): open_list("abilities"))
	items_button = _slot("Items", "items", SLOT, func(): pass)
	items_button.disabled = true
	items_button.tooltip_text = "No items yet"
	defend_button = _slot("Defend", "defend", SLOT, func(): defend_pressed.emit())
	defend_button.tooltip_text = "Guard until your next turn: half damage. Ends the turn."
	summon_button = _slot("Summon", "summon", SLOT, func(): open_list("summon"))
	summon_button.tooltip_text = "Summon a vessel onto a relic in range. Free."
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
	_unit = bu
	_battle = battle
	var king := bu.is_king()
	defend_button.visible = not king
	summon_button.visible = king
	end_button.text = "END TURN" if battle.moved or battle.acted else "WAIT"
	attack_button.disabled = battle.acted
	defend_button.disabled = battle.acted
	move_button.disabled = battle.moved
	abilities_button.disabled = not _skill_entries(bu, battle).any(func(e): return not e[3])
	summon_button.disabled = not king or not _summon_entries(bu, battle).any(func(e): return not e[3])
	title.text = "%s  ·  SP %d / %d" % [bu.data.display_name, bu.sp, bu.max_sp()]
	_set_state(State.COMMANDS)


## Opens the list for "abilities" or "summon" above the bar, with a short grow-and-fade.
func open_list(kind := "abilities") -> void:
	list_kind = kind
	_fill_list(kind)
	_set_state(State.LIST)
	if is_inside_tree():
		menu.modulate.a = 0.0
		menu.scale = Vector2(1, 0.85)
		menu.pivot_offset = Vector2(menu.size.x / 2.0, menu.size.y)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(menu, "modulate:a", 1.0, 0.16)
		tw.tween_property(menu, "scale", Vector2.ONE, 0.18)


func show_aiming(text: String) -> void:
	hint.text = text
	_set_state(State.AIMING)


func show_enemy_turn(bu: BattleUnit) -> void:
	title.text = "%s's turn" % bu.data.display_name
	hint.text = "Enemy turn"
	_set_state(State.ENEMY)


func hide_palette() -> void:
	_set_state(State.HIDDEN)


## The list panel that opens above the bar: a heading, a scrolling list and Back.
func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", HudStyle.slim_panel(14, 12))
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	menu.add_child(box)
	_menu_title = Label.new()
	_menu_title.add_theme_font_override("font", HudStyle.font(true, true))
	_menu_title.add_theme_font_size_override("font_size", 18)
	_menu_title.add_theme_color_override("font_color", Color("#e9dcc0"))
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_menu_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_scroll = scroll
	columns = VBoxContainer.new()
	columns.add_theme_constant_override("separation", 1)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(160, 44)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): _set_state(State.COMMANDS))
	box.add_child(back_button)
	_list_style = {
		"normal": HudStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3, 0, 8, 3),
		"hover": HudStyle.box(Color(HudStyle.GOLD, 0.16), Color(HudStyle.GOLD, 0.45), 3, 1, 8, 3),
		"pressed": HudStyle.box(Color(HudStyle.GOLD, 0.3), HudStyle.GOLD, 3, 1, 8, 3),
		"disabled": HudStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3, 0, 8, 3),
	}


## [heading, what, text, disabled, cost] per skill, grouped by proficiency (heading set on the first).
func _skill_entries(bu: BattleUnit, battle: BattleController) -> Array:
	var out := []
	for cat in Proficiency.all():
		var group := battle.actions(bu).filter(func(a): return a.skill != null and a.skill.category == cat)
		for i in group.size():
			var a: BattleAction = group[i]
			var lv: int = battle.skill_level(bu, a.skill)
			var studying: bool = bu.data.skill_tree != null and bu.data.skill_tree.active_study() != null and bu.data.skill_tree.active_study().skill == a.skill
			var note := "  (studying)" if studying else ("  Lv %d" % lv if lv > 0 else "")
			out.append([Proficiency.display_name(cat) if i == 0 else "", a, a.skill.display_name + note, battle.acted or bu.sp < a.sp_cost(), "%d SP" % a.sp_cost()])
	return out


## The King's summon entries: every owned vessel not already out (or removed this battle).
func _summon_entries(bu: BattleUnit, battle: BattleController) -> Array:
	var out := []
	if not bu.is_king() or bu.is_down():
		return out
	var dm := battle.deployment
	var any_prop := dm.props.keys().any(func(c): return dm.in_summon_range(c) and battle.grid.can_stand(c))
	for v in dm.owned_vessels:
		if dm.is_deployed(v) or dm.removed.has(v):
			continue
		out.append(["Free  ·  %d left this battle" % dm.summons_left() if out.is_empty() else "", v, v.display_name, not any_prop or dm.summons_left() == 0, ""])
	return out


func _fill_list(kind: String) -> void:
	for c in columns.get_children():
		columns.remove_child(c)
		c.queue_free()
	list_buttons.clear()
	list_actions.clear()
	_menu_title.text = kind.to_upper()
	if _unit == null:
		return
	var entries := _summon_entries(_unit, _battle) if kind == "summon" else _skill_entries(_unit, _battle)
	for e in entries:
		if e[0] != "":
			_heading(e[0])
		_entry(e[1], e[2], e[4], kind, e[3])
	# as tall as the entries need, up to LIST_SIZE (then it scrolls)
	var headings := entries.filter(func(e): return e[0] != "").size()
	_scroll.custom_minimum_size.y = clampf(entries.size() * 37 + headings * 22, 40, LIST_SIZE.y)
	if entries.is_empty():
		var none := Label.new()
		none.text = "No skills yet" if kind == "abilities" else "No vessels to summon"
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
	b.icon = HudStyle.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 36
	b.add_theme_font_size_override("font_size", 18)
	for k in _list_style:
		b.add_theme_stylebox_override(k, _list_style[k])
	_icon_colors(b, icon_name, 0.85)
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


## A command slot: icon over a small-caps label.
func _slot(text: String, icon_name: String, size: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.icon = HudStyle.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = size
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.add_theme_font_override("font", HudStyle.font(true, true))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_constant_override("h_separation", 6)
	b.add_theme_constant_override("icon_max_width", 60 if size == ATTACK else 50)
	_icon_colors(b, icon_name, 1.0)
	b.pressed.connect(on_press)
	_commands.add_child(b)
	return b


## Generated icons are white and tinted here; the owner's own icons keep their colors (dimmed when off).
func _icon_colors(b: Button, icon_name: String, strength: float) -> void:
	var custom := HudStyle.custom_icon(icon_name)
	var base := Color.WHITE if custom else Color("#efe2c4") if strength >= 1.0 else Color(HudStyle.GOLD, strength)
	for k in ["icon_normal_color", "icon_focus_color"]:
		b.add_theme_color_override(k, base)
	b.add_theme_color_override("icon_hover_color", Color.WHITE if custom else Color("#fff3d0"))
	b.add_theme_color_override("icon_pressed_color", Color(0.8, 0.8, 0.8) if custom else HudStyle.INK)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3) if custom else Color(HudStyle.GOLD, 0.22))


func _set_state(s: State) -> void:
	state = s
	visible = s != State.HIDDEN
	menu.visible = s == State.LIST
	_commands.visible = s == State.COMMANDS or s == State.LIST
	hint.visible = s == State.AIMING or s == State.ENEMY
	_aim_row.visible = s == State.AIMING
	cancel_button.visible = s == State.AIMING
	_plaque.visible = s != State.AIMING
