class_name BattleHud
extends CanvasLayer
## The battle HUD: turn order across the top, the command palette at the bottom center, the selected
## unit's status card at the bottom right, a short message line, and the result panel at the end.
## It only shows things and reports button presses; BattleStage decides what they do.

signal return_pressed
signal rotate_pressed

var root: Control
var turn_order: TurnOrderBar
var palette: CommandPalette
var card: UnitStatusCard
var message: Label
var result_panel: PanelContainer
var result_title: Label
var result_text: Label
var return_button: Button
var rotate_button: Button


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = HudStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_margins(top, 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var top_col := VBoxContainer.new()
	top_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_col)
	turn_order = TurnOrderBar.new()
	top_col.add_child(turn_order)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_col.add_child(top_row)
	message = Label.new()
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.add_theme_constant_override("outline_size", 5)
	message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(message)
	rotate_button = Button.new()
	rotate_button.text = "Rotate"
	rotate_button.custom_minimum_size = Vector2(70, 36)
	rotate_button.pressed.connect(func(): rotate_pressed.emit())
	top_row.add_child(rotate_button)

	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_margins(bottom, 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(row)
	var center := CenterContainer.new()  # keeps the palette centered in the space left of the card
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_END
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(center)
	palette = CommandPalette.new()
	center.add_child(palette)
	card = UnitStatusCard.new()
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(card)

	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", HudStyle.box(HudStyle.GLASS, HudStyle.GOLD, 8, 1, 18, 14))
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(320, 0)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(result_panel)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 8)
	result_panel.add_child(rc)
	result_title = Label.new()
	result_title.add_theme_font_size_override("font_size", 26)
	result_title.add_theme_color_override("font_color", HudStyle.GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(result_title)
	result_text = Label.new()
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.theme_type_variation = &"SmallLabel"
	result_text.add_theme_color_override("font_color", HudStyle.TEXT)
	result_text.custom_minimum_size.x = 284
	rc.add_child(result_text)
	return_button = Button.new()
	return_button.text = "Return to the barracks"
	return_button.custom_minimum_size.y = 46
	return_button.pressed.connect(func(): return_pressed.emit())
	rc.add_child(return_button)
	result_panel.hide()


func say(text: String) -> void:
	message.text = text


## The end-of-battle panel: the outcome and one line per unit (BattleSummary.describe).
func show_result(summary: BattleSummary) -> void:
	result_title.text = {BattleController.Outcome.WON: "Victory", BattleController.Outcome.LOST: "Defeat"}.get(summary.outcome, "Battle over")
	var lines: Array[String] = []
	for bu in summary.lines:
		if bu.data.role() != UnitData.Role.ENEMY:
			lines.append(summary.describe(bu))
	if summary.exp_each > 0:
		lines.append("XP pool %d, %d each" % [summary.exp_pool, summary.exp_each])
	if not summary.relics_secured.is_empty():
		lines.append("Relics home: " + ", ".join(summary.relics_secured.map(func(r): return r.display_name)))
	result_text.text = "\n".join(lines)
	palette.hide_palette()
	result_panel.show()


func _margins(m: MarginContainer, px: int) -> void:
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
