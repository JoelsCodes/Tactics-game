class_name IntroCutscene
extends Node3D
## The opening cutscene on the intro forest (samples/intro_forest.json). Not a battle: no input, no rules.
## It runs on the same 3D board and camera as the battle (Board3D: square-on, a quarter-turn to the right).
##
## The King walks slowly up the path toward the ruins and mutters. Right before the entrance he stops and
## speaks again, then goes in and fades away. As he fades, two Ashen Squires come into the clearing; one walks
## forward and speaks; the scene fades out.

signal beat(name: String)  ## a step of the scene was reached (the shot test saves a frame on each)
signal finished

const MAP := "res://samples/intro_forest.json"
const STEP := 0.9  ## seconds per tile for the King's slow walk
const PATH_ROW := 5  ## the path runs along this row of the map, west to east, up to the ruins
const STOP_X := 7  ## he stops on the terrace in front of the entrance, which is the gap at (8, 5)
const ENTRANCE_X := 9  ## the far end of the entrance corridor: where he disappears
const KING_PORTRAIT := "res://assets/characters/king/portraits/portrait_01.png"
const LINE_MUTTER := "They left me in the dirt. They think the fire finished it."
const LINE_ENTRANCE := "End me here soldiers. If not.. be sure my fire will finish you."
const LINE_SQUIRE := "I smell a hurt rat, I think he went in there!"
const CHARS_PER_SECOND := 36.0
const HOLD := 2.2  ## seconds a line stays up after it is typed out

var board: Board3D
var king: UnitView3D
var knights: Array[UnitView3D] = []
var knight_cells: Array[Vector2i] = []
var stopped_cell := Vector2i(-1, -1)  ## where the King stopped to speak at the entrance
var fade: ColorRect
var box: PanelContainer
var portrait: TextureRect
var line: Label
var _line_id := 0  ## a line hides only if no newer line replaced it


func _ready() -> void:
	board = Board3D.new()
	board.name = "Board"
	add_child(board)
	board.setup(Terrain.load_map(MAP))
	board.frame_board()
	get_viewport().size_changed.connect(board.frame_board)
	var ui := CanvasLayer.new()
	add_child(ui)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	_build_box(ui)
	king = _make_unit("king", Vector2i(0, PATH_ROW))
	king.face(board.screen_dir(Vector2i(1, 0), Vector2i(0, PATH_ROW)))
	_run()


## The whole scene, in order. Each step waits for the one before it.
func _run() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 1.2)
	await tw.finished
	beat.emit("start")
	var cell := Vector2i(0, PATH_ROW)
	for x in range(1, STOP_X + 1):  # a slow walk; he mutters on the way
		if x == 3:
			_say(LINE_MUTTER, KING_PORTRAIT)
			beat.emit("dialogue")
		var to := Vector2i(x, PATH_ROW)
		await _walk(king, cell, to)
		cell = to
	# right before the entrance he stops and speaks again
	stopped_cell = cell
	beat.emit("stop")
	await _say(LINE_ENTRANCE, KING_PORTRAIT)
	# then he goes in and fades away; the squires come into the clearing as he goes
	create_tween().tween_method(king.set_alpha, 1.0, 0.0, STEP * 2.0)
	beat.emit("cave")
	_spawn_knights()
	for x in range(STOP_X + 1, ENTRANCE_X + 1):
		var to := Vector2i(x, PATH_ROW)
		await _walk(king, cell, to)
		cell = to
	# one squire walks forward and speaks
	beat.emit("knights")
	var ahead := Vector2i(3, PATH_ROW)
	await _walk(knights[0], knight_cells[0], ahead)
	knight_cells[0] = ahead
	beat.emit("knight_line")
	await _say(LINE_SQUIRE, "squire")
	beat.emit("fade")
	var out := create_tween()
	out.tween_property(fade, "modulate:a", 1.0, 1.6)
	await out.finished
	finished.emit()


## A unit standing on a cell of the board, in the sheet's idle.
func _make_unit(sheet: String, cell: Vector2i) -> UnitView3D:
	var v := UnitView3D.new()
	board.add_child(v)
	v.setup(sheet)
	board.add_upright(v)
	v.position = board.top_point(cell.x, cell.y)
	v.play("idle")
	return v


## Two Ashen Squires are placed in the clearing, faded in, facing up the path.
func _spawn_knights() -> void:
	for cell in [Vector2i(0, PATH_ROW - 1), Vector2i(0, PATH_ROW + 1)]:
		var k := _make_unit("squire", cell)
		k.face(board.screen_dir(Vector2i(1, 0), cell))
		k.set_alpha(0.0)
		create_tween().tween_method(k.set_alpha, 0.0, 1.0, 0.8)
		knights.append(k)
		knight_cells.append(cell)


## Walks `v` from one cell to another, STEP seconds per tile, facing where it goes.
func _walk(v: UnitView3D, from: Vector2i, to: Vector2i) -> void:
	var d := to - from
	v.face(board.screen_dir(d, from))
	v.play("walk")
	var tw := create_tween()
	tw.tween_property(v, "position", board.top_point(to.x, to.y), STEP * float(maxi(absi(d.x), absi(d.y))))
	await tw.finished
	v.play("idle")


## Shows a line in the dialogue box: the portrait, the text typed out, then held and hidden.
func _say(text: String, who: String) -> void:
	_line_id += 1
	var id := _line_id
	portrait.texture = load(KING_PORTRAIT) if who == KING_PORTRAIT else UnitLook.portrait("squire")
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
