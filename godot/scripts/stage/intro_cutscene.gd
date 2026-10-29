class_name IntroCutscene
extends Node2D
## The opening cutscene on the intro forest (samples/intro_forest.json). Not a battle: no input, no rules.
## The King walks slowly from the clearing toward the ruins, mutters, and goes into the cave. As he nears
## it, two knights come out of the clearing; one speaks; the scene fades out as they step forward.

signal beat(name: String)  ## a step of the scene was reached (the shot test saves a frame on each)
signal finished

const MAP := "res://samples/intro_forest.json"
const STEP := 0.9  ## seconds per tile for the King's slow walk
const KING_PORTRAIT := "res://assets/characters/king/portraits/portrait_01.png"
const KING_LINE := "They will regret not striking me down."
const KNIGHT_LINE := "Ay, seems to me the rat went this way!"
const CHARS_PER_SECOND := 36.0
const HOLD := 2.2  ## seconds a line stays up after it is typed out

var terrain: Terrain
var king: Character
var knights: Array[Character] = []
var fade: ColorRect
var box: PanelContainer
var portrait: TextureRect
var line: Label
var _line_id := 0  ## a line hides only if no newer line replaced it


func _ready() -> void:
	var m := Terrain.load_map(MAP)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.show_map(m)
	var cam := Camera2D.new()
	add_child(cam)
	cam.position = terrain.stand_point(m.w / 2.0, m.d / 2.0)
	cam.zoom = Vector2.ONE * clampf(get_viewport_rect().size.x / ((m.w + m.d) * Terrain.TW * .62), .45, 2.4)
	cam.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	_build_box(ui)
	king = Character.new()
	terrain.field.add_child(king)
	king.setup("king")
	king.position = terrain.stand_point(0, 5)
	king.face(terrain.stand_point(1, 5) - king.position)
	king.play("idle")
	_run()


## The whole scene, in order. Each step waits for the one before it.
func _run() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 1.2)
	await tw.finished
	beat.emit("start")
	for x in range(1, 9):  # to the cave's mouth at (8, 5); the last step goes in
		if x == 3:
			_say(KING_LINE, KING_PORTRAIT)
			beat.emit("dialogue")
		if x == 6:
			_spawn_knights()
			beat.emit("knights")
		if x == 8:
			_walk_knights()
		await _walk(king, terrain.stand_point(x, 5))
	beat.emit("cave")
	var door := terrain.stand_point(9, 5)
	var fading := create_tween()
	fading.tween_property(king, "modulate:a", 0.0, 0.8)
	await _walk(king, door)  # the fade (0.8 s) ends within the 0.9 s step
	await get_tree().create_timer(1.0).timeout
	_say(KNIGHT_LINE, "knight")
	beat.emit("knight_line")
	await get_tree().create_timer(HOLD + 1.0).timeout
	beat.emit("fade")
	var out := create_tween()
	out.tween_property(fade, "modulate:a", 1.0, 1.6)
	for k in knights:
		_step_forward(k)
	await out.finished
	finished.emit()


## A knight is placed in the clearing, faded in.
func _spawn_knights() -> void:
	for cell in [Vector2i(0, 4), Vector2i(0, 6)]:
		var k := Character.new()
		terrain.field.add_child(k)
		k.setup("knight")
		k.position = terrain.stand_point(cell.x, cell.y)
		k.modulate.a = 0.0
		k.face(terrain.stand_point(1, 5) - k.position)
		k.play("idle")
		knights.append(k)
		create_tween().tween_property(k, "modulate:a", 1.0, 0.8)


## The knights walk up the path toward the cave, while the King is still going in.
func _walk_knights() -> void:
	for i in knights.size():
		_walk(knights[i], terrain.stand_point(4, 5 + i))


## One knight steps toward the viewer (one tile down-screen, on both grid axes).
func _step_forward(k: Character) -> void:
	var to := k.position + terrain.stand_point(1, 1) - terrain.stand_point(0, 0)
	k.face(to - k.position)
	k.play("walk")
	create_tween().tween_property(k, "position", to, 1.4)


## Walks `ch` to `to` at STEP seconds per tile, facing where it goes.
func _walk(ch: Character, to: Vector2) -> void:
	var from := ch.position
	ch.face(to - from)
	ch.play("walk")
	var tw := create_tween()
	tw.tween_property(ch, "position", to, STEP)
	await tw.finished
	ch.play("idle")


## Shows a line in the dialogue box: the portrait, the text typed out, then held and hidden.
func _say(text: String, who: String) -> void:
	_line_id += 1
	var id := _line_id
	portrait.texture = load(KING_PORTRAIT) if who == KING_PORTRAIT else UnitLook.portrait("knight")
	line.text = text
	line.visible_characters = 0
	box.visible = true
	var typed := create_tween()
	typed.tween_property(line, "visible_characters", text.length(), text.length() / CHARS_PER_SECOND)
	await typed.finished
	await get_tree().create_timer(HOLD).timeout
	if id == _line_id:
		box.visible = false


## The dialogue box, framed like the battle HUD's panels and portraits.
func _build_box(ui: CanvasLayer) -> void:
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", HudStyle.panel())
	box.anchor_left = .5
	box.anchor_right = .5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -600
	box.offset_right = 600
	box.offset_top = -300
	box.offset_bottom = -48
	box.visible = false
	ui.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", HudStyle.portrait_box(Color(0.85, 0.72, 0.45)))
	frame.custom_minimum_size = Vector2(200, 200)
	row.add_child(frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(190, 190)
	frame.add_child(portrait)
	line = Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_theme_font_override("font", HudStyle.font())
	line.add_theme_font_size_override("font_size", 34)
	row.add_child(line)
