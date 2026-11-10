class_name BattleHud
extends CanvasLayer
## The battle HUD for a 16:9 screen (laid out at 1920x1080, scaling with the window):
##   top left        a TURN banner and the Objectives
##   top center      the turn queue, with a message line under it; Rotate at the top right
##   bottom left     the selected or targeted unit's card (hidden when nothing else is selected); above it the damage
##                   prediction panel slides out from the left edge when a tile is aimed (ForecastPanel)
##   bottom center   the command palette
##   bottom right    the acting unit's card
## and the result panel in the middle at the end. It only shows things and reports button presses;
## BattleStage decides what they do.

signal return_pressed

## Screen space the HUD's center column covers at 1080p (turn order above, palette below), so the camera
## can frame the battlefield between them. The status cards sit in the bottom corners, beside it.
const TOP_BAND := 150
const BOTTOM_BAND := 262
const FORECAST_X := 24.0  ## the prediction panel rests at the left edge, above the Target card
const CARD_HEIGHT := 236  ## how tall the Target card (plaque and panel) stands at 1080p

var root: Control
var turn_order: TurnOrderBar
var palette: CommandPalette
var card: UnitStatusCard  ## the acting unit
var target_card: UnitStatusCard  ## a selected or targeted unit
var forecast: ForecastPanel  ## the damage prediction, above the target card
var message: Label
var result_panel: PanelContainer
var result_title: Label
var result_text: Label
var return_button: Button
var turn_label: Label  ## "TURN n" on the banner
var objective_label: Label
var tip_panel: PanelContainer  ## a tutorial hint under the objectives (BattleTutorial)
var tip_label: Label
var result: ResultScreen  ## the end-of-battle show (it owns result_panel, result_title, result_text and return_button)
var gauge: MomentumGauge  ## top right: Momentum, the Surge button and the battle speed
var callouts: CalloutLayer  ## big words over the fight, the start banner, the screen flash
var bars: UnitBars  ## the HP bars over the units
var feed: SkillFeed  ## skill training: the progress strip and the SKILL MASTERED card
var animate := true  ## off in tests: the result show is in its final state at once


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = HudStyle.hud_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	bars = UnitBars.new()
	root.add_child(bars)

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
	_build_turn_banner()

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

	forecast = ForecastPanel.new()
	forecast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	forecast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	forecast.offset_left = FORECAST_X
	forecast.offset_right = FORECAST_X + ForecastPanel.WIDTH
	forecast.offset_bottom = -(24 + CARD_HEIGHT + 10)
	root.add_child(forecast)
	forecast.set_home(FORECAST_X)
	gauge = MomentumGauge.new()
	gauge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gauge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gauge.offset_right = -24
	gauge.offset_left = -24 - MomentumGauge.WIDTH
	gauge.offset_top = 18
	root.add_child(gauge)
	callouts = CalloutLayer.new()
	root.add_child(callouts)
	feed = SkillFeed.new()
	root.add_child(feed)
	feed.anchor = card
	result = ResultScreen.new()
	root.add_child(result)
	result_panel = result.panel
	result_title = result.title
	result_text = result.plain
	return_button = result.button
	result.continue_pressed.connect(func(): return_pressed.emit())
	result_panel.hide()
	get_tree().node_added.connect(_wire_button)
	_wire_buttons(root)
	HudStyle.frost_panels(self)  # the game shows blurred through the panels' glass


## Top left: an arrow-shaped TURN banner and an Objectives strip fading out to the right.
func _build_turn_banner() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(0, 18)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var banner := TextureRect.new()
	banner.texture = load(HudStyle.UI_DIR + "turn_banner.png")
	banner.custom_minimum_size = Vector2(240, 64)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(banner)
	turn_label = Label.new()
	turn_label.add_theme_font_override("font", HudStyle.font(true, true))
	turn_label.add_theme_font_size_override("font_size", 30)
	turn_label.add_theme_color_override("font_color", Color("#f4ead2"))
	turn_label.position = Vector2(40, 10)
	turn_label.text = "TURN 1"
	banner.add_child(turn_label)
	var obj := PanelContainer.new()
	var sb := HudStyle.tex("fade_panel.png", 0, Vector4(28, 10, 120, 12))
	obj.add_theme_stylebox_override("panel", sb)
	obj.custom_minimum_size.x = 440
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(obj)
	var oc := VBoxContainer.new()
	oc.add_theme_constant_override("separation", 4)
	obj.add_child(oc)
	var head := Label.new()
	head.text = "Objectives"
	head.add_theme_font_override("font", HudStyle.font(false, true))
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color("#f1e2bd"))
	oc.add_child(head)
	objective_label = Label.new()
	objective_label.text = "•  Defeat all enemies"
	objective_label.add_theme_font_size_override("font_size", 18)
	oc.add_child(objective_label)
	tip_panel = PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", HudStyle.panel())
	tip_panel.custom_minimum_size.x = 440
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.visible = false
	box.add_child(tip_panel)
	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override("font_size", 22)
	tip_label.add_theme_color_override("font_color", Color("#f1e2bd"))
	tip_panel.add_child(tip_label)


func set_turn(n: int) -> void:
	turn_label.text = "TURN %d" % n


func set_objective(text: String) -> void:
	objective_label.text = "•  " + text


func say(text: String) -> void:
	message.text = text


## The damage prediction for the aimed tile (a DamageForecast; an empty one hides the panel).
func show_forecast(f: DamageForecast) -> void:
	forecast.show_forecast(f)


func hide_forecast() -> void:
	forecast.hide_forecast()


## A tutorial hint under the objectives; "" hides it.
func show_tip(text: String) -> void:
	tip_label.text = text
	tip_panel.visible = text != ""


## The end-of-battle show (ResultScreen): the outcome, the grade and its feats, a row per unit with its XP, the rewards.
func show_result(summary: BattleSummary) -> void:
	palette.hide_palette()
	target_card.show_unit(null)
	hide_forecast()
	gauge.hide()
	bars.hide()
	feed.hide()
	card.show_unit(null)
	message.text = ""
	result.animate = animate
	result_panel.show()
	result.show_summary(summary)


## Every button of the HUD ticks when the mouse comes over it and clicks when pressed (CombatAudio: ui_hover, ui_click).
func _wire_buttons(n: Node) -> void:
	_wire_button(n)
	for c in n.get_children():
		_wire_buttons(c)


func _wire_button(n: Node) -> void:
	if not (n is BaseButton) or n.has_meta("ui_sound") or not is_ancestor_of(n):
		return
	n.set_meta("ui_sound", true)
	var b := n as BaseButton
	b.mouse_entered.connect(func():
		if not b.disabled and b.is_visible_in_tree():
			CombatAudio.play(self, "ui_hover", 1.0, -6.0))
	if b != return_button:
		b.pressed.connect(func(): CombatAudio.play(self, "ui_click", 1.0, -3.0))


func _margins(m: MarginContainer, x: int, y: int) -> void:
	m.add_theme_constant_override("margin_left", x)
	m.add_theme_constant_override("margin_right", x)
	m.add_theme_constant_override("margin_top", y)
	m.add_theme_constant_override("margin_bottom", y)
