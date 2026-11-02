class_name HallwayReturnCutscene
extends Cutscene3D
## After the first battle (the result panel's Continue), in the same hallway: Alaric stands slumped where the fight
## left him, hurt and tired. Iron boots sound from the entrance: more squires are on their way. He looks back,
## straightens, and limps to the doors at the far end of the hall; he goes through and the scene fades out into
## the final chamber (ChamberCutscene). The game he fought with (Cutscene3D.carried_game) is kept for the chamber.
## Cells are (column, row): the column is the depth (0 is the front wall), the row runs left to right.

const MAP := FirstBattle.MAP
const SPOT := Vector2i(4, 4)  ## where he stands when the scene opens
const DOORS := Vector2i(9, 4)  ## the far end of the hall: the doors onto the dark
const SLUMP := 4  ## the frame of the hurt animation that shows him hunched over
## Narration (drafted by Claude: the owner can reword it).
const NARRATION: Array[String] = [
	"Iron boots, on the stone behind him.",
	"More of them. And closer than before.",
]
const NEXT_SCENE := "res://scenes/chamber.tscn"

@export var go_on := true  ## false in the checks: stop at the end instead of changing to the chamber scene

var king: UnitView3D
var king_cell := SPOT


func _ready() -> void:
	setup_scene(MAP)
	king = make_unit("king", SPOT)
	look(king, Vector2i(1, 0), SPOT)
	king.hold("hit", SLUMP)
	_run()


func _run() -> void:
	await fade_to(0.0, 1.2)
	beat.emit("start")
	await get_tree().create_timer(1.6).timeout
	# he hears them coming and looks back down the hall
	beat.emit("boots")
	narrate(NARRATION[0], 1.4)
	await get_tree().create_timer(0.6).timeout
	king.release()
	look(king, Vector2i(-1, 0), king_cell)
	await get_tree().create_timer(2.2).timeout
	await narrate(NARRATION[1], 1.4)
	# then he limps for the far doors
	look(king, Vector2i(1, 0), king_cell)
	for x in range(SPOT.x + 1, DOORS.x + 1):
		var to := Vector2i(x, DOORS.y)
		if x == DOORS.x - 1:
			create_tween().tween_method(king.set_alpha, 1.0, 0.0, STEP * 1.0)
		await walk(king, king_cell, to, STEP)
		king_cell = to
	beat.emit("doors")
	await fade_to(1.0, 1.0)
	finished.emit()
	if go_on:
		get_tree().change_scene_to_file(NEXT_SCENE)
