class_name HallwayCutscene
extends Cutscene3D
## The second story scene, in the abandoned castle's hallway (samples/intro_ruins.json), leading straight into
## the first battle.
##
## Alaric limps in from the entrance (hurt and out of breath). Halfway down the hall an Ashen Squire appears at the entrance behind him
## and calls out, then lunges. The King hops back out of reach, leaps forward and slashes; the blow drives the
## squire three tiles back. The battle (FirstBattle) starts with both where they stand.
## Cells are (column, row): the column is the depth (0 is the front wall), the row runs left to right.

const MAP := FirstBattle.MAP
const ENTRANCE := Vector2i(0, 4)  ## the entrance gap in the front wall
const HALFWAY := Vector2i(7, 4)  ## where Alaric is when the squire appears (far down the hall: the battle starts 7 tiles apart)
const DODGE := Vector2i(8, 4)  ## where the King hops back to
const LUNGE_TO := Vector2i(6, 4)  ## where the squire's lunge ends: right behind the King's first spot
const PUSH := 6  ## tiles the King's slash drives the squire back: out of reach of a first turn (see tests/spacing_check.gd)
const LINE_SQUIRE := "Here by the hallway!"

@export var start_battle := true  ## false in the checks: stop when the battle would start

var king: UnitView3D
var squire: UnitView3D
var king_cell := ENTRANCE
var squire_cell := TacticalGrid.NO_CELL


func _ready() -> void:
	setup_scene(MAP, true)  # the castle runs on past the 8x10, out of focus
	king = make_unit("king", ENTRANCE)
	look(king, Vector2i(1, 0), ENTRANCE)
	_run()


func _run() -> void:
	await fade_to(0.0, 1.0)
	beat.emit("start")
	# Alaric limps in, slowly: he is hurt and tired
	for x in range(ENTRANCE.x + 1, HALFWAY.x + 1):
		var to := Vector2i(x, ENTRANCE.y)
		await walk(king, king_cell, to, STEP * 0.95)
		king_cell = to
	# halfway down, a squire appears at the entrance behind him; he turns
	squire_cell = ENTRANCE
	squire = make_unit("squire", squire_cell)
	look(squire, Vector2i(1, 0), squire_cell)
	squire.set_alpha(0.0)
	var appear := create_tween()
	appear.tween_method(squire.set_alpha, 0.0, 1.0, 0.5)
	await appear.finished
	look(king, Vector2i(-1, 0), king_cell)
	beat.emit("squire")
	await say(LINE_SQUIRE, "squire", "ASHEN SQUIRE")
	# the lunge: the squire rushes in and strikes; the King hops back out of reach just in time
	beat.emit("lunge")
	squire.play("run")
	var rush := create_tween()
	rush.tween_property(squire, "position", board.top_point(LUNGE_TO.x, LUNGE_TO.y), 0.7)
	await get_tree().create_timer(0.45).timeout
	await jump(king, king_cell, DODGE, 0.28)
	king_cell = DODGE
	if rush.is_running():  # (awaiting a tween that already ended would wait forever)
		await rush.finished
	squire_cell = LUNGE_TO
	squire.play("idle")
	squire.act("attack")
	beat.emit("dodge")
	await get_tree().create_timer(0.45).timeout
	# the King leaps forward and slashes; the blow drives the squire back
	await jump(king, king_cell, HALFWAY, 0.24, 0.35)
	king_cell = HALFWAY
	king.act("heavy" if king.has_anim("heavy") else "attack")
	await get_tree().create_timer(0.18).timeout
	king.spawn_fx("slash", board.top_point(squire_cell.x, squire_cell.y) + Vector3.UP * 0.9)
	squire.hit_react(squire.position - king.position)
	beat.emit("slash")
	squire_cell = squire_cell - Vector2i(PUSH, 0)
	await slide(squire, squire_cell, 0.8)
	beat.emit("pushed")
	await get_tree().create_timer(0.8).timeout
	finished.emit()
	if start_battle:
		BattleStage.pending_game = FirstBattle.game()
		BattleStage.pending_setup = FirstBattle.setup(king_cell, squire_cell)
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
