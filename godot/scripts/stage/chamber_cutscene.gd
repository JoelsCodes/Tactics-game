class_name ChamberCutscene
extends Cutscene3D
## The story's heart, in the ruins' final chamber (samples/ruins_chamber.json), leading straight into the first full
## battle. Not a battle itself: no input, no rules.
##
## Alaric limps in from the entrance. It is a big, dead-end room: nowhere to go. He drags himself to the far wall
## beside the carved altar and slumps there, waiting for the end. Then his bleeding hand falls on the altar and its
## magic answers: a flash, and two spirits step into the world, Bram (iron and a shattered shield) and Lyra
## (a spellweaver). Iron boots echo outside. They talk (the owner's lines, word for word); then the two spirits
## dissolve into the altar's light, two Ashen Squires walk in at the entrance, and the battle (FirstBattle.chamber_setup)
## begins, where Alaric must call them back himself (the summon tutorial).
## Cells are (column, row): the column is the depth (0 is the front wall), the row runs left to right.

const MAP := FirstBattle.CHAMBER
const ENTRANCE := Vector2i(0, 4)  ## the entrance gap in the front wall (rows 3 to 5)
const WALL_SPOT := Vector2i(10, 5)  ## where he slumps: by the far wall, next to the altar
const ALTAR := Vector2i(10, 4)  ## the carved altar block on the dais
const BRAM_AT := Vector2i(10, 6)  ## the three stand in a row along the far wall: Lyra, the altar, Alaric, Bram
const LYRA_AT := Vector2i(10, 3)
const SQUIRES_IN: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, 5)]
const SQUIRES_TO: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 5)]
const SLUMP := 4  ## the frame of the hurt animation that shows him hunched over
## Narration (drafted by Claude, from the owner's staging: the owner can reword it).
const NARRATE_ENTER := "There was nowhere left to run."
const NARRATE_BOOTS := "Heavy iron boots echo down the stone corridor outside."
## The owner's dialogue, word for word.
const LINE_LYRA_1 := "You're calling us with a dying pulse. And you look terrified of what you just did."
const LINE_BRAM := "Kid's running on empty. But there's steel at the door. Do we bleed with him, or go back to the dark?"
const LINE_ALARIC := "We don't bleed. The King took my home. Now we take everything else."
const LINE_LYRA_2 := "...I like his silence. Form ranks."
const LINE_BRAM_WARNING := "You\u0027re half dead, boy. Sit down before you finish the job."
const LINE_ALARIC_FIGHT := "There\u0027s still a fight."
const LINE_LYRA_ALONE := "And you think you have to fight it alone?"
const LINE_ALARIC_HUNTED := "They\u0027re hunting me. Not you."

@export var start_battle := true  ## false in the checks: stop when the battle would start

var king: UnitView3D
var bram: UnitView3D
var lyra: UnitView3D
var squires: Array[UnitView3D] = []
var king_cell := ENTRANCE
var squire_cells: Array[Vector2i] = []


func _ready() -> void:
	setup_scene(MAP, false)
	king = make_unit("king", ENTRANCE)
	look(king, Vector2i(1, 0), ENTRANCE)
	_run()


func _run() -> void:
	await fade_to(0.0, 1.4)
	beat.emit("start")
	# he limps in, down the middle of the room, to the far wall by the altar
	for x in range(1, 9):
		var to := Vector2i(x, ENTRANCE.y)
		if x == 4:
			narrate(NARRATE_ENTER, 1.6)
		await walk(king, king_cell, to, STEP)
		king_cell = to
	await walk(king, king_cell, Vector2i(8, WALL_SPOT.y), STEP)
	await walk(king, Vector2i(8, WALL_SPOT.y), WALL_SPOT, STEP)
	king_cell = WALL_SPOT
	look(king, Vector2i(1, 0), king_cell)
	king.hold("hit", SLUMP)
	beat.emit("sit")
	await get_tree().create_timer(3.0).timeout  # he waits for the end
	# his bleeding hand falls on the altar and its magic answers
	king.release()
	look(king, ALTAR - king_cell, king_cell)
	king.act("cast")
	king.spawn_fx("circle", board.top_point(ALTAR.x, ALTAR.y) + Vector3.UP * 0.1, 1.4)
	await get_tree().create_timer(1.1).timeout
	beat.emit("altar")
	flash(2.2)
	pulse_red(0.8, 0.25)
	king.spawn_fx("burst", board.top_point(ALTAR.x, ALTAR.y) + Vector3.UP * 0.9, 1.6)
	_spawn_vessels()
	await get_tree().create_timer(0.5).timeout
	king.hold("hit", SLUMP)  # his hands stay on the altar
	for v in [bram, lyra]:
		create_tween().tween_method(v.set_alpha, 0.0, 1.0, 1.2)
	await get_tree().create_timer(2.0).timeout
	beat.emit("vessels")
	# iron boots outside
	await narrate(NARRATE_BOOTS, 1.4)
	# the dialogue
	look(lyra, king_cell - LYRA_AT, LYRA_AT)
	beat.emit("lyra")
	await say(LINE_LYRA_1, "mira", "LYRA")
	bram.release()  # he pushes himself up to his full height
	look(bram, king_cell - BRAM_AT, BRAM_AT)
	beat.emit("bram")
	await say(LINE_BRAM, "warden", "BRAM")
	king.release()  # Alaric stands, tall through the pain
	look(king, Vector2i(-1, 0), king_cell)
	beat.emit("alaric")
	await say(LINE_ALARIC, "king", "ALARIC", "angry")
	beat.emit("ranks")
	# Establish Alaric\u0027s reluctance to let others share his burden before the first summon battle.
	await say(LINE_BRAM_WARNING, "warden", "BRAM")
	await say(LINE_ALARIC_FIGHT, "king", "ALARIC", "pained")
	await say(LINE_LYRA_ALONE, "mira", "LYRA")
	await say(LINE_ALARIC_HUNTED, "king", "ALARIC", "worried")
	await say(LINE_LYRA_2, "mira", "LYRA")
	# they dissolve into the altar's light; the squires walk in
	flash(0.9, 0.55)
	for v in [bram, lyra]:
		create_tween().tween_method(v.set_alpha, 1.0, 0.0, 0.7)
	_squires_in()
	await get_tree().create_timer(STEP * 0.7 + 0.9).timeout
	beat.emit("squires")
	finished.emit()
	if start_battle:
		BattleStage.pending_game = FirstBattle.chamber_game(carried_game if carried_game != null else FirstBattle.game())
		carried_game = null
		BattleStage.pending_setup = FirstBattle.chamber_setup(king_cell, squire_cells)
		get_tree().change_scene_to_file("res://scenes/battle.tscn")


## Bram and Lyra step out of the altar's light, faded out until the flash covers it.
func _spawn_vessels() -> void:
	bram = make_unit("warden", BRAM_AT, UnitLook.VESSEL_TINT)
	lyra = make_unit("mira", LYRA_AT, UnitLook.VESSEL_TINT)
	for v in [bram, lyra]:
		v.set_alpha(0.0)
	bram.hold("hit", SLUMP)  # on a knee until he stands
	look(bram, king_cell - BRAM_AT, BRAM_AT)
	look(lyra, king_cell - LYRA_AT, LYRA_AT)


func _squires_in() -> void:
	for i in SQUIRES_IN.size():
		var sq := make_unit("squire", SQUIRES_IN[i])
		look(sq, Vector2i(1, 0), SQUIRES_IN[i])
		sq.set_alpha(0.0)
		create_tween().tween_method(sq.set_alpha, 0.0, 1.0, 0.4)
		squires.append(sq)
		squire_cells.append(SQUIRES_TO[i])
		walk(sq, SQUIRES_IN[i], SQUIRES_TO[i], STEP * 0.7)  # not awaited: both walk in together
