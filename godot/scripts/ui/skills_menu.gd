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
		var s: SkillData = e.skill
		var lv := ("Lv %d" % e.level) if e.level > 0 else ("%d%%" % e.progress if e.group == 1 else "—")
		list.add_item("%s   %s   (%s %s)" % [s.display_name, lv, Proficiency.display_name(s.category), SkillData.Rank.keys()[s.rank]])
		list.set_item_metadata(list.item_count - 1, e)
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
		return
	var s: SkillData = e.skill
	bar.visible = true
	bar.value = 100 if e.level >= TacticalMath.MAX_LEVEL else e.progress
	var lines: Array[String] = ["%s" % s.display_name.to_upper(), "%s  ·  rank %s  ·  %d SP" % [Proficiency.display_name(s.category), SkillData.Rank.keys()[s.rank], s.sp_cost], "",
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


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(HudStyle.backdrop())
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
	mentor_button = Button.new()
	mentor_button.text = "Mentor"
	mentor_button.custom_minimum_size = Vector2(160, 52)
	mentor_button.pressed.connect(func(): mentor_requested.emit(unit))
	head.add_child(mentor_button)
	page.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 32)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	list = ItemList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 1.2
	list.item_selected.connect(func(_i): _show_detail(_selected()))
	body.add_child(list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	bar = ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	right.add_child(bar)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
