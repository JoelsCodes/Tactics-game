class_name SkillFeed
extends Control
## Skill training made visible during the battle:
##
##   progress   after a unit uses a skill it is learning or levelling, a small strip above the acting unit's card shows the skill,
##              its level and its bar filling from where it was to where it is now (rolling over on a level up)
##   mastered   when a skill reaches level 1 (a vessel learned it by use, or a human finished studying it), a card drops in at the
##              top of the screen: SKILL MASTERED, the skill, its proficiency and rank, and what that opens (a vessel's skill can
##              now be studied by Alaric and the Co-Captains; a human's is theirs for good)
##   bond       a line under the card when studying raised a Mentor Bond
##
## Presentation only: it never blocks input and changes nothing.

const STRIP_WIDTH := 400
const CARD_WIDTH := 620

var strip: PanelContainer
var card: PanelContainer
var last_progress := {}  ## what the strip showed last: {who, skill, before, after} (tests read it)
var anchor: Control  ## the acting unit's card: the strip sits just above it, however tall it is
var last_mastered := {}  ## what the card showed last: {who, skill, note}
var _strip_name: Label
var _strip_level: Label
var _strip_gain: Label
var _strip_bar: ProgressBar
var _card_title: Label
var _card_name: Label
var _card_kind: Label
var _card_note: Label
var _strip_tween: Tween
var _card_tween: Tween
var _queue: Array[Dictionary] = []  ## mastery cards waiting their turn
var _card_busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_strip()
	_build_card()


func _build_strip() -> void:
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", HudStyle.box(Color(0.03, 0.035, 0.07, 0.88), Color(HudStyle.GOLD, 0.5), 6, 1, 14, 8))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.offset_right = -24
	strip.offset_left = -24 - STRIP_WIDTH
	strip.offset_bottom = -(24 + BattleHud.CARD_HEIGHT + 14)
	strip.visible = false
	add_child(strip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_strip_name = Label.new()
	_strip_name.add_theme_font_override("font", HudStyle.font(true))
	_strip_name.add_theme_font_size_override("font_size", 17)
	_strip_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip_name.clip_text = true
	row.add_child(_strip_name)
	_strip_gain = Label.new()
	_strip_gain.add_theme_font_override("font", HudStyle.font(true))
	_strip_gain.add_theme_font_size_override("font_size", 16)
	_strip_gain.add_theme_color_override("font_color", Color("#7fe6ff"))
	row.add_child(_strip_gain)
	_strip_level = Label.new()
	_strip_level.add_theme_font_override("font", HudStyle.font(true))
	_strip_level.add_theme_font_size_override("font_size", 16)
	_strip_level.add_theme_color_override("font_color", HudStyle.XP)
	row.add_child(_strip_level)
	_strip_bar = HudStyle.bar(HudStyle.XP, 12)
	_strip_bar.max_value = 1.0
	col.add_child(_strip_bar)


func _build_card() -> void:
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", HudStyle.box(Color(0.05, 0.045, 0.02, 0.93), HudStyle.GOLD, 8, 2, 28, 14))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = 232
	card.custom_minimum_size.x = CARD_WIDTH
	card.visible = false
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	_card_title = Label.new()
	_card_title.text = "SKILL MASTERED"
	_card_title.add_theme_font_override("font", HudStyle.font(true, true))
	_card_title.add_theme_font_size_override("font_size", 18)
	_card_title.add_theme_color_override("font_color", HudStyle.GOLD)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_title)
	_card_name = Label.new()
	_card_name.add_theme_font_override("font", HudStyle.font(true, true))
	_card_name.add_theme_font_size_override("font_size", 40)
	_card_name.add_theme_color_override("font_color", Color("#fff3d0"))
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_name)
	_card_kind = Label.new()
	_card_kind.add_theme_font_override("font", HudStyle.font(true))
	_card_kind.add_theme_font_size_override("font_size", 18)
	_card_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_kind)
	_card_note = Label.new()
	_card_note.add_theme_font_size_override("font_size", 17)
	_card_note.add_theme_color_override("font_color", Color("#e8e2d0"))
	_card_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_note.custom_minimum_size.x = CARD_WIDTH - 56
	col.add_child(_card_note)


## The strip: `who` used `skill`; its level and bar went from `before` to `after` ([level, points]).
func progress(who: String, skill: SkillData, before: Array, after: Array, animate := true) -> void:
	last_progress = {"who": who, "skill": skill, "before": before, "after": after}
	var gained := (int(after[0]) - int(before[0])) * TacticalMath.PROGRESS_PER_LEVEL + int(after[1]) - int(before[1])
	_strip_name.text = "%s  ·  %s" % [who, skill.display_name]
	_strip_name.add_theme_color_override("font_color", SkillCollection.rank_color(skill).lightened(0.3))
	_strip_gain.text = "+%d" % gained
	_strip_level.text = "Lv %d" % int(after[0])
	var to := float(after[1]) / TacticalMath.PROGRESS_PER_LEVEL
	if int(after[0]) >= TacticalMath.MAX_LEVEL:
		to = 1.0
	if anchor != null and anchor.visible:
		strip.offset_bottom = -(24 + anchor.size.y + 22)
	strip.visible = true
	if _strip_tween:
		_strip_tween.kill()
	if not animate or not is_inside_tree():
		_strip_bar.value = to
		strip.modulate.a = 1.0
		return
	var from := float(before[1]) / TacticalMath.PROGRESS_PER_LEVEL
	_strip_bar.value = from
	_strip_level.text = "Lv %d" % int(before[0])
	strip.modulate.a = 1.0
	_strip_tween = create_tween()
	if int(after[0]) > int(before[0]):  # the bar fills, the level turns over, the rest fills
		_strip_tween.tween_property(_strip_bar, "value", 1.0, 0.3)
		_strip_tween.tween_callback(func():
			_strip_level.text = "Lv %d" % int(after[0])
			_strip_bar.value = 0.0
			strip.modulate = Color(2.0, 1.8, 1.3))
		_strip_tween.tween_property(strip, "modulate", Color.WHITE, 0.25)
		_strip_tween.parallel().tween_property(_strip_bar, "value", to, 0.25)
	else:
		_strip_tween.tween_property(_strip_bar, "value", to, 0.45).set_ease(Tween.EASE_OUT)
	_strip_tween.tween_interval(1.6)
	_strip_tween.tween_property(strip, "modulate:a", 0.0, 0.4)
	_strip_tween.tween_callback(strip.hide)


## The card: `who` took `skill` to level 1. `note` says what that opens; `bond` is an extra line ("" for none).
func mastered(who: String, skill: SkillData, note: String, bond := "", animate := true) -> void:
	last_mastered = {"who": who, "skill": skill, "note": note, "bond": bond}
	if not animate or not is_inside_tree():
		_fill_card(last_mastered)
		card.visible = true
		card.modulate.a = 1.0
		return
	_queue.append(last_mastered)
	if not _card_busy:
		_next_card()


func _fill_card(e: Dictionary) -> void:
	var skill: SkillData = e.skill
	_card_title.text = "SKILL MASTERED  ·  %s" % String(e.who).to_upper()
	_card_name.text = skill.display_name
	_card_kind.text = "%s  ·  Level 1" % SkillCollection.kind_line(skill)
	_card_kind.add_theme_color_override("font_color", SkillCollection.category_color(skill.category))
	_card_note.text = String(e.note) + ("\n" + String(e.bond) if String(e.bond) != "" else "")


func _next_card() -> void:
	if _queue.is_empty():
		_card_busy = false
		return
	_card_busy = true
	_fill_card(_queue.pop_front())
	card.visible = true
	card.modulate.a = 0.0
	card.pivot_offset = Vector2(CARD_WIDTH / 2.0, 60)
	card.scale = Vector2(1.25, 1.25)
	_card_tween = create_tween()
	_card_tween.tween_property(card, "modulate:a", 1.0, 0.12)
	_card_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_card_tween.tween_interval(2.8)
	_card_tween.tween_property(card, "modulate:a", 0.0, 0.35)
	_card_tween.tween_callback(func():
		card.hide()
		_next_card())

