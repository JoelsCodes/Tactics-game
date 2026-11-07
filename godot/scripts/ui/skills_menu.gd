class_name SkillsMenu
extends Control
## The skills of one unit, the same menu for Alaric, the Co-Captains and the vessels (the owner's wish, Nov 2026): every skill the unit has learned with its
## level and its bar, the skills it is working on (a vessel's practice, a human's study), the skills its relics carry now and an officer's signature skills.
## Pick one for its details: proficiency, rank, SP, power at its level, the description and where it came from. The only difference between the units: Alaric
## and the Co-Captains have a Mentor button (it opens the Mentorship window, where they study skills their vessels carry).

signal closed
signal mentor_requested(human: UnitData)

var unit: UnitData
var title: Label
var list: ItemList
var detail: Label
var bar: ProgressBar
var mentor_button: Button
var back_button: Button
var _entries: Array[Dictionary] = []


func _ready() -> void:
	_build()


func open(u: UnitData) -> void:
	unit = u
	refresh()
	show()
	MenuKit.set_plate(_plate, unit)
	MenuKit.reveal(_body, 14.0)
	list.grab_focus.call_deferred()


## Every skill line for `u`: {skill, level, progress, group, note}. Learned first (highest level first), then in progress, then carried now, then signature.
static func entries_of(u: UnitData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Array[SkillData] = []
	var tree := u.skill_tree
	var study: SkillMastery = tree.active_study() if tree != null else null
	if tree != null:
		for m in tree.masteries:
			seen.append(m.skill)
			var note := ""
			var group := 0
			if m.is_mastered():
				note = "Learned" + (" (studied from %s)" % m.mentor_name if m.mentor_name != "" else "")
			else:
				group = 1
				if m == study:
					note = "Studying now"
				elif u is VesselData:
					note = "Practising: it learns this by using it in battle"
				else:
					note = "Study paused"
			out.append({"skill": m.skill, "level": m.level, "progress": m.progress, "group": group, "note": note})
	if u.loadout != null:
		for r in u.loadout.relics():
			if r.skill != null and not seen.has(r.skill):
				seen.append(r.skill)
				out.append({"skill": r.skill, "level": 0, "progress": 0, "group": 2, "note": "On the relic %s: usable in battle, not learned yet" % r.display_name})
	if u is CoCaptainData:
		for s in (u as CoCaptainData).signature_skills:
			if not seen.has(s):
				seen.append(s)
				out.append({"skill": s, "level": 0, "progress": 0, "group": 3, "note": "Signature skill: always available"})
	out.sort_custom(func(a, b): return a.group < b.group or (a.group == b.group and a.level > b.level))
	return out


func refresh() -> void:
	if unit == null:
		return
	title.text = "Skills  ·  %s  ·  %s" % [unit.display_name, unit.role_name()]
	_entries = entries_of(unit)
	var keep = _selected()
	list.clear()
	var heads := ["LEARNED", "IN PROGRESS", "CARRIED NOW", "SIGNATURE"]
	var last := -1
	for e in _entries:
		if e.group != last:
			last = e.group
			list.add_item("— %s —" % heads[e.group])
			list.set_item_disabled(list.item_count - 1, true)
			list.set_item_selectable(list.item_count - 1, false)
			list.set_item_custom_fg_color(list.item_count - 1, MenuKit.GOLD)
		var s: SkillData = e.skill
		var lv := ("Lv %d" % e.level) if e.level > 0 else ("%d%%" % e.progress if e.group == 1 else "—")
		list.add_item("%s   %s   (%s %s)" % [s.display_name, lv, Proficiency.display_name(s.category), SkillData.Rank.keys()[s.rank]])
		list.set_item_metadata(list.item_count - 1, e)
		list.set_item_custom_fg_color(list.item_count - 1, MenuKit.rank_color(s.rank) if e.group != 2 else MenuKit.PARCHMENT_DIM)
		list.set_item_tooltip(list.item_count - 1, String(e.note))
	if _entries.is_empty():
		list.add_item("No skills yet.")
		list.set_item_disabled(0, true)
	mentor_button.visible = Mentorship.is_eligible(unit)  # the one difference: Alaric and the Co-Captains have a mentor
	_show_detail(keep)


func _selected() -> Variant:
	var sel := list.get_selected_items()
	return list.get_item_metadata(sel[0]) if sel.size() > 0 else null


func _show_detail(e: Variant) -> void:
	if e == null:
		detail.text = "Pick a skill to see what it does and how far along it is."
		bar.visible = false
		_skill_name.text = ""
		_skill_meta.text = ""
		return
	var s: SkillData = e.skill
	_skill_name.text = s.display_name
	_skill_name.add_theme_color_override("font_color", MenuKit.rank_color(s.rank))
	_skill_meta.text = String(e.note)
	bar.visible = true
	bar.value = 100 if e.level >= TacticalMath.MAX_LEVEL else e.progress
	var lines: Array[String] = ["%s  ·  rank %s  ·  %d SP" % [Proficiency.display_name(s.category), SkillData.Rank.keys()[s.rank], s.sp_cost], "",
		s.description, "", e.note]
	if e.group <= 1:
		lines.append("Level %d of %d  ·  the bar to the next level: %d / %d" % [e.level, TacticalMath.MAX_LEVEL, e.progress, TacticalMath.PROGRESS_PER_LEVEL])
		lines.append("Power at this level: x%.2f" % TacticalMath.multiplier(e.level))
		if e.level == 0:
			lines.append("Reaches level 1 by use in battle: then it is learned for good and kept in every later battle, with the progress made so far.")
	detail.text = "\n".join(lines)


func _on_back() -> void:
	hide()
	closed.emit()


var _plate: Control
var _body: Control
var _skill_name: Label
var _skill_meta: Label


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var sh := MenuKit.screen(self, "Skills")
	back_button = sh.back
	back_button.pressed.connect(_on_back)
	title = sh.title
	_plate = sh.plate
	_body = sh.body
	(sh.subtitle as Label).text = "Learned skills, skills in progress, and what the relics carry now"
	MenuKit.set_hints(sh.footer, [["↑↓", "Choose a skill"], ["Tab", "Mentor"], ["Esc", "Back"]])
	mentor_button = Button.new()
	mentor_button.text = "Mentor"
	mentor_button.custom_minimum_size = Vector2(170, 50)
	mentor_button.tooltip_text = "Study a skill one of your vessels carries"
	mentor_button.pressed.connect(func(): mentor_requested.emit(unit))
	MenuKit.liven(mentor_button)
	(sh.plate as Control).get_parent().add_child(mentor_button)
	var body: HBoxContainer = sh.body
	var left := MenuKit.column(body, "Skills", 0, 1.15)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	MenuKit.style_list(list)
	list.item_selected.connect(func(_i): _show_detail(_selected()))
	left.add_child(list)
	var right := MenuKit.column(body, "Details", 0, 1.0)
	right.add_theme_constant_override("separation", 12)
	_skill_name = MenuKit.label("", MenuKit.TITLE - 8, MenuKit.GOLD_BRIGHT, true, true)
	right.add_child(_skill_name)
	_skill_meta = MenuKit.label("", MenuKit.SMALL + 1, MenuKit.TEAL, true)
	right.add_child(_skill_meta)
	bar = ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	MentorshipMenu._style_bar(bar, MenuKit.XP)
	right.add_child(bar)
	detail = MenuKit.body_text()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
