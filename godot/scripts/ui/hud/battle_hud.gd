class_name BattleHud
extends CanvasLayer
## The battle HUD for a 16:9 screen (laid out at 1920x1080, scaling with the window):
##   top center      the turn order, with a message line under it; Rotate at the top right
##   bottom left     the selected or targeted unit's card (hidden when nothing else is selected)
##   bottom center   the command palette
##   bottom right    the acting unit's card
## and the result panel in the middle at the end. It only shows things and reports button presses;
## BattleStage decides what they do.

signal return_pressed
signal rotate_pressed

## Screen space the HUD's center column covers at 1080p (turn order above, palette below), so the camera
## can frame the battlefield between them. The status cards sit in the bottom corners, beside it.
const TOP_BAND := 190
const BOTTOM_BAND := 215

var root: Control
var turn_order: TurnOrderBar
var palette: CommandPalette
var card: UnitStatusCard  ## the acting unit
var target_card: UnitStatusCard  ## a selected or targeted unit
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
	_margins(top, 24, 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var top_col := VBoxContainer.new()
	top_col.add_theme_constant_override("separation", 8)
	top_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_col)
	turn_order = TurnOrderBar.new()
	top_col.add_child(turn_order)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", HudStyle.FONT)
	message.add_theme_constant_override("outline_size", 6)
	message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	top_col.add_child(message)
	rotate_button = Button.new()
	rotate_button.text = "Rotate view"
	rotate_button.custom_minimum_size = Vector2(160, 48)
	rotate_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rotate_button.offset_left = -184
	rotate_button.offset_top = 24
	rotate_button.offset_right = -24
	rotate_button.pressed.connect(func(): rotate_pressed.emit())
	root.add_child(rotate_button)

	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_margins(bottom, 24, 24)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(row)
	var left := Control.new()  # keeps its width when the target card is hidden, so the palette stays centered
	left.custom_minimum_size.x = UnitStatusCard.WIDTH
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	target_card = UnitStatusCard.new()
	target_card.caption = "Target"
	target_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	target_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.add_child(target_card)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_END
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(center)
	palette = CommandPalette.new()
	center.add_child(palette)
	card = UnitStatusCard.new()
	card.caption = "Acting"
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(card)

	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", HudStyle.panel(true, 40, 32))
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.custom_minimum_size = Vector2(720, 0)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(result_panel)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 14)
	result_panel.add_child(rc)
	result_title = Label.new()
	result_title.theme_type_variation = &"HeadingLabel"
	result_title.add_theme_color_override("font_color", HudStyle.GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(result_title)
	result_text = Label.new()
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.custom_minimum_size.x = 656
	rc.add_child(result_text)
	return_button = Button.new()
	return_button.text = "Return to the barracks"
	return_button.custom_minimum_size = Vector2(320, 58)
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_button.pressed.connect(func(): return_pressed.emit())
	rc.add_child(return_button)
	result_panel.hide()
	HudStyle.frost_panels(self)  # the game shows blurred through the panels' glass


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
	target_card.show_unit(null)
	result_panel.show()


func _margins(m: MarginContainer, x: int, y: int) -> void:
	m.add_theme_constant_override("margin_left", x)
	m.add_theme_constant_override("margin_right", x)
	m.add_theme_constant_override("margin_top", y)
	m.add_theme_constant_override("margin_bottom", y)
