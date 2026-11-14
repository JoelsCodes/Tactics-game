class_name MomentumGauge
extends PanelContainer
## Top right of the battle HUD: the party's Momentum (see Momentum): a gold bar that fills as the party fights well, the Chain
## beside it, and the SURGE button that lights up when the bar is full. Under it, the battle speed button. It only shows
## things and reports presses; BattleStage decides what they do.

signal surge_pressed
signal speed_pressed

const WIDTH := 372

var bar: Control
var chain_label: Label
var surge_button: Button
var speed_button: Button
var hint: Label
var _ratio := 0.0  ## what the bar shows now (eases toward the real value)
var _target := 0.0
var _full := false
var _armed := false
var _t := 0.0
var _flash := 0.0  ## a white flash over the bar when it gains


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", HudStyle.slim_panel(16, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Momentum"
	Typography.apply(title, Typography.Role.SECTION)
	title.add_theme_color_override("font_color", Color("#cfe6ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	chain_label = Label.new()
	Typography.apply(chain_label, Typography.Role.NUMBER)
	chain_label.add_theme_color_override("font_color", HudStyle.ICE)
	chain_label.pivot_offset = Vector2(40, 12)
	head.add_child(chain_label)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.draw.connect(_draw_bar)
	col.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	surge_button = Button.new()
	surge_button.text = "Surge  [F]"
	surge_button.custom_minimum_size = Vector2(0, 38)
	surge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Typography.apply(surge_button, Typography.Role.BODY_STRONG)
	surge_button.focus_mode = Control.FOCUS_NONE
	surge_button.disabled = true
	surge_button.tooltip_text = "Spend a full Momentum bar: this unit's next attack cannot miss and is critical on every target."
	surge_button.pressed.connect(func(): surge_pressed.emit())
	row.add_child(surge_button)
	speed_button = Button.new()
	speed_button.text = "Speed 1×"
	speed_button.custom_minimum_size = Vector2(118, 38)
	Typography.apply(speed_button, Typography.Role.LABEL)
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.tooltip_text = "Battle speed (Tab)"
	speed_button.pressed.connect(func(): speed_pressed.emit())
	row.add_child(speed_button)
	hint = Label.new()
	hint.theme_type_variation = &"SmallLabel"
	Typography.apply(hint, Typography.Role.CAPTION)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Hits, criticals, pincers and knockouts fill it."
	col.add_child(hint)


## Shows the gauge's state. `can_surge`: the bar is full and the acting unit may spend it now. `armed`: a Surge is waiting on the acting unit.
func show_state(m: Momentum, can_surge: bool, armed: bool) -> void:
	if m.ratio() > _target + 0.001:
		_flash = 1.0
	_target = m.ratio()
	_full = m.is_full()
	_armed = armed
	var text := "Chain ×%d" % m.chain if m.chain >= 2 else ""
	if text != chain_label.text:
		chain_label.text = text
		if text != "" and is_inside_tree():  # a new link pops
			chain_label.scale = Vector2(1.5, 1.5)
			create_tween().tween_property(chain_label, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	surge_button.disabled = not (can_surge or armed)
	surge_button.text = "Surge armed  [F] cancels" if armed else "Surge  [F]"
	hint.text = "Armed: the next attack cannot miss and is critical." if armed else ("Full! Spend it on this unit's attack." if _full else "Hits, criticals, pincers and knockouts fill it.")
	bar.queue_redraw()


func set_speed(mult: float) -> void:
	speed_button.text = "Speed %s×" % (str(int(mult)) if is_equal_approx(mult, roundf(mult)) else "%.1f" % mult)


func _process(delta: float) -> void:
	_t += delta
	var moving := absf(_target - _ratio) > 0.0005
	if moving:
		_ratio = lerpf(_ratio, _target, 1.0 - exp(-9.0 * delta))
	_flash = maxf(0.0, _flash - delta * 3.0)
	if moving or _full or _armed or _flash > 0.0:
		bar.queue_redraw()
	if (_full or _armed) and not surge_button.disabled:
		var k := 0.5 + 0.5 * sin(_t * 6.0)
		surge_button.modulate = Color(1.0 + 0.5 * k, 1.0 + 0.3 * k, 1.0)
	else:
		surge_button.modulate = Color.WHITE


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(r, Color(0, 0, 0, 0.6))
	var w := (r.size.x - 4.0) * clampf(_ratio, 0.0, 1.0)
	if w > 0.5:
		var a := Color("#2f7fc4")  # the icy blue; armed (a Surge ready to fire) turns to a hot amber
		var b := Color("#cfeeff")
		if _armed:
			a = Color("#c23b1c")
			b = Color("#ffb347")
		var pulse := (0.5 + 0.5 * sin(_t * 6.0)) if (_full or _armed) else 0.0
		var steps := 24
		for i in steps:  # a left-to-right gradient, brighter when full
			var x0 := 2.0 + w * i / steps
			var c := a.lerp(b, float(i) / steps).lightened(0.25 * pulse + 0.5 * _flash)
			bar.draw_rect(Rect2(x0, 2.0, w / steps + 0.6, r.size.y - 4.0), c)
		bar.draw_rect(Rect2(2.0, 2.0, w, (r.size.y - 4.0) * 0.4), Color(1, 1, 1, 0.16))
	for i in range(1, 4):  # quarter marks
		var x := 2.0 + (r.size.x - 4.0) * i / 4.0
		bar.draw_line(Vector2(x, 2), Vector2(x, r.size.y - 2), Color(0, 0, 0, 0.45), 1.0)
	bar.draw_rect(r, Color(HudStyle.ICE, 0.95 if _full else 0.45), false, 1.0)
