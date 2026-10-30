class_name HallwayReturnCutscene
extends Cutscene3D
## After the first battle: the King runs in through the hallway's entrance, then walks slowly to the middle
## and speaks. Two more Ashen Squires come in through the entrance; one steps forward and calls out. The second
## battle (FirstBattle.second_setup) starts with everyone where they stand, the King as the first battle left
## him (Cutscene3D.carried_game).
## Cells are (column, row): the column is the depth (0 is the front wall), the row runs left to right.

const MAP := FirstBattle.MAP
const ENTRANCE := Vector2i(0, 4)  ## the entrance gap in the front wall (rows 3 and 4)
const RUN_TO := Vector2i(2, 4)  ## he runs in this far, then walks
const MIDDLE := Vector2i(4, 4)  ## the middle of the hallway
const SQUIRES_IN: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, 4)]  ## where the two squires come in
const SQUIRES_TO: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 4)]  ## a step inside the hall
const STEP_FORWARD := Vector2i(2, 4)  ## where the squire who speaks steps to
const LINE_KING := "I will not falter here"
const LINE_SQUIRE := "You stop!"
const KING_PORTRAIT := "res://assets/characters/king/portraits/portrait_01.png"

@export var start_battle := true  ## false in the checks: stop when the battle would start

var king: UnitView3D
var squires: Array[UnitView3D] = []
var king_cell := ENTRANCE
var squire_cells: Array[Vector2i] = []


func _ready() -> void:
	setup_scene(MAP)
	king = make_unit("king", ENTRANCE)
	look(king, Vector2i(1, 0), ENTRANCE)
	_run()


func _run() -> void:
	await fade_to(0.0, 0.8)
	beat.emit("start")
	# he runs in through the entrance...
	await walk(king, king_cell, RUN_TO, 0.2, "run")
	king_cell = RUN_TO
	# ...then walks slowly to the middle and speaks
	for x in range(RUN_TO.x + 1, MIDDLE.x + 1):
		var to := Vector2i(x, MIDDLE.y)
		await walk(king, king_cell, to)
		king_cell = to
	beat.emit("middle")
	await say(LINE_KING, KING_PORTRAIT)
	# two more squires come in through the entrance; he turns to them
	for i in SQUIRES_IN.size():
		var sq := make_unit("squire", SQUIRES_IN[i])
		look(sq, Vector2i(1, 0), SQUIRES_IN[i])
		sq.set_alpha(0.0)
		create_tween().tween_method(sq.set_alpha, 0.0, 1.0, 0.4)
		squires.append(sq)
		squire_cells.append(SQUIRES_IN[i])
	look(king, Vector2i(-1, 0), king_cell)
	for i in squires.size():
		walk(squires[i], SQUIRES_IN[i], SQUIRES_TO[i], STEP * 0.7)  # not awaited: both walk in together
		squire_cells[i] = SQUIRES_TO[i]
	await get_tree().create_timer(STEP * 0.7 + 0.1).timeout
	beat.emit("squires")
	# one steps forward and calls out
	await walk(squires[1], squire_cells[1], STEP_FORWARD, STEP * 0.7)
	squire_cells[1] = STEP_FORWARD
	beat.emit("stop")
	await say(LINE_SQUIRE, "squire")
	finished.emit()
	if start_battle:
		BattleStage.pending_game = carried_game if carried_game != null else FirstBattle.game()
		carried_game = null
		BattleStage.pending_setup = FirstBattle.second_setup(king_cell, squire_cells)
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
