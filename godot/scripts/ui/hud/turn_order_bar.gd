class_name TurnOrderBar
extends PanelContainer
## Top center of the battle HUD: the coming turns in initiative order (TurnManager.upcoming), as
## portraits with names. The unit acting now comes first, larger, with a gold frame, a soft breathing
## gold glow, and a quick scale pop when its turn begins. Frames are colored
## by side: gold for the King and Co-Captains, cyan for vessels (with their Fade Clock as a number), red
## for enemies.

signal unit_pressed(unit: BattleUnit)

## How many turns to show.
@export var count := 10
## Enemies take turns too; set false to list only the player's units.
@export var show_enemies := true

const NOW_SIZE := 92
const NEXT_SIZE := 70

var entries: Array[BattleUnit] = []  ## what is shown, in order
var now_frame: Control  ## the acting unit's portrait frame (glow and pop)
var _row: HBoxContainer
var _last_now: BattleUnit


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := Label.new()
	head.text = "TURN ORDER"
	head.theme_type_variation = &"SectionLabel"
	col.add_child(head)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


func show_turns(turns: TurnManager) -> void:
	var list := turns.upcoming(count * 3)
	if not show_enemies:
		list = list.filter(func(u): return TurnManager.group_of(u) != TurnManager.Group.ENEMY)
	entries.assign(list.slice(0, count))
	for c in _row.get_children():
		c.queue_free()
	for i in entries.size():
		_row.add_child(_slot(entries[i], i == 0))
	if not entries.is_empty() and entries[0] != _last_now:
		_last_now = entries[0]
		_pop()


## The scale pop on the acting unit's portrait (pivot in its middle).
func _pop() -> void:
	if now_frame == null or not is_inside_tree():
		return
	now_frame.pivot_offset = Vector2(NOW_SIZE, NOW_SIZE) / 2.0 + Vector2(5, 5)
	now_frame.scale = Vector2.ONE * 0.86
	var tw := now_frame.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(now_frame, "scale", Vector2.ONE * 1.1, 0.16)
	tw.tween_property(now_frame, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)


func _slot(bu: BattleUnit, now: bool) -> Control:
	var side := NOW_SIZE if now else NEXT_SIZE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HudStyle.portrait_box(HudStyle.GOLD.lightened(0.2) if now else HudStyle.team_color(bu), 5 if now else 4))
	frame.tooltip_text = bu.data.display_name
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: unit_pressed.emit(bu))
	col.add_child(frame)
	if now:
		now_frame = frame
		var holder := Control.new()  # first child: the glow draws over the frame's ring, under the portrait
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(holder)
		var halo := TextureRect.new()
		halo.name = "Glow"
		halo.texture = load("res://assets/fx/soft_dot.png")
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_SCALE
		halo.size = Vector2(side, side) * 1.9
		halo.position = -Vector2(side, side) * 0.45
		halo.modulate = Color(1.0, 0.82, 0.4, 0.7)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		halo.material = add
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(halo)
		var tw := halo.create_tween().set_loops()
		tw.tween_property(halo, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(halo, "modulate:a", 0.7, 0.9).set_trans(Tween.TRANS_SINE)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(side, side)
	frame.add_child(stack)
	var pic := TextureRect.new()
	pic.texture = UnitLook.portrait(UnitLook.sheet_for(bu.data))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.modulate = Color(1, 1, 1) if bu.data.role() != UnitData.Role.ENEMY else Color(1, 0.82, 0.8)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(pic)
	var strip := ColorRect.new()  # a side-colored strip along the bottom
	strip.color = HudStyle.team_color(bu)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -4
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(strip)
	if bu.fade_clock != null:
		var badge := Label.new()
		badge.text = str(bu.fade_clock.turns_left)
		badge.add_theme_font_size_override("font_size", HudStyle.FONT)
		badge.add_theme_color_override("font_color", HudStyle.VESSEL)
		badge.add_theme_constant_override("outline_size", 6)
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -18
		stack.add_child(badge)
	var name := Label.new()
	name.text = bu.data.display_name
	name.theme_type_variation = &"SmallLabel"
	name.add_theme_color_override("font_color", HudStyle.GOLD if now else HudStyle.MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size.x = side + 6
	col.add_child(name)
	return col
