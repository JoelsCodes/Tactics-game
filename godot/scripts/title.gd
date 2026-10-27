extends Control
## Title screen: pick a story mission. The campaign (map, shop, clan) is not ported yet,
## so each mission starts with the default clan at a fitting level.


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_theme_constant_override("margin_top", 48)
	m.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var t := UI.label("Hollowmark Tactics", 30, UI.BRASS)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("Godot edition · battle preview", 14, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	# The starting clan, as portraits.
	var party := Rules.new_party()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for u in party:
		row.add_child(UI.Portrait.new(u, 46, 0))
	v.add_child(UI.spacer(0, 6))
	v.add_child(row)
	v.add_child(UI.spacer(0, 10))
	v.add_child(UI.label("Story missions", 13, UI.MUTED))
	for i in Data.MISSIONS.size():
		var ms: Dictionary = Data.MISSIONS[i]
		var stage := i
		var law := "Banned: %s · Favored: %s" % [Data.LAWS[ms.law.ban].name, Data.LAWS[ms.law.fav].name]
		v.add_child(UI.opt(ms.name, "%s\n%s · %s · %d units, Lv %d" % [ms.brief, Data.MAPS[ms.map].name, law, ms.deploy, 1 + i * 2], "", func(): _start(stage)))
	v.add_child(UI.spacer(0, 8))
	v.add_child(UI.label("Tap Move, then a blue tile. Tap Act, pick an ability, tap a target twice to confirm. Drag to pan, pinch or use the buttons to zoom and rotate.", 12, UI.MUTED, true))


func _start(stage: int) -> void:
	var Battle = load("res://scripts/battle.gd")
	Battle.stage = stage
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
