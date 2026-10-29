class_name TurnOrderBar
extends PanelContainer
## Top center of the battle HUD: the coming turns in initiative order (TurnManager.upcoming) as a strip
## of compact cards between gold arrow caps. Each card has the portrait, the name and a thin HP line
## (colored by side: gold for the King and Co-Captains, cyan for vessels with their Fade Clock as a
## number, red for enemies). The unit acting now comes first, on a cyan-edged card with a soft glow
## that breathes, and its card pops in scale when its turn begins.

signal unit_pressed(unit: BattleUnit)

## How many turns to show.
@export var count := 7
## Enemies take turns too; set false to list only the player's units.
@export var show_enemies := true

const CARD := Vector2(128, 62)
const FACE := 48

var entries: Array[BattleUnit] = []  ## what is shown, in order
var now_frame: Control  ## the acting unit's card (glow and pop)
var _row: HBoxContainer
var _last_now: BattleUnit


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("panel", HudStyle.slim_panel(8, 6))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(line)
	line.add_child(_arrow("queue_arrow_l.png"))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	line.add_child(_row)
	line.add_child(_arrow("queue_arrow_r.png"))


func show_turns(turns: TurnManager) -> void:
	var list := turns.upcoming(count * 3)
	if not show_enemies:
		list = list.filter(func(u): return TurnManager.group_of(u) != TurnManager.Group.ENEMY)
	entries.assign(list.slice(0, count))
	for c in _row.get_children():
		c.queue_free()
	now_frame = null
	for i in entries.size():
		_row.add_child(_card(entries[i], i == 0))
	if not entries.is_empty() and entries[0] != _last_now:
		_last_now = entries[0]
		_pop()


## The scale pop on the acting unit's card (pivot in its middle).
func _pop() -> void:
	if now_frame == null or not is_inside_tree():
		return
	now_frame.pivot_offset = CARD / 2.0
	now_frame.scale = Vector2.ONE * 0.88
	var tw := now_frame.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(now_frame, "scale", Vector2.ONE * 1.08, 0.16)
	tw.tween_property(now_frame, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)


func _card(bu: BattleUnit, now: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	card.add_theme_stylebox_override("panel", HudStyle.queue_box(now))
	card.tooltip_text = bu.data.display_name
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: unit_pressed.emit(bu))
	if now:
		now_frame = card
		_add_glow(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var face := Control.new()
	face.custom_minimum_size = Vector2(FACE, FACE)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var pic := TextureRect.new()
	pic.texture = UnitLook.portrait(UnitLook.sheet_for(bu.data))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bu.is_down():
		pic.modulate = Color(0.5, 0.5, 0.5)
	face.add_child(pic)
	if bu.fade_clock != null:
		var badge := Label.new()
		badge.text = str(bu.fade_clock.turns_left)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", HudStyle.VESSEL)
		badge.add_theme_constant_override("outline_size", 6)
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -12
		face.add_child(badge)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var name := Label.new()
	name.text = bu.data.display_name
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color("#eaf9ff") if now else HudStyle.TEXT)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	info.add_child(hp_row)
	var tag := Label.new()
	tag.text = "HP"
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", HudStyle.GOLD)
	hp_row.add_child(tag)
	var bar := HudStyle.slim_bar(HudStyle.team_color(bu), 5)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxi(bu.max_hp(), 1)
	bar.value = bu.hp
	hp_row.add_child(bar)
	return card


## A soft cyan glow under the acting unit's card that breathes.
func _add_glow(card: Control) -> void:
	var holder := Control.new()  # first child: drawn over the card's fill, under its contents
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(holder)
	var halo := TextureRect.new()
	halo.name = "Glow"
	halo.texture = load("res://assets/fx/soft_dot.png")
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.size = CARD * Vector2(1.5, 2.2)
	halo.position = -CARD * Vector2(0.25, 0.6)
	halo.modulate = Color(0.45, 0.9, 1.0, 0.45)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(halo)
	var tw := halo.create_tween().set_loops()
	tw.tween_property(halo, "modulate:a", 0.2, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)


func _arrow(file: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(HudStyle.UI_DIR + file)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = Vector2(28, CARD.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
