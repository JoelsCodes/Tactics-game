class_name SummonPicker
extends PanelContainer
## The stone-first summon card (owner, Nov 2026): click a stone on the King's turn and one card opens beside it with the stone's facts and a thin
## bar per vessel (a strip of the portrait across the eyes, the name, what the stone means for it), best first (SummonRanking). Click a bar to
## summon, Up / Down and Enter to choose with the keyboard (Enter alone takes the best), Esc to close. It only shows things and says what was
## chosen (`chosen`); BattleStage asks the rules to summon.

signal chosen(vessel: VesselData)
signal dismissed

const WIDTH := 640.0
const BAR := Vector2(600.0, 44.0)
const STRIP := 330.0  ## the width of the eye strip inside a bar
const BG := Color(0.07, 0.06, 0.09, 0.94)
const DIM := Color(0.42, 0.36, 0.26, 0.9)

var cell := TacticalGrid.NO_CELL
var rows: Array[Dictionary] = []
var selected := 0

var _name: Label
var _chips: HBoxContainer
var _what: Label
var _list: VBoxContainer
var _hint: Label
var _bars: Array[PanelContainer] = []


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", HudStyle.slim_panel(18, 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_name = Label.new()
	Typography.apply(_name, Typography.Role.SUBHEADING, Color("#f4ead2"))
	col.add_child(_name)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	col.add_child(_chips)
	_what = Label.new()
	Typography.apply(_what, Typography.Role.BODY, Color("#e6dcc3"))
	_what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_what.custom_minimum_size.x = BAR.x
	col.add_child(_what)
	col.add_child(HudStyle.divider())
	var title := Label.new()
	title.text = "WHO RECEIVES IT"
	Typography.apply(title, Typography.Role.CAPTION, HudStyle.GOLD)
	col.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	col.add_child(_list)
	_hint = Label.new()
	Typography.apply(_hint, Typography.Role.CAPTION, Color("#cfc3a6"))
	col.add_child(_hint)


## Opens the card for the stone on `at`: its facts, then one bar per vessel from `entries`.
func open(at: Vector2i, relic: RelicItem, entries: Array[Dictionary], game: SaveGame) -> void:
	cell = at
	rows = entries
	var sk := relic.skill
	_name.text = sk.display_name if sk != null else "Stone"
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	if sk != null:
		_chip("Rank %s" % SkillCollection.rank_letter(sk), SkillCollection.rank_color(sk))
		_chip(Proficiency.display_name(sk.category), SkillCollection.category_color(sk.category))
		_chip("New to the party" if SkillCollection.is_new(game, sk) else "Known", HudStyle.GOLD if SkillCollection.is_new(game, sk) else Color("#9aa6c4"))
		_chip({"reach": "Reach stone", "field": "Field stone", "prize": "Prize stone"}.get(StonePlacement.kind_of(relic), "Stone"), Color("#cfc3a6"))
		var parts: Array[String] = ["%d SP" % sk.sp_cost]
		if sk.is_physical():
			var b := sk.band()
			parts.append("%.2f to %.2f x Attack" % [float(b[0]), float(b[1])])
		elif sk.base_power > 0:
			parts.append("Power %d" % sk.base_power)
		_what.text = "%s\n%s" % [SkillCollection.describe(sk), "  ·  ".join(parts)]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_bars.clear()
	selected = 0
	for i in rows.size():
		var bar := _bar(rows[i], i)
		_list.add_child(bar)
		_bars.append(bar)
	for i in rows.size():  # the keyboard starts on the best one
		if rows[i].available:
			selected = i
			break
	_hint.text = "Click a vessel to summon it, or press Enter for the best one  ·  Esc closes" if rows.any(func(r): return r.available) else "Nothing can be summoned onto this stone now  ·  Esc closes"
	_paint()
	visible = true
	reset_size()


func close() -> void:
	if visible:
		visible = false
		dismissed.emit()


## Moves the keyboard choice to the next vessel that can be summoned (`step` +1 or -1).
func move(step: int) -> void:
	var n := rows.size()
	for k in range(1, n + 1):
		var i := posmod(selected + step * k, n)
		if rows[i].available:
			selected = i
			break
	_paint()


## Summons the keyboard choice (the best vessel until the arrows move it). Returns false when nothing can be summoned.
func confirm() -> bool:
	if selected < 0 or selected >= rows.size() or not rows[selected].available:
		return false
	chosen.emit(rows[selected].vessel)
	return true


func _chip(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	Typography.apply(l, Typography.Role.CAPTION, color)
	_chips.add_child(l)


func _bar(r: Dictionary, i: int) -> PanelContainer:
	var v: VesselData = r.vessel
	var bar := PanelContainer.new()
	bar.custom_minimum_size = BAR
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if r.available else Control.CURSOR_ARROW
	var stack := Control.new()
	stack.custom_minimum_size = BAR - Vector2(4, 4)
	stack.clip_contents = true
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(stack)
	var pic := TextureRect.new()
	pic.texture = UnitLook.eye_strip(UnitLook.sheet_for(v), STRIP / (BAR.y - 4.0))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.size = Vector2(STRIP, BAR.y - 4.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.modulate = Color.WHITE if r.available else Color(0.4, 0.4, 0.4)
	stack.add_child(pic)
	var fade := TextureRect.new()  # the eyes melt into the bar on the right
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(BG.r, BG.g, BG.b, 0.0))
	g.set_color(1, Color(BG.r, BG.g, BG.b, 1.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	fade.texture = gt
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.position = Vector2(STRIP - 90.0, 0)
	fade.size = Vector2(90.0, BAR.y - 4.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(fade)
	var nm := Label.new()
	nm.text = String(v.display_name).to_upper()
	Typography.apply(nm, Typography.Role.SUBHEADING, Color("#f4ead2") if r.available else Color("#7a7468"))
	nm.position = Vector2(STRIP + 6.0, 4.0)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(nm)
	var tag := Label.new()
	tag.text = r.tag
	Typography.apply(tag, Typography.Role.CAPTION, _tag_color(r))
	tag.position = Vector2(BAR.x - 4.0 - 158.0, 10.0)
	tag.size = Vector2(150.0, 20.0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(tag)
	bar.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			selected = i
			_paint()
			confirm()
			accept_event())
	bar.mouse_entered.connect(func():
		if r.available:
			selected = i
			_paint())
	return bar


static func _tag_color(r: Dictionary) -> Color:
	match r.state:
		SummonRanking.State.LEARNING:
			return HudStyle.GOLD
		SummonRanking.State.FRESH:
			return Color("#9fe8a8")
		SummonRanking.State.KNOWN:
			return Color("#a8a290")
	return Color("#8a8474")


## The frame of each bar: gold for the choice, a thin dark gold for the rest.
func _paint() -> void:
	for i in _bars.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = BG
		var on: bool = i == selected and rows[i].available
		sb.border_color = HudStyle.GOLD if on else DIM
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(2)
		_bars[i].add_theme_stylebox_override("panel", sb)
