class_name UnitStatusCard
extends PanelContainer
## Bottom right of the battle HUD: the selected unit. Name, its role (the game is classless, so the
## King / Co-Captain / Vessel / Enemy role stands in for a class), level and XP, HP, SP, and for vessels
## the Fade Clock and the lifetime Sever and Tether counts.

var unit: BattleUnit
var name_label: Label
var class_label: Label
var hp_bar: ProgressBar
var sp_bar: ProgressBar
var xp_bar: ProgressBar
var hp_text: Label
var sp_text: Label
var xp_text: Label
var tactical: Label  ## vessel data: Fade Clock, Sever and Tether counts


func _ready() -> void:
	custom_minimum_size.x = 190
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	add_child(col)
	name_label = Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.clip_text = true
	col.add_child(name_label)
	class_label = Label.new()
	class_label.theme_type_variation = &"SmallLabel"
	col.add_child(class_label)
	hp_text = _row(col, "HP")
	hp_bar = HudStyle.bar(HudStyle.HP)
	col.add_child(hp_bar)
	sp_text = _row(col, "SP")
	sp_bar = HudStyle.bar(HudStyle.SP)
	col.add_child(sp_bar)
	xp_text = _row(col, "XP")
	xp_bar = HudStyle.bar(HudStyle.XP)
	col.add_child(xp_bar)
	tactical = Label.new()
	tactical.theme_type_variation = &"SmallLabel"
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
	class_label.text = "%s  ·  Lv %d%s" % [_class_name(d), d.level, "  ·  down" if bu.is_down() else ""]
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


func _row(col: VBoxContainer, title: String) -> Label:
	var row := HBoxContainer.new()
	col.add_child(row)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = &"SmallLabel"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var v := Label.new()
	v.theme_type_variation = &"SmallLabel"
	v.add_theme_color_override("font_color", HudStyle.TEXT)
	row.add_child(v)
	return v
