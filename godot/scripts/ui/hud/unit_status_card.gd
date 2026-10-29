class_name UnitStatusCard
extends VBoxContainer
## A unit's status card in a bottom corner of the battle HUD. The HUD has two: the unit acting now
## (bottom right) and the selected or targeted unit (bottom left). A caption plaque ("Acting" /
## "Target") over a sleek panel: the name in capitals and LVL, a large portrait, its title (the game is
## classless, so King / Co-Captain / Vessel / Enemy and the stance stand in for a class), exact HP and
## SP on thin lines, XP, status chips (Fade countdown, Guarding, Knocked out, Low SP) and for vessels
## the Fade Clock and the lifetime Sever and Tether counts.

const WIDTH := 430
const PORTRAIT := Vector2(104, 112)

## Text on the plaque above the card, e.g. "Acting" or "Target".
@export var caption := ""

var unit: BattleUnit
var caption_label: Label
var name_label: Label
var level_label: Label
var class_label: Label
var hp_bar: ProgressBar
var sp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_text: Label
var sp_text: Label
var xp_text: Label
var tactical: Label  ## vessel data: Fade Clock, Sever and Tether counts
var portrait: TextureRect
var portrait_frame: PanelContainer
var chips: HBoxContainer  ## status chips
var body: PanelContainer


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", -6)
	var plaque := HudStyle.plaque(caption, 18)
	caption_label = plaque.get_node("Text")
	plaque.visible = caption != ""
	add_child(plaque)
	body = PanelContainer.new()
	body.add_theme_stylebox_override("panel", HudStyle.slim_panel(20, 14))
	add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	body.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	name_label = Label.new()
	name_label.add_theme_font_override("font", HudStyle.font(true, true))
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	level_label = Label.new()
	level_label.add_theme_font_override("font", HudStyle.font(false, true))
	level_label.add_theme_font_size_override("font_size", 22)
	level_label.add_theme_color_override("font_color", Color("#cfc3a6"))
	head.add_child(level_label)
	col.add_child(HudStyle.divider())
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	col.add_child(main)
	portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = PORTRAIT
	main.add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(portrait)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("separation", 4)
	main.add_child(stats)
	class_label = Label.new()
	class_label.add_theme_font_size_override("font_size", 18)
	class_label.add_theme_color_override("font_color", Color("#e6d7b4"))
	stats.add_child(class_label)
	hp_bar = HudStyle.slim_bar(HudStyle.HP, 7)
	hp_text = _row(stats, "HP", hp_bar)
	sp_bar = HudStyle.slim_bar(HudStyle.SP, 7)
	sp_text = _row(stats, "SP", sp_bar)
	xp_bar = HudStyle.slim_bar(HudStyle.XP.darkened(0.15), 5)
	xp_text = _row(stats, "XP", xp_bar)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	stats.add_child(chips)
	tactical = Label.new()
	tactical.theme_type_variation = &"SmallLabel"
	tactical.add_theme_color_override("font_color", HudStyle.VESSEL)
	tactical.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tactical)
	hide()


func show_unit(bu: BattleUnit) -> void:
	unit = bu
	if bu == null:
		hide()
		return
	var d := bu.data
	var side := HudStyle.team_color(bu)
	portrait.texture = UnitLook.portrait(UnitLook.sheet_for(d))
	portrait.modulate = Color(0.55, 0.55, 0.55) if bu.is_down() else Color.WHITE
	portrait_frame.add_theme_stylebox_override("panel", HudStyle.portrait_box(side, 5))
	name_label.text = d.display_name.to_upper()
	name_label.add_theme_color_override("font_color", Color("#f4ead2") if bu.team == 0 else side.lightened(0.2))
	level_label.text = "LVL %d" % d.level
	class_label.text = "%s  ·  %s stance" % [_class_name(d), WeaponStyle.Stance.keys()[bu.stance()].capitalize()]
	hp_text.text = "%d / %d" % [bu.hp, bu.max_hp()]
	hp_bar.max_value = maxi(bu.max_hp(), 1)
	hp_bar.value = bu.hp
	sp_text.text = "%d / %d" % [bu.sp, bu.max_sp()]
	sp_bar.max_value = maxi(bu.max_sp(), 1)
	sp_bar.value = bu.sp
	var next := d.exp_to_next_level
	xp_text.text = "%d / %d" % [d.exp, next] if next > 0 else "max"
	xp_bar.max_value = maxi(next, 1)
	xp_bar.value = d.exp if next > 0 else 1
	xp_text.get_parent().get_parent().visible = d.role() != UnitData.Role.ENEMY  # enemies earn no XP
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	if bu.fade_clock:
		_chip("Fade %d / %d" % [bu.fade_clock.turns_left, bu.fade_clock.total], HudStyle.VESSEL)
	if bu.guarding:
		_chip("Guarding", Color("#8fe3ff"))
	if bu.is_down():
		_chip("Knocked out", HudStyle.ENEMY)
	if bu.sp < bu.max_sp() / 4 and not bu.is_down():
		_chip("Low SP", HudStyle.SP)
	tactical.visible = d is VesselData
	if d is VesselData:
		var v := d as VesselData
		var clock := "Fade Clock %d / %d" % [bu.fade_clock.turns_left, bu.fade_clock.total] if bu.fade_clock else "Not on the field"
		tactical.text = "%s\nSevered %d×  ·  Tethered %d×" % [clock, v.sever_count, v.tether_count]
	show()


static func _class_name(d: UnitData) -> String:
	match d.role():
		UnitData.Role.KING:
			return "King"
		UnitData.Role.CO_CAPTAIN:
			return "Co-Captain"
		UnitData.Role.VESSEL:
			return "Vessel"
	return "Enemy"


## A small status chip: colored text in a thin colored outline.
func _chip(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HudStyle.box(Color(col, 0.14), Color(col, 0.7), 5, 1, 8, 1))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", col.lightened(0.25))
	p.add_child(l)
	chips.add_child(p)


## One stat line: gold tag, the value at the right, a thin bar under them.
func _row(col: VBoxContainer, tag: String, bar: ProgressBar) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	col.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var t := Label.new()
	t.text = tag
	t.add_theme_font_override("font", HudStyle.font(true, true))
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", HudStyle.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", 18)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(v)
	box.add_child(bar)
	return v
