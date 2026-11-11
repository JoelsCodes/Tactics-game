class_name ForecastPanel
extends VBoxContainer
## The damage prediction view: when a tile is aimed with the attack or a skill, a panel slides out from the left edge of the battle HUD, just above the
## Target card, and says what the action would do to the unit on it (DamageForecast): a plaque with the action's name and SP cost, the target's
## name and HP with a forecast bar (what is certainly lost, what might be, what is left), the chance to hit, the damage or healing in large numbers
## (a range when it rolls), chips for the extra effects and a Knockout warning, and a line for each other unit the action hits.
## It only shows things; BattleStage feeds it when a tile is aimed and hides it when the aim ends.

const WIDTH := 430
const SLIDE := 0.24  ## seconds to slide in or out
const MAX_OTHERS := 4
const RED := Color("#e0584a")
const AMBER := Color("#f0a44a")
const MUTED_CHIP := Color("#9aa6c4")

var plaque_label: Label
var name_label: Label
var hp_label: Label
var bar: ForecastBar
var hit_value: Label
var hit_tag: Label
var big: Label
var big_caption: Label
var chips: HBoxContainer
var others: VBoxContainer
var shown := false
var _tween: Tween
var _home_x := 0.0


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", -6)
	var plaque := HudStyle.plaque("FORECAST", 18)
	plaque_label = plaque.get_node("Text")
	add_child(plaque)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", HudStyle.slim_panel(20, 14))
	add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	body.add_child(col)
	# the target: name, HP before and after, the forecast bar
	var head := HBoxContainer.new()
	col.add_child(head)
	name_label = Label.new()
	Typography.apply(name_label, Typography.Role.SUBHEADING)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	hp_label = Label.new()
	Typography.apply(hp_label, Typography.Role.NUMBER)
	head.add_child(hp_label)
	bar = ForecastBar.new()
	bar.custom_minimum_size.y = 14
	col.add_child(bar)
	col.add_child(HudStyle.divider())
	# the numbers: hit chance on the left, the damage or healing large on the right
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 18)
	col.add_child(nums)
	var hit_col := VBoxContainer.new()
	hit_col.add_theme_constant_override("separation", 0)
	hit_col.custom_minimum_size.x = 120
	nums.add_child(hit_col)
	hit_tag = Label.new()
	hit_tag.text = "Hit"
	Typography.apply(hit_tag, Typography.Role.LABEL, HudStyle.GOLD)
	hit_col.add_child(hit_tag)
	hit_value = Label.new()
	Typography.apply(hit_value, Typography.Role.NUMBER)
	hit_value.add_theme_font_size_override("font_size", 40)  # the chance to hit, large: Inter's tabular figures
	hit_col.add_child(hit_value)
	var big_col := VBoxContainer.new()
	big_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	big_col.add_theme_constant_override("separation", -4)
	nums.add_child(big_col)
	big = Label.new()
	Typography.apply(big, Typography.Role.NUMBER)
	big.add_theme_font_size_override("font_size", 64)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_constant_override("outline_size", 6)
	big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	big_col.add_child(big)
	big_caption = Label.new()
	Typography.apply(big_caption, Typography.Role.LABEL, Color("#cfc3a6"))
	big_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_col.add_child(big_caption)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	col.add_child(chips)
	others = VBoxContainer.new()
	others.add_theme_constant_override("separation", 2)
	col.add_child(others)
	modulate.a = 0.0
	hide()


## Shows `f` (a DamageForecast) and slides the panel out if it is not out already. An empty forecast hides it.
func show_forecast(f: DamageForecast) -> void:
	if f == null or f.is_empty():
		hide_forecast()
		return
	var l := f.aimed
	plaque_label.text = ("%s  ·  %d SP" % [f.action_name.to_upper(), f.sp_cost]) if f.sp_cost > 0 else f.action_name.to_upper()
	var side := HudStyle.team_color(l.target)
	name_label.text = l.target.data.display_name
	name_label.add_theme_color_override("font_color", Color("#f4ead2") if l.target.team == 0 else side.lightened(0.2))
	hp_label.text = "%d  →  %d" % [l.hp_before, l.hp_low] if l.low == l.high else "%d  →  %d-%d" % [l.hp_before, l.hp_low, l.hp_high]
	hp_label.add_theme_color_override("font_color", HudStyle.HP if l.heal else Color("#f1e2bd"))
	bar.set_forecast(l)
	hit_value.text = "%d%%" % l.hit_percent
	hit_value.add_theme_color_override("font_color", Color("#f4ead2") if l.hit_percent >= 85 else AMBER)
	big.text = l.headline
	big.add_theme_color_override("font_color", HudStyle.HP.lightened(0.25) if l.heal else Color("#fff3d6"))
	big.add_theme_font_size_override("font_size", 64 if l.headline.length() <= 5 else 44)
	big_caption.text = l.caption
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	if l.ko and l.hit_percent >= 100:
		_chip("KNOCKOUT", RED)
	elif l.ko:
		_chip("KO if it hits", RED)
	elif l.may_ko:
		_chip("May KO", AMBER)
	if l.angle == BattleController.Angle.BACK:
		_chip("BACK ATTACK", HudStyle.GOLD)
	elif l.angle == BattleController.Angle.FRONT and not l.heal:
		_chip("FRONT", MUTED_CHIP)
	elif l.angle == BattleController.Angle.SIDE:
		_chip("FLANK", HudStyle.GOLD)
	if l.crit_percent > 0 and not l.heal:
		_chip("CRIT %d%%" % l.crit_percent, HudStyle.GOLD)
	if l.pincer != "":
		_chip("%s follows up" % l.pincer, HudStyle.GOLD)
	for n in l.notes:
		if n != "Knockout":
			_chip(n, HudStyle.GOLD)
	chips.visible = chips.get_child_count() > 0
	for c in others.get_children():
		others.remove_child(c)
		c.queue_free()
	var extra := f.lines.filter(func(x): return x != l)
	for x in extra.slice(0, MAX_OTHERS):
		others.add_child(_other_row(x))
	others.visible = not extra.is_empty()
	_slide(true)


func hide_forecast() -> void:
	_slide(false)


## One of the other units the action hits: its name, the chance to hit and the amount.
func _other_row(x: DamageForecast.Line) -> HBoxContainer:
	var row := HBoxContainer.new()
	var n := Label.new()
	n.text = x.target.data.display_name
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	Typography.apply(n, Typography.Role.BODY, Color("#cfc3a6"))
	row.add_child(n)
	var h := Label.new()
	h.text = "%d%%  " % x.hit_percent
	Typography.apply(h, Typography.Role.NUMBER, Color("#cfc3a6"))
	row.add_child(h)
	var a := Label.new()
	a.text = x.headline
	a.custom_minimum_size.x = 70
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Typography.apply(a, Typography.Role.NUMBER, HudStyle.HP.lightened(0.25) if x.heal else Color("#fff3d6"))
	row.add_child(a)
	return row


func _slide(on: bool) -> void:
	if _tween != null:
		_tween.kill()
	if on == shown and on:
		return  # already out: only the contents changed
	shown = on
	_tween = create_tween()
	_tween.set_parallel(true)
	if on:
		show()
		position.x = _home_x - WIDTH - 40.0
		modulate.a = 0.0
		_tween.tween_property(self, "position:x", _home_x, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, SLIDE * 0.8)
	else:
		_tween.tween_property(self, "position:x", _home_x - WIDTH - 40.0, SLIDE * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, SLIDE * 0.8)
		_tween.chain().tween_callback(hide)


## The x the panel rests at (set by the HUD once it knows its layout).
func set_home(x: float) -> void:
	_home_x = x
	if shown:
		position.x = x


func _chip(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", HudStyle.box(Color(col, 0.14), Color(col, 0.7), 5, 1, 8, 1))
	var l := Label.new()
	l.text = text
	Typography.apply(l, Typography.Role.LABEL, col.lightened(0.25))
	p.add_child(l)
	chips.add_child(p)


## The target's HP as a thin bar that shows the forecast: what stays (green), what is lost for certain (red), what might be lost (amber, the
## spread of a roll); for a heal, what is gained for certain (bright) and what might be (pale).
class ForecastBar extends Control:
	var max_hp := 1
	var before := 0
	var low := 0  ## HP after the largest outcome
	var high := 0  ## HP after the smallest outcome
	var heal := false

	func set_forecast(l: DamageForecast.Line) -> void:
		max_hp = maxi(1, l.max_hp)
		before = l.hp_before
		low = l.hp_low
		high = l.hp_high
		heal = l.heal
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6))
		var k := w / float(max_hp)
		if heal:
			draw_rect(Rect2(0, 0, before * k, h), HudStyle.HP)
			draw_rect(Rect2(before * k, 0, (low - before) * k, h), HudStyle.HP.lightened(0.5))
			draw_rect(Rect2(low * k, 0, (high - low) * k, h), Color(HudStyle.HP.lightened(0.5), 0.45))
		else:
			draw_rect(Rect2(0, 0, low * k, h), HudStyle.HP)
			draw_rect(Rect2(low * k, 0, (high - low) * k, h), AMBER)
			draw_rect(Rect2(high * k, 0, (before - high) * k, h), RED)
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.22), false, 1.0)
