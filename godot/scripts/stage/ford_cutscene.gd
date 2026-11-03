class_name FordCutscene
extends Cutscene3D
## The story scene the world map plays the first time Riverbank level 1 (The Ford) is picked (WorldData.CUTSCENES). Not a battle: no
## input, no rules. A town centre on a 19x19 map (samples/ford_town.json, tools/make_ford_town_map.py) with villagers and the
## mechanic running about. In the middle of the plaza Merc, a trader, stands two tiles from Vesper, who has two Ashen Squires behind;
## Merc confronts Vesper about the burned village, Vesper steps forward, Merc steps back and walks away out of the town and
## vanishes, Vesper sends the squires after Merc, and the scene fades out to the world map. It marks itself seen
## (CampaignState.scenes_seen), so the next time the level is picked the battle loads.
## The dialogue is the owner's, word for word.
## Cells are (column, row): the column is the depth (0 is the front of the map), the row runs left to right.

const MAP := "res://samples/ford_town.json"
const MERC_AT := Vector2i(9, 8)
const VESPER_AT := Vector2i(9, 10)  ## two tiles from Merc, with the carved medallion (9, 9) between them
const SQUIRES_AT: Array[Vector2i] = [Vector2i(8, 11), Vector2i(10, 11)]  ## behind Vesper
const MERC_BACK := Vector2i(9, 7)
const MERC_EXIT := Vector2i(9, 0)  ## the west street leaves the map here
const NEXT_SCENE := "res://scenes/world_map.tscn"
const SCENE_ID := &"ford_intro"
const WEST := Vector2i(0, -1)  ## the board direction toward the left of the screen
const EAST := Vector2i(0, 1)
const RUN := 0.3  ## seconds per tile for the townsfolk
## The stage: villagers keep out of it (and out of the way of the walk Merc leaves by).
const STAGE := Rect2i(5, 5, 8, 9)
## [speaker, sheet, text]
const L_MERC_1 := "I saw it. We gathered resources for the little village and your men just burned it for no good reason!"
const L_MERC_2 := "We have raised hundreds to gather supplies to bring to all these places and for what!"
const L_MERC_3 := "Not even the best we had was good enough to rescue one person!"
const L_VESPER_1 := "Now now, we can help you find new people to support. Why, the world is a place full of those who need help."
const L_MERC_4 := "I must have lost myself for a second there, apologies. I have just never seen so many bodies in my life."
const L_VESPER_2 := "Yes that must be a terrible sight, it's unfortunate they were all criminals. Justice has prevailed. Why don't you come with us and we can set you up with a new trading route?"
const L_MERC_5 := "Actually I've already embarrassed myself enough. I will take my leave sorry for the misunderstanding."
const L_VESPER_3 := "Oliver wouldn't want to have this news spread. Follow him and solve the issue."

## The townsfolk: [sheet, start cell]. Four villagers and the mechanic.
const FOLK: Array = [
	[NpcLook.MAN, Vector2i(5, 3)], [NpcLook.GIRL, Vector2i(12, 14)], [NpcLook.KID, Vector2i(4, 9)], [NpcLook.KID, Vector2i(16, 9)],
	[NpcLook.MAN, Vector2i(9, 17)], [NpcLook.MECHANIC, Vector2i(9, 14)],
]

@export var go_on := true  ## false in the checks: stop at the end instead of changing to the world map

var merc: UnitView3D
var vesper: UnitView3D
var squires: Array[UnitView3D] = []
var folk: Array[UnitView3D] = []
var _busy := true  ## the townsfolk keep running while the scene plays
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 41
	setup_scene(MAP)
	merc = make_unit("merc", MERC_AT)
	vesper = make_unit("vesper", VESPER_AT)
	look(merc, EAST, MERC_AT)
	look(vesper, WEST, VESPER_AT)
	for c in SQUIRES_AT:
		var s := make_unit("squire", c)
		look(s, WEST, c)
		squires.append(s)
	for f in FOLK:
		var v := make_unit(f[0], f[1])
		folk.append(v)
		_wander(v, f[1])
	_run()


func _run() -> void:
	await fade_to(0.0, 1.4)
	beat.emit("start")
	await get_tree().create_timer(1.2).timeout
	# Merc confronts Vesper
	beat.emit("merc1")
	await say(L_MERC_1, "merc", "MERC")
	beat.emit("merc2")
	await say(L_MERC_2, "merc", "MERC")
	beat.emit("merc3")
	await say(L_MERC_3, "merc", "MERC")
	# Vesper takes one step forward
	var vesper_at := VESPER_AT + WEST
	await _step(vesper, VESPER_AT, vesper_at)
	beat.emit("step")
	await say(L_VESPER_1, "vesper", "VESPER")
	beat.emit("merc4")
	await say(L_MERC_4, "merc", "MERC")
	beat.emit("vesper2")
	await say(L_VESPER_2, "vesper", "VESPER")
	# Merc takes one step back
	await _step(merc, MERC_AT, MERC_BACK, true)
	beat.emit("back")
	await say(L_MERC_5, "merc", "MERC")
	# Merc walks away and vanishes
	beat.emit("leaves")
	await _leave(merc, MERC_BACK, MERC_EXIT)
	merc.visible = false
	beat.emit("gone")
	# Vesper turns to the squires
	look(vesper, EAST, vesper_at)
	beat.emit("orders")
	await say(L_VESPER_3, "vesper", "VESPER")
	# the squires set off after Merc as the scene fades out to the world map
	beat.emit("end")
	for i in squires.size():
		_follow(squires[i], SQUIRES_AT[i])
	var game := carried_game if carried_game != null else GameSession.current()
	GameSession.game = game
	game.campaign.mark_scene_seen(SCENE_ID)
	GameSession.autosave()
	await fade_to(1.0, 1.6)
	_busy = false
	finished.emit()
	if go_on:
		get_tree().change_scene_to_file(NEXT_SCENE)


## One step from a cell to the next, at a walking pace. `keep_facing`: a step back, still looking at the one in front.
func _step(v: UnitView3D, from: Vector2i, to: Vector2i, keep_facing := false) -> void:
	if not keep_facing:
		look(v, to - from, from)
	v.play("walk")
	var tw := create_tween()
	tw.tween_property(v, "position", board.top_point(to.x, to.y), STEP * 0.7)
	await tw.finished
	v.play("idle")


## Walks `v` along the street and out of the picture: it fades over the last two tiles.
func _leave(v: UnitView3D, from: Vector2i, to: Vector2i) -> void:
	look(v, to - from, from)
	v.play("walk")
	var tiles := float(maxi(absi(to.x - from.x), absi(to.y - from.y)))
	var total := STEP * 0.6 * tiles
	var fade_for := STEP * 0.6 * 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(v, "position", board.top_point(to.x, to.y), total)
	tw.tween_method(v.set_alpha, 1.0, 0.0, fade_for).set_delay(total - fade_for)
	await tw.finished


## A squire sets off after Merc, at a run along its row to the west street.
func _follow(v: UnitView3D, from: Vector2i) -> void:
	look(v, WEST, from)
	v.play("run")
	var tw := create_tween()
	tw.tween_property(v, "position", board.top_point(from.x, 0), RUN * float(from.y))


# ---- the townsfolk

## Running about for the whole scene: pick a spot out of the stage, run there by the open ground, stop a moment, repeat.
func _wander(v: UnitView3D, from: Vector2i) -> void:
	var at := from
	await get_tree().create_timer(_rng.randf_range(0.0, 1.2)).timeout
	while _busy and is_inside_tree():
		var goal := _pick_goal(at)
		var path := _path(at, goal)
		if path.size() > 1:
			await _run_path(v, path)
			at = goal
		v.play("idle")
		await get_tree().create_timer(_rng.randf_range(0.3, 1.4)).timeout


func _pick_goal(from: Vector2i) -> Vector2i:
	var open: Array[Vector2i] = []
	for y in board.map.d:
		for x in board.map.w:
			var c := Vector2i(x, y)
			if _open(c) and not STAGE.has_point(c) and absi(c.x - from.x) + absi(c.y - from.y) >= 4:
				open.append(c)
	return open[_rng.randi() % open.size()]


## Ground a villager may run over: flat open tiles (streets, plaza, grass), never a wall, roof, the fountain, a tree or the stage.
func _open(c: Vector2i) -> bool:
	if not board.in_bounds(c):
		return false
	var t: Dictionary = board.map.tiles[c.y][c.x]
	return t.t in ["g", "d", "s", "e", "f"] and t.h <= 1


## Shortest way by open ground, a step at a time, round the stage. The first cell is `from`.
func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if c == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if prev.has(n) or not _open(n) or STAGE.has_point(n):
				continue
			if absi(board.map.tiles[n.y][n.x].h - board.map.tiles[c.y][c.x].h) > 1:
				continue
			prev[n] = c
			q.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var c := to
	while c != from:
		out.push_front(c)
		c = prev[c]
	out.push_front(from)
	return out


func _run_path(v: UnitView3D, path: Array[Vector2i]) -> void:
	v.play("run")
	for i in range(1, path.size()):
		if not _busy or not is_inside_tree():
			return
		look(v, path[i] - path[i - 1], path[i - 1])
		v.play("run")
		var tw := create_tween()
		tw.tween_property(v, "position", board.top_point(path[i].x, path[i].y), RUN)
		await tw.finished
