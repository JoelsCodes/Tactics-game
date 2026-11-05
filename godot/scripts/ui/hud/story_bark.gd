class_name StoryBark
extends CanvasLayer
## A short spoken line over a battle (a reinforcement arriving, Vesper leaving): a slim panel under the turn bar with the speaker's portrait,
## name and the line typed out. `say` waits until it has been read. Not used for the long scenes (Cutscene3D has its own dialogue box).

const CHARS_PER_SECOND := 44.0

var box: PanelContainer
var portrait: TextureRect
var who: Label
var line: Label
var _id := 0


func _init() -> void:
	layer = 30
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", HudStyle.slim_panel(22, 14))
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.0
	box.offset_left = -520
	box.offset_right = 520
	box.offset_top = 120
	box.offset_bottom = 260
	box.visible = false
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HudStyle.portrait_box(Color(0.85, 0.72, 0.45)))
	frame.custom_minimum_size = Vector2(112, 112)
	row.add_child(frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(104, 104)
	frame.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	who = Label.new()
	who.add_theme_font_override("font", HudStyle.font(true, true))
	who.add_theme_font_size_override("font_size", 24)
	who.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	col.add_child(who)
	line = Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_override("font", HudStyle.font())
	line.add_theme_font_size_override("font_size", 28)
	col.add_child(line)


## Shows `text` said by `sheet`'s character (a character sheet id) as `name`, typed out and held, then hidden. Returns when it is done.
func say(sheet: String, name: String, text: String, hold := 1.8) -> void:
	_id += 1
	var id := _id
	portrait.texture = UnitLook.portrait(sheet)
	who.text = name.to_upper()
	line.text = text
	line.visible_characters = 0
	box.visible = true
	var typed := create_tween()
	typed.tween_property(line, "visible_characters", text.length(), text.length() / CHARS_PER_SECOND)
	await typed.finished
	await get_tree().create_timer(hold).timeout
	if id == _id:
		box.visible = false
