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
const SKILL_LIST_WIDTH := 430  ## the ABILITIES list, with the detail pane beside it
const SKILL_LIST_HEIGHT := 300
const SKILL_ROW := 50
const DETAIL_WIDTH := 380

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
var _menu_note: Label  ## right of the title: the unit's SP and how many skills
var detail: PanelContainer  ## the pane beside the ABILITIES list
var tabs: HBoxContainer  ## ABILITIES: All, then one tab per proficiency the unit has skills in
const TAB_ALL := -1
const TAB_FAVORITES := -2  ## the starred skills: the tab exists only while the unit has any
var tab := TAB_ALL  ## the tab shown: TAB_FAVORITES, TAB_ALL or a proficiency (a Proficiency.Category)
var tab_buttons := {}  ## category (or -1) -> Button
var detail_action: BattleAction  ## the skill it shows
var detail_name: Label
var detail_rank: Label
var detail_fav: Button  ## the star in the detail pane: the same toggle as the one on the row
var detail_kind: Label
var detail_text: Label
var detail_level: Label
var detail_points: Label
var detail_bar: ProgressBar
var detail_state: Label
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


## The list panel that opens above the bar: a heading, a scrolling list with (for ABILITIES) a detail pane beside it, and Back.
func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", HudStyle.slim_panel(16, 12))
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	menu.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_menu_title = Label.new()
	_menu_title.add_theme_font_override("font", HudStyle.font(true, true))
	_menu_title.add_theme_font_size_override("font_size", 20)
	_menu_title.add_theme_color_override("font_color", Color("#e9dcc0"))
	_menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_menu_title)
	_menu_note = Label.new()
	_menu_note.add_theme_font_size_override("font_size", 15)
	_menu_note.add_theme_color_override("font_color", HudStyle.MUTED)
	head.add_child(_menu_note)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	box.add_child(tabs)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_scroll = scroll
	columns = VBoxContainer.new()
	columns.add_theme_constant_override("separation", 2)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	_build_detail(row)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(160, 44)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): _set_state(State.COMMANDS))
	box.add_child(back_button)
	_list_style = {
		"normal": HudStyle.box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.05), 4, 1, 8, 3),
		"hover": HudStyle.box(Color(HudStyle.GOLD, 0.16), Color(HudStyle.GOLD, 0.55), 4, 1, 8, 3),
		"pressed": HudStyle.box(Color(HudStyle.GOLD, 0.3), HudStyle.GOLD, 4, 1, 8, 3),
		"disabled": HudStyle.box(Color(0, 0, 0, 0.12), Color(0, 0, 0, 0), 4, 0, 8, 3),
	}


## The pane beside the skill list: the skill under the mouse (or the first one) in full: what it is, what it costs, what it does,
## and this unit's level and bar for it.
func _build_detail(row: HBoxContainer) -> void:
	detail = PanelContainer.new()
	detail.add_theme_stylebox_override("panel", HudStyle.box(Color(0.02, 0.025, 0.05, 0.6), Color(HudStyle.GOLD, 0.3), 6, 1, 16, 12))
	detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	row.add_child(detail)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	detail.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	detail_name = Label.new()
	detail_name.add_theme_font_override("font", HudStyle.font(true, true))
	detail_name.add_theme_font_size_override("font_size", 23)
	detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_name.clip_text = true
	top.add_child(detail_name)
	detail_rank = Label.new()
	detail_rank.add_theme_font_override("font", HudStyle.font(true, true))
	detail_rank.add_theme_font_size_override("font_size", 23)
	top.add_child(detail_rank)
	detail_fav = Button.new()
	detail_fav.flat = true
	detail_fav.focus_mode = Control.FOCUS_NONE
	detail_fav.add_theme_font_size_override("font_size", 26)
	detail_fav.pressed.connect(func(): toggle_favorite(detail_action.skill if detail_action != null else null))
	top.add_child(detail_fav)
	detail_kind = Label.new()
	detail_kind.add_theme_font_override("font", HudStyle.font(true))
	detail_kind.add_theme_font_size_override("font_size", 15)
	col.add_child(detail_kind)
	detail_text = Label.new()
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.add_theme_font_size_override("font_size", 16)
	detail_text.custom_minimum_size = Vector2(DETAIL_WIDTH - 32, 66)
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(detail_text)
	var rule := ColorRect.new()
	rule.color = Color(HudStyle.GOLD, 0.25)
	rule.custom_minimum_size.y = 1
	col.add_child(rule)
	var lv_row := HBoxContainer.new()
	col.add_child(lv_row)
	detail_level = Label.new()
	detail_level.add_theme_font_override("font", HudStyle.font(true))
	detail_level.add_theme_font_size_override("font_size", 17)
	detail_level.add_theme_color_override("font_color", Color("#f4e3b8"))
	detail_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv_row.add_child(detail_level)
	detail_points = Label.new()
	detail_points.add_theme_font_size_override("font_size", 15)
	detail_points.add_theme_color_override("font_color", HudStyle.MUTED)
	lv_row.add_child(detail_points)
	detail_bar = HudStyle.bar(HudStyle.XP, 12)
	detail_bar.max_value = 1.0
	col.add_child(detail_bar)
	detail_state = Label.new()
	detail_state.add_theme_font_size_override("font_size", 14)
	detail_state.add_theme_color_override("font_color", HudStyle.MUTED)
	detail_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_state.custom_minimum_size.x = DETAIL_WIDTH - 32
	col.add_child(detail_state)


## Fills the detail pane for one skill of the unit whose list is open.
func show_detail(a: BattleAction) -> void:
	detail_action = a
	if a == null or a.skill == null or _unit == null:
		return
	var s := a.skill
	var m := SkillCollection.mastery(_unit.data, s)
	detail_name.text = s.display_name
	detail_name.add_theme_color_override("font_color", Color("#f4e3b8"))
	var fav := SkillCollection.is_favorite(_unit.data, s)
	detail_fav.text = "★" if fav else "☆"
	detail_fav.tooltip_text = "Favorite: it gets a tab of its own. Click to remove it." if fav else "Add to Favorites: starred skills get a tab of their own."
	detail_fav.add_theme_color_override("font_color", Color("#ffd86a") if fav else HudStyle.MUTED)
	detail_rank.text = SkillCollection.rank_letter(s)
	detail_rank.add_theme_color_override("font_color", SkillCollection.rank_color(s).lightened(0.2))
	detail_kind.text = "%s  ·  %s" % [SkillCollection.kind_line(s), "free" if a.sp_cost() == 0 else "%d SP" % a.sp_cost()]
	detail_kind.add_theme_color_override("font_color", SkillCollection.category_color(s.category))
	detail_text.text = SkillCollection.describe(s)
	var level := m.level if m != null else 0
	detail_level.text = "Level %d" % level
	detail_bar.value = m.fill() if m != null else 0.0
	detail_points.text = "MAX" if m != null and m.is_maxed() else "%d / %d to Level %d" % [m.progress if m != null else 0, TacticalMath.PROGRESS_PER_LEVEL, level + 1]
	var why := ""
	if _battle != null and _battle.acted:
		why = "  ·  Already acted this turn"
	elif _unit.sp < a.sp_cost():
		why = "  ·  Not enough SP (%d of %d)" % [_unit.sp, a.sp_cost()]
	detail_state.text = SkillCollection.state_text(_unit.data, s) + why


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
			# [heading, action, text, disabled, cost, learning, favorite]: the headings are set when the tab's list is arranged
			out.append(["", a, a.skill.display_name + note, battle.acted or bu.sp < a.sp_cost(), "%d SP" % a.sp_cost(), SkillCollection.is_learning(bu.data, a.skill), SkillCollection.is_favorite(bu.data, a.skill)])
	return out


## The entries of the chosen tab, in order, with their headings. A skill being learned (not yet level 1) goes to the top of every list until it is
## learned: on All under a LEARNING heading, then the rest grouped by proficiency; on a proficiency tab or Favorites it simply comes first.
func _arrange(entries: Array) -> Array:
	var rest := entries
	if tab == TAB_FAVORITES:
		rest = entries.filter(func(e): return e[6])
	elif tab >= 0:
		rest = entries.filter(func(e): return (e[1] as BattleAction).skill.category == tab)
	var learning := rest.filter(func(e): return e[5])
	var others := rest.filter(func(e): return not e[5])
	var out := []
	for i in learning.size():
		var e: Array = learning[i].duplicate()
		e[0] = "Learning" if i == 0 and tab == TAB_ALL else ""
		out.append(e)
	var last_cat := -1
	for e in others:
		var c: Array = e.duplicate()
		var cat: int = (c[1] as BattleAction).skill.category
		c[0] = Proficiency.display_name(cat) if (tab == TAB_ALL and cat != last_cat) else ""
		last_cat = cat
		out.append(c)
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
	_menu_note.text = ""
	var skills := kind != "summon"
	detail.visible = skills
	_scroll.custom_minimum_size.x = SKILL_LIST_WIDTH if skills else LIST_SIZE.x
	if _unit == null:
		return
	var entries := _summon_entries(_unit, _battle) if kind == "summon" else _skill_entries(_unit, _battle)
	tabs.visible = skills and not entries.is_empty()
	if skills:
		_fill_tabs(entries)
		entries = _arrange(entries)
	var first: BattleAction = null
	for e in entries:
		if e[0] != "":  # (a proficiency's own tab and Favorites have no headings: `_arrange` leaves them empty)
			_heading(e[0], (HudStyle.GOLD if e[0] == "Learning" else SkillCollection.category_color((e[1] as BattleAction).skill.category)) if skills else HudStyle.GOLD)
		if skills:
			_skill_row(e[1], e[3], e[5], e[6])
			if first == null or (detail_action != null and (e[1] as BattleAction).skill == detail_action.skill):
				first = e[1]
		else:
			_entry(e[1], e[2], e[4], kind, e[3])
	# as tall as the entries need, up to the list's height (then it scrolls)
	var headings := entries.filter(func(e): return e[0] != "").size()
	var row_h := (SKILL_ROW + 2) if skills else 37
	_scroll.custom_minimum_size.y = clampf(entries.size() * row_h + headings * 24, 40 if not skills else 190, SKILL_LIST_HEIGHT if skills else LIST_SIZE.y)
	if skills:
		_menu_note.text = "SP %d / %d   ·   %d skill%s" % [_unit.sp, _unit.max_sp(), entries.size(), "" if entries.size() == 1 else "s"]
		detail.visible = not entries.is_empty()
		detail_action = null
		if first != null:
			show_detail(first)
	if entries.is_empty():
		var none := Label.new()
		none.text = "No skills yet" if kind == "abilities" else "No vessels to summon"
		none.theme_type_variation = &"SmallLabel"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columns.add_child(none)


## The tabs over the ABILITIES list: Favorites (only while the unit has starred skills, and first), All, and one per proficiency the unit has skills in, with how
## many. A tab that no longer has anything (the last favorite un-starred, a proficiency the unit has nothing in) falls back to All.
func _fill_tabs(entries: Array) -> void:
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	tab_buttons.clear()
	var counts := {}
	var favs := 0
	for e in entries:
		var cat: int = (e[1] as BattleAction).skill.category
		counts[cat] = int(counts.get(cat, 0)) + 1
		if e[6]:
			favs += 1
	if (tab >= 0 and not counts.has(tab)) or (tab == TAB_FAVORITES and favs == 0):
		tab = TAB_ALL
	if favs > 0:
		_tab_button(TAB_FAVORITES, "★ Favorites", favs, Color("#ffd86a"))
	_tab_button(TAB_ALL, "All", entries.size(), HudStyle.GOLD)
	for cat in Proficiency.all():
		if counts.has(cat):
			_tab_button(cat, Proficiency.display_name(cat), counts[cat], SkillCollection.category_color(cat))


func _tab_button(cat: int, text: String, n: int, col: Color) -> void:
	var b := Button.new()
	b.text = "%s  %d" % [text, n]
	b.toggle_mode = true
	b.button_pressed = cat == tab
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", HudStyle.box(Color(0, 0, 0, 0.3), Color(col, 0.35), 5, 1, 12, 4))
	b.add_theme_stylebox_override("hover", HudStyle.box(Color(col, 0.18), Color(col, 0.7), 5, 1, 12, 4))
	b.add_theme_stylebox_override("pressed", HudStyle.box(Color(col, 0.3), col, 5, 2, 12, 4))
	b.add_theme_color_override("font_color", col.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", Color("#fff3d0"))
	b.add_theme_color_override("font_hover_color", Color("#fff3d0"))
	b.pressed.connect(show_tab.bind(cat))
	tabs.add_child(b)
	tab_buttons[cat] = b


## Stars or un-stars a skill for the open unit (SkillCollection.toggle_favorite) and redraws the list on the same tab: the Favorites tab appears with the
## first star and goes away with the last.
func toggle_favorite(skill: SkillData) -> void:
	if _unit == null or skill == null:
		return
	var now := SkillCollection.toggle_favorite(_unit.data, skill)
	CombatAudio.play(self, "ui_confirm" if now else "ui_back", 1.0, -6.0)
	var keep := detail_action
	_fill_list("abilities")
	if keep != null:
		show_detail(keep)


## Shows one tab: Favorites (-2), All (-1) or a proficiency (a Proficiency.Category).
func show_tab(cat: int) -> void:
	tab = cat
	detail_action = null
	_fill_list("abilities")


func _heading(text: String, col := HudStyle.GOLD) -> void:
	var l := HudStyle.section(text)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	columns.add_child(l)


## One skill in the ABILITIES list: a stripe in its proficiency's colour, the name with its rank letter, this unit's level and
## bar for it, and the SP cost at the right. Pointing at it (or focusing it) shows it in the detail pane.
func _skill_row(a: BattleAction, disabled: bool, learning := false, favorite := false) -> void:
	var s := a.skill
	var m := SkillCollection.mastery(_unit.data, s)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, SKILL_ROW)
	for k in _list_style:
		b.add_theme_stylebox_override(k, _list_style[k])
	b.disabled = disabled
	b.clip_contents = true
	b.set_meta("skill", s)
	b.pressed.connect(_on_entry.bind(a))
	b.mouse_entered.connect(show_detail.bind(a))
	b.focus_entered.connect(show_detail.bind(a))
	var dim := 0.45 if disabled else 1.0
	var stripe := ColorRect.new()
	stripe.color = Color(SkillCollection.category_color(s.category), dim)
	stripe.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	stripe.offset_right = 4
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(stripe)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = dim
	b.add_child(row)
	var rank := Label.new()
	rank.text = SkillCollection.rank_letter(s)
	rank.add_theme_font_override("font", HudStyle.font(true, true))
	rank.add_theme_font_size_override("font_size", 20)
	rank.add_theme_color_override("font_color", SkillCollection.rank_color(s).lightened(0.2))
	rank.custom_minimum_size.x = 20
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rank)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	var name := Label.new()
	name.text = s.display_name
	name.add_theme_font_override("font", HudStyle.font(true))
	name.add_theme_font_size_override("font_size", 18)
	name.clip_text = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(name)
	var prog := HBoxContainer.new()
	prog.add_theme_constant_override("separation", 8)
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(prog)
	var lv := Label.new()
	var learned := m != null and m.is_mastered()
	lv.text = "Lv %d" % (m.level if m != null else 0)
	lv.add_theme_font_size_override("font_size", 13)
	lv.add_theme_color_override("font_color", HudStyle.XP if learned else HudStyle.MUTED)
	lv.custom_minimum_size.x = 38
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog.add_child(lv)
	var bar := HudStyle.slim_bar(HudStyle.XP if learned else Color("#7fe6ff"), 6)
	bar.max_value = 1.0
	bar.value = m.fill() if m != null else 0.0
	bar.custom_minimum_size.x = 150
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog.add_child(bar)
	var tag := Label.new()
	tag.text = "" if learned else ("NEW" if m == null else "LEARNING")
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", HudStyle.GOLD if learning else Color("#7fe6ff"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog.add_child(tag)
	var cost := Label.new()
	cost.text = "free" if a.sp_cost() == 0 else "%d SP" % a.sp_cost()
	cost.add_theme_font_override("font", HudStyle.font(true))
	cost.add_theme_font_size_override("font_size", 16)
	cost.add_theme_color_override("font_color", HudStyle.SP.lightened(0.3) if _unit.sp >= a.sp_cost() else Color("#ff8a7a"))
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := Button.new()  # the favorite toggle: a click stars or un-stars the skill without using it
	star.flat = true
	star.focus_mode = Control.FOCUS_NONE
	star.text = "★" if favorite else "☆"
	star.tooltip_text = "Remove from Favorites" if favorite else "Add to Favorites"
	star.custom_minimum_size = Vector2(34, 0)
	star.add_theme_font_size_override("font_size", 22)
	star.add_theme_color_override("font_color", Color("#ffd86a") if favorite else Color(HudStyle.MUTED, 0.8))
	star.add_theme_color_override("font_hover_color", Color("#fff3d0"))
	star.pressed.connect(toggle_favorite.bind(s))
	star.set_meta("star", true)
	row.add_child(star)
	row.add_child(cost)
	columns.add_child(b)
	list_buttons.append(b)
	list_actions.append(a)


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
	# the owner's icons are detailed framed tiles: they fill most of the slot; the generated glyphs stay small
	var big := HudStyle.custom_icon(icon_name)
	b.add_theme_constant_override("icon_max_width", (120 if size == ATTACK else 96) if big else (60 if size == ATTACK else 50))
	if HudStyle.labeled_icon(icon_name):  # the icon has its own text: it is the whole button face
		b.tooltip_text = b.text.capitalize()
		b.text = ""
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", int(size.x) - 10)
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
