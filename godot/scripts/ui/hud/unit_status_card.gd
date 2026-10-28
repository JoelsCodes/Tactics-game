class_name UnitStatusCard
extends PanelContainer
## A unit's status card in a bottom corner of the battle HUD. The HUD has two: the unit acting now
## (bottom right) and the selected or targeted unit (bottom left). Name and level, its role (the game is
## classless, so King / Co-Captain / Vessel / Enemy stands in for a class), HP, SP and XP bars, and for
## vessels the Fade Clock and the lifetime Sever and Tether counts.

const WIDTH := 400

## Small heading above the name, e.g. "Acting" or "Target".
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


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	caption_label = Label.new()
	caption_label.theme_type_variation = &"SectionLabel"
	caption_label.text = caption.to_upper()
	caption_label.visible = caption != ""
	col.add_child(caption_label)
	var head := HBoxContainer.new()
	col.add_child(head)
	name_label = Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	level_label = Label.new()
	level_label.theme_type_variation = &"TitleLabel"
	head.add_child(level_label)
	class_label = Label.new()
	class_label.theme_type_variation = &"SmallLabel"
	col.add_child(class_label)
	hp_bar = HudStyle.bar(HudStyle.HP, 12)
	hp_text = _row(col, "HP", hp_bar)
	sp_bar = HudStyle.bar(HudStyle.SP, 12)
	sp_text = _row(col, "SP", sp_bar)
	xp_bar = HudStyle.bar(HudStyle.XP, 6)
	xp_text = _row(col, "XP", xp_bar)
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
	name_label.text = d.display_name
	name_label.add_theme_color_override("font_color", HudStyle.team_color(bu))
	level_label.text = "Lv %d" % d.level
	class_label.text = "%s%s" % [_class_name(d), "  ·  knocked out" if bu.is_down() else ""]
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
	xp_text.get_parent().visible = d.role() != UnitData.Role.ENEMY  # enemies earn no XP
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


## One stat row: name, bar, value.
func _row(col: VBoxContainer, title: String, bar: ProgressBar) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = &"SmallLabel"
	t.custom_minimum_size.x = 30
	row.add_child(t)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", HudStyle.FONT_SMALL)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size.x = 96
	row.add_child(v)
	return v
