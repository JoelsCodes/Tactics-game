class_name TurnOrderBar
extends PanelContainer
## Top of the battle HUD: the coming turns in initiative order (TurnManager.upcoming), as portraits.
## The unit acting now comes first, larger, with a gold frame. Frames are colored by side: gold for the
## King and Co-Captains, cyan for vessels (with their Fade Clock as a small number), red for enemies.

signal unit_pressed(unit: BattleUnit)

## How many turns to show.
@export var count := 6
## Enemies take turns too; set false to list only the player's units.
@export var show_enemies := true

var entries: Array[BattleUnit] = []  ## what is shown, in order
var _row: HBoxContainer


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)


func show_turns(turns: TurnManager) -> void:
	var list := turns.upcoming(count * 3)
	if not show_enemies:
		list = list.filter(func(u): return TurnManager.group_of(u) != TurnManager.Group.ENEMY)
	entries.assign(list.slice(0, count))
	for c in _row.get_children():
		c.queue_free()
	for i in entries.size():
		_row.add_child(_slot(entries[i], i == 0))


func _slot(bu: BattleUnit, now: bool) -> Control:
	var size := 54 if now else 44
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HudStyle.box(HudStyle.GLASS_LIGHT, HudStyle.GOLD if now else HudStyle.team_color(bu), 6, 2 if now else 1, 2, 2))
	frame.tooltip_text = bu.data.display_name
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: unit_pressed.emit(bu))
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(size, size)
	frame.add_child(stack)
	var pic := TextureRect.new()
	pic.texture = UnitLook.portrait(UnitLook.sheet_for(bu.data))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.modulate = Color(1, 1, 1) if bu.data.role() != UnitData.Role.ENEMY else Color(1, 0.82, 0.8)
	stack.add_child(pic)
	var strip := ColorRect.new()  # a side-colored strip along the bottom
	strip.color = HudStyle.team_color(bu)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -3
	stack.add_child(strip)
	if bu.fade_clock != null:
		var badge := Label.new()
		badge.theme_type_variation = &"SmallLabel"
		badge.text = str(bu.fade_clock.turns_left)
		badge.add_theme_color_override("font_color", HudStyle.VESSEL)
		badge.add_theme_constant_override("outline_size", 4)
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -12
		stack.add_child(badge)
	return frame
