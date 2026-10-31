class_name Cutscene3D
extends Node3D
## What the story scenes share: the map on the same 3D board and static camera as the battle (Board3D), units
## standing on its tiles (UnitView3D), a black fade, and the dialogue box (portrait and a typed-out line). Not a
## battle: no input, no rules. A scene extends this, calls setup_scene(map) and plays its steps.

signal beat(name: String)  ## a step of the scene was reached (the shot tests save a frame on each)
signal finished

const STEP := 0.9  ## seconds per tile for a slow walk
const CHARS_PER_SECOND := 36.0
const HOLD := 2.2  ## seconds a line stays up after it is typed out

## The game as the last battle left it (set by BattleStage when a story battle is won), for the next battle.
static var carried_game: SaveGame

var board: Board3D
var fade: ColorRect
var box: PanelContainer
var portrait: TextureRect
var line: Label
var _line_id := 0  ## a line hides only if no newer line replaced it


func setup_scene(map_path: String, outside_blur := false) -> void:
	board = Board3D.new()
	board.name = "Board"
	add_child(board)
	board.outside_castle = outside_blur
	board.setup(Terrain.load_map(map_path))
	_lock_camera()
	get_viewport().size_changed.connect(_lock_camera)
	if outside_blur:
		add_child(OutsideBlur.new(board))
	var ui := CanvasLayer.new()
	add_child(ui)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	_build_box(ui)


## The battle's camera position (BattleStage.lock_camera), so a scene and the battle after it look the same.
func _lock_camera() -> void:
	BattleStage.lock_camera(board, get_viewport().get_visible_rect().size)


## Fades the black in (to 1) or out (to 0).
func fade_to(alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", alpha, seconds)
	await tw.finished


## A unit standing on a cell of the board, in the sheet's idle.
func make_unit(sheet: String, cell: Vector2i) -> UnitView3D:
	var v := UnitView3D.new()
	board.add_child(v)
	v.setup(sheet)
	board.add_upright(v)
	v.position = board.top_point(cell.x, cell.y)
	v.play("idle")
	return v


## Turns `v` to look along the grid direction `d` (from `cell`).
func look(v: UnitView3D, d: Vector2i, cell: Vector2i) -> void:
	v.face(board.screen_dir(d, cell))


## Walks `v` from one cell to another, `per_tile` seconds a tile, facing where it goes.
func walk(v: UnitView3D, from: Vector2i, to: Vector2i, per_tile := STEP, anim := "walk") -> void:
	var d := to - from
	look(v, d, from)
	v.play(anim)
	var tw := create_tween()
	tw.tween_property(v, "position", board.top_point(to.x, to.y), per_tile * float(maxi(absi(d.x), absi(d.y))))
	await tw.finished
	v.play("idle")


## A quick jump from one cell to another: a low arc over `seconds`, keeping the way `v` faces (a hop back
## keeps looking at the foe).
func jump(v: UnitView3D, from: Vector2i, to: Vector2i, seconds := 0.3, height := 0.45) -> void:
	var a := board.top_point(from.x, from.y)
	var b := board.top_point(to.x, to.y)
	var tw := create_tween()
	tw.tween_method(func(t: float): v.position = a.lerp(b, t) + Vector3.UP * sin(PI * t) * height, 0.0, 1.0, seconds)
	await tw.finished


## Slides `v` to a cell without walking (knocked back), easing out.
func slide(v: UnitView3D, to: Vector2i, seconds := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(v, "position", board.top_point(to.x, to.y), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tw.finished


## Shows a line in the dialogue box: `who`'s portrait (a character sheet, or a portrait image's path), the
## text typed out, then held and hidden.
func say(text: String, who: String) -> void:
	_line_id += 1
	var id := _line_id
	portrait.texture = load(who) if who.begins_with("res://") else UnitLook.portrait(who)
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
