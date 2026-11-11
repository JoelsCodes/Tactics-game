class_name MentorshipMenu
extends Control
## Mentorship sub-menu for one human (King or Co-Captain), the way the owner asked for it (Nov 2026):
##   choose a skill  ->  see every vessel that can teach it  ->  compare what studying with each is worth  ->  choose a teacher.
## The middle column lists every skill some vessel can teach, under tabs (All, then one per proficiency, like the battle menu); the right column
## shows the chosen skill and its teachers side by side: the Mentor Bond with each, the teacher's own level in the skill, and the study speed that adds up
## to, best first. The rules live in Mentorship and SkillTree; this only shows them. Built on MenuKit's sub-screen shell; Esc / B goes back, Q / E change tab.

signal closed
signal study_started(human: UnitData, skill: SkillData)

var human: UnitData
var roster: PartyRoster
var tab := -1  ## the proficiency shown (a Proficiency.Category), -1 = all
var tab_buttons := {}  ## category (or -1) -> Button
var _skills: Array[SkillData] = []  ## the skill list as shown (after the tab)
var _teachers: Array[Mentorship.Teacher] = []  ## the chosen skill's teachers, best first

var title: Label
var prof_grid: GridContainer
var study_label: Label
var study_bar: ProgressBar
var tabs: HBoxContainer
var skill_list: ItemList
var teacher_list: ItemList
var skill_title: Label  ## the chosen skill's name, in its rank's colour
var skill_label: Label  ## the chosen skill: kind, cost, the human's own state, description
var compare_label: Label  ## what the chosen teacher is worth, and against the best
var study_button: Button
var learned_label: Label
var back_button: Button
var _plate: Control
var _body: Control


func _ready() -> void:
	_build()


func open(unit: UnitData, party: PartyRoster) -> void:
	human = unit
	roster = party
	Mentorship.tree_of(human)
	tab = -1
	refresh()
	if skill_list.item_count > 0:
		skill_list.select(0)
		_on_skill_selected(0)
	show()
	MenuKit.set_plate(_plate, human)
	MenuKit.reveal(_body, 14.0)
	skill_list.grab_focus.call_deferred()


## Redraws everything from the current data, keeping the chosen skill (and teacher) where it can.
func refresh() -> void:
	if human == null:
		return
	var keep_skill := selected_skill()
	var keep_teacher := selected_vessel()
	title.text = "Mentorship  ·  %s" % human.display_name
	_fill_header()
	_fill_skills(keep_skill)
	if keep_teacher != null:
		for i in _teachers.size():
			if _teachers[i].vessel == keep_teacher:
				teacher_list.select(i)
	_show_detail()


func _fill_header() -> void:
	for c in prof_grid.get_children():
		c.queue_free()
	for cat in Proficiency.all():  # each proficiency with its rank as a coloured letter
		var row := HBoxContainer.new()
		var n := MenuKit.label(Proficiency.display_name(cat), MenuKit.BODY - 1, MenuKit.PARCHMENT)
		n.custom_minimum_size.x = 130
		row.add_child(n)
		var r := human.stats.rank_of(cat) if human.stats else 0
		var letter := TacticalMath.rank_letter(r) if human.stats else "-"
		row.add_child(MenuKit.label(letter, MenuKit.HEADING - 2, MenuKit.rank_color(5 - mini(r, 5)) if human.stats else MenuKit.PARCHMENT_DIM, true, true))
		var l := Label.new()  # (kept for anything that reads the plain text)
		l.text = "%s  %s" % [Proficiency.display_name(cat), letter]
		l.visible = false
		row.add_child(l)
		prof_grid.add_child(row)
	var tree := Mentorship.tree_of(human)
	var m := tree.active_study()
	if m == null:
		study_label.text = "Not studying anything"
		study_bar.value = 0
	else:
		study_label.text = "Studying %s from %s  ·  usable now, kept at Lv 1" % [m.skill.display_name, m.mentor_name]
		study_bar.value = m.progress
	var learned := tree.learned_skills()
	learned_label.text = "Learned: " + (", ".join(learned.map(func(s): return "%s Lv %d" % [s.display_name, tree.skill_level(s)])) if not learned.is_empty() else "none yet")


# ---------- the skills ----------

## Where a skill stands for the human, for sorting and colour: studying first, then paused, available, learned last.
func _order(s: SkillData) -> int:
	return {Mentorship.Status.STUDYING: 0, Mentorship.Status.PAUSED: 1, Mentorship.Status.AVAILABLE: 2, Mentorship.Status.LEARNED: 3}[Mentorship.status(human, s)]


func _fill_skills(keep: SkillData) -> void:
	var all := Mentorship.taught_skills(roster)
	var counts := {}
	for s in all:
		counts[s.category] = int(counts.get(s.category, 0)) + 1
	if tab >= 0 and not counts.has(tab):
		tab = -1
	_fill_tabs(all.size(), counts)
	_skills = all.filter(func(s): return tab < 0 or s.category == tab)
	_skills.sort_custom(func(a, b):
		var oa := _order(a)
		var ob := _order(b)
		if oa != ob:
			return oa < ob
		if a.category != b.category:
			return a.category < b.category
		if a.rank != b.rank:
			return a.rank > b.rank
		return a.display_name < b.display_name)
	skill_list.clear()
	for s in _skills:
		var st := Mentorship.status(human, s)
		var n := Mentorship.teachers(human, roster, s).size()
		skill_list.add_item("%s   %s  ·  %s   ·   %s   ·   %d teacher%s" % [s.display_name, SkillCollection.rank_letter(s), Proficiency.short_name(s.category), Mentorship.status_name(st), n, "" if n == 1 else "s"])
		var i := skill_list.item_count - 1
		skill_list.set_item_custom_fg_color(i, MenuKit.PARCHMENT_DIM if st == Mentorship.Status.LEARNED else (MenuKit.GOLD_BRIGHT if st == Mentorship.Status.STUDYING else MenuKit.rank_color(s.rank)))
		skill_list.set_item_tooltip(i, "%s  ·  %d SP" % [SkillCollection.kind_line(s), s.sp_cost])
	if _skills.is_empty():
		_teachers.clear()
		teacher_list.clear()
		return
	var at := maxi(_skills.find(keep), 0)
	skill_list.select(at)
	_fill_teachers()


func _fill_tabs(total: int, counts: Dictionary) -> void:
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	tab_buttons.clear()
	tabs.visible = total > 0
	_tab_button(-1, "All", total, MenuKit.GOLD)
	for cat in Proficiency.all():
		if counts.has(cat):
			_tab_button(cat, Proficiency.display_name(cat), counts[cat], SkillCollection.category_color(cat))


func _tab_button(cat: int, text: String, n: int, col: Color) -> void:
	var b := Button.new()
	b.text = "%s  %d" % [text, n]
	b.toggle_mode = true
	b.button_pressed = cat == tab
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 42)
	Typography.apply(b, Typography.Role.LABEL)
	b.add_theme_stylebox_override("normal", HudStyle.box(Color(0, 0, 0, 0.3), Color(col, 0.35), 5, 1, 12, 4))
	b.add_theme_stylebox_override("hover", HudStyle.box(Color(col, 0.18), Color(col, 0.7), 5, 1, 12, 4))
	b.add_theme_stylebox_override("pressed", HudStyle.box(Color(col, 0.3), col, 5, 2, 12, 4))
	b.add_theme_color_override("font_color", col.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", Color("#fff3d0"))
	b.add_theme_color_override("font_hover_color", Color("#fff3d0"))
	b.pressed.connect(show_tab.bind(cat))
	tabs.add_child(b)
	tab_buttons[cat] = b


## Shows one proficiency's skills (a Proficiency.Category), or all of them (-1).
func show_tab(cat: int) -> void:
	tab = cat
	_fill_skills(selected_skill())
	_show_detail()


## Q and E step through the tabs.
func step_tab(d: int) -> void:
	var order: Array = [-1]
	for cat in Proficiency.all():
		if tab_buttons.has(cat):
			order.append(cat)
	show_tab(order[posmod(order.find(tab) + d, order.size())])


func selected_skill() -> SkillData:
	var i := _selected(skill_list)
	return _skills[i] if i >= 0 and i < _skills.size() else null


## The teacher chosen on the right: the vessel (null when nothing is chosen).
func selected_vessel() -> VesselData:
	var t := selected_teacher()
	return t.vessel if t != null else null


func selected_teacher() -> Mentorship.Teacher:
	var i := _selected(teacher_list)
	return _teachers[i] if i >= 0 and i < _teachers.size() else null


func _on_skill_selected(_i: int) -> void:
	_fill_teachers()
	_show_detail()


# ---------- the teachers ----------

func _fill_teachers() -> void:
	teacher_list.clear()
	_teachers = []
	var s := selected_skill()
	if s == null:
		return
	_teachers = Mentorship.teachers(human, roster, s)
	for i in _teachers.size():
		var t := _teachers[i]
		var tag := "★ " if i == 0 and _teachers.size() > 1 and t.total > _teachers[-1].total + 0.0001 else ""
		var text := "%s%s    Bond %d  ·  Lv %d    →    %s%s" % [tag, t.vessel.display_name, t.bond, t.level, _pct(t.total), "   (teaching you)" if t.current else ""]  # the breakdown is under the list
		teacher_list.add_item(text, UnitLook.portrait(UnitLook.sheet_for(t.vessel)))
		var j := teacher_list.item_count - 1
		teacher_list.set_item_custom_fg_color(j, MenuKit.GOLD_BRIGHT if t.current else MenuKit.PARCHMENT)
		teacher_list.set_item_tooltip(j, "On %s" % t.relic.display_name if t.relic != null else "Has mastered it: taught without a relic")
	var pick := 0
	for i in _teachers.size():
		if _teachers[i].current:
			pick = i
	if not _teachers.is_empty():
		teacher_list.select(pick)


static func _pct(f: float) -> String:
	return "+%d%%" % roundi(f * 100.0)


func _on_teacher_selected(_i: int) -> void:
	_show_detail()


# ---------- the detail and the button ----------

func _show_detail() -> void:
	var s := selected_skill()
	if s == null:
		skill_title.text = ""
		skill_label.text = "No vessel carries a skill yet. A vessel learns skills by using them in battle."
		compare_label.text = ""
		study_button.disabled = true
		study_button.text = "Study"
		return
	var tree := Mentorship.tree_of(human)
	var m := tree.mastery_of(s)
	var own := "Lv %d (learned)" % m.level if m and m.is_mastered() else "Lv 0, %d / %d studied" % [m.progress if m else 0, TacticalMath.PROGRESS_PER_LEVEL]
	own += "  ·  your %s rank %s" % [Proficiency.display_name(s.category), TacticalMath.rank_letter(human.stats.rank_of(s.category)) if human.stats else "-"]
	skill_title.text = "%s   %s" % [s.display_name, SkillCollection.rank_letter(s)]
	skill_title.add_theme_color_override("font_color", SkillCollection.rank_color(s).lightened(0.25))
	skill_label.text = "%s  ·  SP %d  ·  Power %d\nYou: %s\n%s" % [SkillCollection.kind_line(s), s.sp_cost, s.base_power, own, SkillCollection.describe(s)]
	var t := selected_teacher()
	if t == null:
		compare_label.text = ""
		study_button.disabled = true
		study_button.text = "Learned" if Mentorship.status(human, s) == Mentorship.Status.LEARNED else "No teacher"
		return
	var best := _teachers[0]
	var bar: Array = tree.bond_bar(t.vessel.display_name)
	var lines: Array[String] = []
	lines.append("%s teaches it %s." % [t.vessel.display_name, "from %s" % t.relic.display_name if t.relic != null else "from its own mastery (no relic needed)"])
	lines.append("Mentor Bond Lv %d%s: %s study speed" % [t.bond, "  (%d / %d to the next)" % [bar[0], bar[1]] if int(bar[1]) > 0 else "  (max)", _pct(t.bond_bonus)])
	lines.append("Its level in the skill, %d: %s study speed (+1%% per %d levels, up to +%d%%)" % [t.level, _pct(t.teach_bonus), SkillTree.TEACH_PER, roundi(SkillTree.TEACH_CAP * 100.0)])
	lines.append("Study speed with %s: %s%s" % [t.vessel.display_name, _pct(t.total), "" if t == best or t.total >= best.total - 0.0001 else "   (%s has %s)" % [best.vessel.display_name, _pct(best.total)]])
	compare_label.text = "\n".join(lines)
	var status := Mentorship.status(human, s)
	var err := Mentorship.study_error(human, t.vessel, s)
	study_button.disabled = err != ""
	var who := t.vessel.display_name
	if err == "":
		study_button.text = ("Resume with %s" % who) if status == Mentorship.Status.PAUSED else (("Switch to %s" % who) if status == Mentorship.Status.STUDYING else ("Study with %s" % who))
	else:
		study_button.text = err.substr(0, 1).to_upper() + err.substr(1)  # sentence case: "Already studying"


func _on_study() -> void:
	var s := selected_skill()
	var v := selected_vessel()
	if s != null and v != null and Mentorship.start_study(human, v, s) != null:
		study_started.emit(human, s)
		refresh()


func _on_back() -> void:
	hide()
	closed.emit()


static func _selected(list: ItemList) -> int:
	var sel := list.get_selected_items()
	return sel[0] if sel.size() > 0 else -1


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_Q:
		step_tab(-1)
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E:
		step_tab(1)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var sh := MenuKit.screen(self, "Mentorship")
	back_button = sh.back
	back_button.pressed.connect(_on_back)
	title = sh.title
	_plate = sh.plate
	_body = sh.body
	(sh.subtitle as Label).text = "Choose a skill, see who can teach it, compare their lessons, choose a teacher"
	MenuKit.set_hints(sh.footer, [["↑↓", "Choose"], ["←→", "Change column"], ["Q E", "Change tab"], ["Enter", "Study"], ["Esc", "Back"]])
	var body: HBoxContainer = sh.body
	# three columns: the human (ranks, study, learned) | the skills, under tabs | the chosen skill, its teachers compared
	var left := _panel(body, 400)
	left.add_child(_section("Proficiency ranks"))
	prof_grid = GridContainer.new()
	prof_grid.columns = 2
	prof_grid.add_theme_constant_override("h_separation", 28)
	prof_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(prof_grid)
	left.add_child(_section("Current study"))
	study_label = MenuKit.body_text()
	left.add_child(study_label)
	study_bar = ProgressBar.new()
	study_bar.max_value = TacticalMath.PROGRESS_PER_LEVEL
	study_bar.custom_minimum_size.y = 14
	study_bar.show_percentage = false
	_style_bar(study_bar, MenuKit.XP)
	left.add_child(study_bar)
	left.add_child(_section("Learned"))
	learned_label = MenuKit.body_text()
	learned_label.add_theme_color_override("font_color", MenuKit.PARCHMENT_DIM)
	left.add_child(learned_label)

	var mid := _panel(body, 0)
	mid.add_child(_section("1  ·  Choose a skill"))
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	mid.add_child(tabs)
	skill_list = ItemList.new()
	skill_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_list.custom_minimum_size.y = 420
	MenuKit.style_list(skill_list)
	skill_list.item_selected.connect(_on_skill_selected)
	mid.add_child(skill_list)

	var right := _panel(body, 620)
	skill_title = Typography.label("", Typography.Role.HEADING, MenuKit.GOLD_BRIGHT)
	skill_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(skill_title)
	skill_label = MenuKit.body_text()
	skill_label.custom_minimum_size.y = 140
	right.add_child(skill_label)
	right.add_child(_section("2  ·  Choose a teacher"))
	teacher_list = ItemList.new()
	teacher_list.custom_minimum_size.y = 200
	teacher_list.fixed_icon_size = Vector2i(40, 40)
	MenuKit.style_list(teacher_list)
	teacher_list.item_selected.connect(_on_teacher_selected)
	teacher_list.item_activated.connect(func(_i): _on_study())
	right.add_child(teacher_list)
	compare_label = MenuKit.body_text()
	Typography.apply(compare_label, Typography.Role.BODY)
	compare_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(compare_label)
	study_button = MenuKit.action_button("Study")
	study_button.pressed.connect(_on_study)
	right.add_child(study_button)
	skill_list.focus_neighbor_right = teacher_list.get_path()
	teacher_list.focus_neighbor_left = skill_list.get_path()
	teacher_list.focus_neighbor_bottom = study_button.get_path()


## A bar in the kit's look.
static func _style_bar(b: ProgressBar, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(MenuKit.GOLD_DIM, 0.5)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)


## A framed column in `parent` (fixed `width`, or 0 to share the free space) holding a VBox. (Also used by LoadoutMenu.)
static func _panel(parent: Control, width: int) -> VBoxContainer:
	var col := MenuKit.column(parent, "", width)
	col.add_theme_constant_override("separation", 12)
	return col


static func _section(text: String) -> Control:
	return MenuKit.heading(text)
