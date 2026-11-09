class_name IntroCutscene
extends Cutscene3D
## The opening cutscene on the intro forest (samples/intro_forest.json). Not a battle: no input, no rules.
## It runs on the same 3D board and camera as the battle (Board3D: square-on, a quarter-turn to the right).
##
## Alaric is hunted. Two lines of narration over the dark (his village burned, his family dead), then the forest:
## he runs along the path toward the ruins, but he is hurt and weak. His wound gives out, he stumbles and slumps (a
## red pulse), then limps on. Two Ashen Squires come running into the clearing behind him; he looks back and
## runs for the entrance, and goes in. The squires reach the middle of the path and lose him; one calls out that
## he went in there. The scene slowly fades out into the hallway scene (HallwayCutscene).

const MAP := "res://samples/intro_forest.json"
const PATH_ROW := 5  ## the path runs along this row of the map, west to east, up to the ruins
const STUMBLE_X := 2  ## where his wound gives out
const LIMP_TO_X := 4  ## how far he limps before he hears them
const ENTRANCE_X := 9  ## the far end of the entrance corridor (the entrance gap is at (8, 5)): where he disappears
## Narration (drafted by Claude: the owner can reword it).
const NARRATION: Array[String] = [
	"The village burned through the night.",
	"Alaric was the only one who walked out of it.",
]
const LINE_SQUIRE := "I smell a hurt rat, I think he went in there!"
const NEXT_SCENE := "res://scenes/hallway.tscn"
const FADE_OUT := 3.5  ## seconds of the slow fade after the squire's line, into the hallway scene
const SLUMP := 4  ## the frame of the hurt animation that shows him hunched over, worn out

@export var go_on := true  ## false in the checks: stop at the end instead of changing to the hallway scene

var king: UnitView3D
var knights: Array[UnitView3D] = []
var knight_cells: Array[Vector2i] = []
var stumble_cell := Vector2i(-1, -1)  ## where he stumbled


func _ready() -> void:
	setup_scene(MAP)
	king = make_unit("king", Vector2i(0, PATH_ROW))
	king.face(board.screen_dir(Vector2i(1, 0), Vector2i(0, PATH_ROW)))
	_run()


## The whole scene, in order. Each step waits for the one before it.
func _run() -> void:
	for text in NARRATION:
		await narrate(text, 1.8)
	await fade_to(0.0, 1.6)
	beat.emit("start")
	var cell := Vector2i(0, PATH_ROW)
	# he runs, already slow for a run
	for x in range(1, STUMBLE_X + 1):
		var to := Vector2i(x, PATH_ROW)
		await walk(king, cell, to, 0.42, "run")
		cell = to
	beat.emit("run")
	# his wound gives out: he stumbles and slumps
	stumble_cell = cell
	king.hold("hit", SLUMP)
	pulse_red(1.4)
	beat.emit("stumble")
	await get_tree().create_timer(1.8).timeout
	# he gets up and limps on
	king.release()
	for x in range(STUMBLE_X + 1, LIMP_TO_X + 1):
		var to := Vector2i(x, PATH_ROW)
		await walk(king, cell, to, 1.05)
		cell = to
	beat.emit("limp")
	# the squires come into the clearing behind him; he looks back
	_spawn_knights()
	look(king, Vector2i(-1, 0), cell)
	await get_tree().create_timer(0.7).timeout
	beat.emit("hunted")
	for i in knights.size():
		var ahead := Vector2i(3, knight_cells[i].y)
		walk(knights[i], knight_cells[i], ahead, 0.3, "run")  # not awaited: they run together
		knight_cells[i] = ahead
	await get_tree().create_timer(0.35).timeout
	# he runs for the entrance and goes in
	for x in range(LIMP_TO_X + 1, ENTRANCE_X + 1):
		var to := Vector2i(x, PATH_ROW)
		if x == ENTRANCE_X - 1:  # into the dark of the corridor
			create_tween().tween_method(king.set_alpha, 1.0, 0.0, 0.36 * 2.0)
		await walk(king, cell, to, 0.36, "run")
		cell = to
	beat.emit("cave")
	# they lose him: one steps up the path and calls out
	await get_tree().create_timer(0.8).timeout
	await walk(knights[0], knight_cells[0], Vector2i(4, knight_cells[0].y), 0.5)
	knight_cells[0] = Vector2i(4, knight_cells[0].y)
	beat.emit("knights")
	await say(LINE_SQUIRE, "squire", "ASHEN SQUIRE")
	beat.emit("fade")
	await fade_to(1.0, FADE_OUT)  # slowly, into the hallway scene (which fades in from black)
	finished.emit()
	if go_on:
		get_tree().change_scene_to_file(NEXT_SCENE)


## Two Ashen Squires are placed at the edge of the clearing, faded in, facing up the path.
func _spawn_knights() -> void:
	for cell in [Vector2i(0, PATH_ROW - 1), Vector2i(0, PATH_ROW + 1)]:
		var k := make_unit("squire", cell)
		k.face(board.screen_dir(Vector2i(1, 0), cell))
		k.set_alpha(0.0)
		create_tween().tween_method(k.set_alpha, 0.0, 1.0, 0.3)
		knights.append(k)
		knight_cells.append(cell)
