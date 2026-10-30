class_name IntroCutscene
extends Cutscene3D
## The opening cutscene on the intro forest (samples/intro_forest.json). Not a battle: no input, no rules.
## It runs on the same 3D board and camera as the battle (Board3D: square-on, a quarter-turn to the right).
##
## The King walks slowly up the path toward the ruins and mutters. Right before the entrance he stops and
## speaks again, then goes in and fades away. As he fades, two Ashen Squires come into the clearing; one walks
## forward and speaks; the scene slowly fades out into the hallway scene (HallwayCutscene). The game starts here.

const MAP := "res://samples/intro_forest.json"
const PATH_ROW := 5  ## the path runs along this row of the map, west to east, up to the ruins
const STOP_X := 7  ## he stops on the terrace in front of the entrance, which is the gap at (8, 5)
const ENTRANCE_X := 9  ## the far end of the entrance corridor: where he disappears
const KING_PORTRAIT := "res://assets/characters/king/portraits/portrait_01.png"
const LINE_MUTTER := "They left me in the dirt. They think the fire finished it."
const LINE_ENTRANCE := "End me here soldiers. If not.. be sure my fire will finish you."
const LINE_SQUIRE := "I smell a hurt rat, I think he went in there!"
const NEXT_SCENE := "res://scenes/hallway.tscn"
const FADE_OUT := 3.5  ## seconds of the slow fade after the squire's line, into the hallway scene

@export var go_on := true  ## false in the checks: stop at the end instead of changing to the hallway scene

var king: UnitView3D
var knights: Array[UnitView3D] = []
var knight_cells: Array[Vector2i] = []
var stopped_cell := Vector2i(-1, -1)  ## where the King stopped to speak at the entrance


func _ready() -> void:
	setup_scene(MAP)
	king = make_unit("king", Vector2i(0, PATH_ROW))
	king.face(board.screen_dir(Vector2i(1, 0), Vector2i(0, PATH_ROW)))
	_run()


## The whole scene, in order. Each step waits for the one before it.
func _run() -> void:
	await fade_to(0.0, 1.2)
	beat.emit("start")
	var cell := Vector2i(0, PATH_ROW)
	for x in range(1, STOP_X + 1):  # a slow walk; he mutters on the way
		if x == 3:
			say(LINE_MUTTER, KING_PORTRAIT)
			beat.emit("dialogue")
		var to := Vector2i(x, PATH_ROW)
		await walk(king, cell, to)
		cell = to
	# right before the entrance he stops and speaks again
	stopped_cell = cell
	beat.emit("stop")
	await say(LINE_ENTRANCE, KING_PORTRAIT)
	# then he goes in and fades away; the squires come into the clearing as he goes
	create_tween().tween_method(king.set_alpha, 1.0, 0.0, STEP * 2.0)
	beat.emit("cave")
	_spawn_knights()
	for x in range(STOP_X + 1, ENTRANCE_X + 1):
		var to := Vector2i(x, PATH_ROW)
		await walk(king, cell, to)
		cell = to
	# one squire walks forward and speaks
	beat.emit("knights")
	var ahead := Vector2i(3, PATH_ROW)
	await walk(knights[0], knight_cells[0], ahead)
	knight_cells[0] = ahead
	beat.emit("knight_line")
	await say(LINE_SQUIRE, "squire")
	beat.emit("fade")
	await fade_to(1.0, FADE_OUT)  # slowly, into the hallway scene (which fades in from black)
	finished.emit()
	if go_on:
		get_tree().change_scene_to_file(NEXT_SCENE)


## Two Ashen Squires are placed in the clearing, faded in, facing up the path.
func _spawn_knights() -> void:
	for cell in [Vector2i(0, PATH_ROW - 1), Vector2i(0, PATH_ROW + 1)]:
		var k := make_unit("squire", cell)
		k.face(board.screen_dir(Vector2i(1, 0), cell))
		k.set_alpha(0.0)
		create_tween().tween_method(k.set_alpha, 0.0, 1.0, 0.8)
		knights.append(k)
		knight_cells.append(cell)
