class_name StoryScene
extends Cutscene3D
## Plays one of chapter two's story scenes from data (RiverfordStory.scene): a map on the same 3D board and camera as the battles, units that
## walk, talk and act, narration cards, a chapter title, letterbox bars, colour tints, flashes and shakes. The steps are arrays, run in order:
##
##   ["fade", alpha, secs]            black overlay to alpha          ["wait", secs]              ["beat", name]  a frame mark for the shot tests
##   ["title", big, small, hold]      a chapter card                  ["narrate", text, hold]     a line of narration over the scene
##   ["bars", on]                     letterbox bars in or out        ["tint", "#rrggbb", alpha, secs]   a colour wash over the scene
##   ["spawn", id, sheet, cell, dir, {tint, alpha}]   puts a unit on the map (tint "vessel" is the spectral blue)
##   ["say", id, name, text]          a line in the dialogue box, portrait of the unit `id`
##   ["walk", id, cell|[cells], {anim, t, par}]   walks (anim "walk" or "run", t seconds a tile); par: true does not wait (["join"] does)
##   ["look", id, dir]  ["play", id, anim]  ["act", id, anim]  ["hold", id, anim, frame]  ["hide", id]  ["show", id]
##   ["fadeout", id, secs]  ["fadein", id, secs]  ["jump", id, cell]  ["slide", id, cell]  ["fx", id, effect, size]  ["bubble", id, text]
##   ["flash"]  ["red"]  ["shake", strength, secs]  ["give_merc"]  ["join"]
## A cell is [x, y] (x is the depth, up the screen; y runs left to right) or "@king", "@captain", "@stoneN", "@enemyN" (a battle's start cells).
## A direction is "N" (up the screen), "S", "E" (right) or "W" (left). When the steps end the scene marks itself seen (the first time only plays
## once per save), then starts the battle that follows (`then_battle`) or goes back to the world map.

## Set by WorldData before the scene loads.
static var queued := ""  ## the scene's key (RiverfordStory)
static var then_battle: BattleSetup  ## the battle the scene leads into (null: back to the world map)

const DIRS := {"N": Vector2i(1, 0), "S": Vector2i(-1, 0), "E": Vector2i(0, 1), "W": Vector2i(0, -1)}
const WORLD_MAP := "res://scenes/world_map.tscn"
const BAR_HEIGHT := 84.0

@export var go_on := true  ## false in the checks: stop at the end instead of changing scene
@export var key := ""

var data: Dictionary
var units := {}  ## id -> UnitView3D
var sheets := {}  ## id -> character sheet
var cells := {}  ## id -> Vector2i
var spawns: Dictionary = {}
var bars: Array[ColorRect] = []
var wash: ColorRect
var scrim: ColorRect  ## the dark band behind narration
var title_big: Label
var title_small: Label
var _pending := 0  ## parallel walks that have not finished
var _busy := true  ## the townsfolk keep moving while the scene plays
var _rng := RandomNumberGenerator.new()
var _folk: Array[UnitView3D] = []


func _ready() -> void:
	_rng.seed = 41
	if key == "":
		key = queued
	data = RiverfordStory.scene(key)
	var map_path: String = data.map
	setup_scene(map_path)
	if data.has("grade"):
		board.set_grade(String(data.grade))
	if data.has("haze"):
		board.set_haze(String(data.haze))
	spawns = JSON.parse_string(FileAccess.get_file_as_string(map_path)).get("spawns", {})
	_build_overlays()
	for f in data.get("folk", []):
		var v := make_unit(f[0], _cell(f[1]))
		_folk.append(v)
		_wander(v, _cell(f[1]))
	_run()


func _run() -> void:
	for step in data.steps:
		await _exec(step)
	await _finish()


func _finish() -> void:
	await join()
	_busy = false
	var game := carried_game if carried_game != null else GameSession.current()
	GameSession.game = game
	if data.get("id", "") != "":
		game.campaign.mark_scene_seen(StringName(data.id))
	GameSession.autosave()
	finished.emit()
	if not go_on:
		return
	if then_battle != null:
		var s := then_battle
		then_battle = null
		BattleStage.pending_game = game
		BattleStage.pending_setup = s
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	else:
		get_tree().change_scene_to_file(WORLD_MAP)


func _exec(step: Array) -> void:
	match step[0]:
		"fade":
			await fade_to(float(step[1]), float(step[2]))
		"wait":
			await get_tree().create_timer(float(step[1])).timeout
		"beat":
			beat.emit(String(step[1]))
		"title":
			await _title(String(step[1]), String(step[2]), float(step[3]))
		"narrate":
			await narrate(String(step[1]), float(step[2]) if step.size() > 2 else 3.0)
		"bars":
			await _bars(bool(step[1]))
		"tint":
			var tw := create_tween()
			tw.tween_property(wash, "color", Color(String(step[1]), float(step[2])), float(step[3]))
			await tw.finished
		"spawn":
			_spawn(step)
		"say":
			var id := String(step[1])
			await say(String(step[3]), sheets.get(id, id), String(step[2]))
		"walk":
			var opts: Dictionary = step[3] if step.size() > 3 else {}
			if opts.get("par", false):
				_pending += 1
				_walk(String(step[1]), step[2], opts)
			else:
				await _walk(String(step[1]), step[2], opts)
		"join":
			await join()
		"look":
			var id2 := String(step[1])
			look(units[id2], DIRS[String(step[2])], cells[id2])
		"play":
			units[String(step[1])].play(String(step[2]))
		"act":
			units[String(step[1])].act(String(step[2]))
		"hold":
			units[String(step[1])].hold(String(step[2]), int(step[3]))
		"hide":
			units[String(step[1])].visible = false
		"show":
			units[String(step[1])].visible = true
		"fadeout", "fadein":
			var u: UnitView3D = units[String(step[1])]
			var tw2 := create_tween()
			tw2.tween_method(u.set_alpha, u.get_alpha(), 0.0 if step[0] == "fadeout" else 1.0, float(step[2]))
			await tw2.finished
		"jump":
			var jid := String(step[1])
			var to := _cell(step[2])
			await jump(units[jid], cells[jid], to, 0.38, 0.6)
			cells[jid] = to
		"slide":
			var sid := String(step[1])
			var sto := _cell(step[2])
			await slide(units[sid], sto, 0.45)
			cells[sid] = sto
		"fx":
			var fu: UnitView3D = units[String(step[1])]
			var node := fu.spawn_fx(String(step[2]), fu.position + Vector3(0, 0.1, 0), float(step[3]) if step.size() > 3 else 1.0)
			if node == null:  # the unit's sheet has no such effect: borrow Alaric's
				var k := UnitView3D.new()
				board.add_child(k)
				k.setup("king")
				k.visible = false
				k.spawn_fx(String(step[2]), fu.position + Vector3(0, 0.1, 0), float(step[3]) if step.size() > 3 else 1.0)
				get_tree().create_timer(2.0).timeout.connect(k.queue_free)
		"bubble":
			_bubble(units[String(step[1])], String(step[2]))
		"flash":
			await flash(1.3, 0.9)
		"red":
			await pulse_red(1.0, 0.4)
		"shake":
			await _shake(float(step[1]), float(step[2]))
		"give_merc":
			var game := carried_game if carried_game != null else GameSession.current()
			Riverford.add_merc(game)
		_:
			push_error("StoryScene: unknown step " + str(step[0]))


## A unit's cell argument: [x, y], or "@king", "@captain", "@stone1", "@enemy2".
func _cell(v) -> Vector2i:
	if v is String:
		var s: String = v
		if s == "@king":
			return Riverford.cell(spawns.king)
		if s == "@captain":
			return Riverford.cell(spawns.captain)
		if s.begins_with("@stone"):
			return Riverford.cell(spawns.stones[int(s.substr(6))])
		if s.begins_with("@enemy"):
			return Riverford.cell(spawns.enemies[int(s.substr(6))].at)
	return Vector2i(int(v[0]), int(v[1]))


func _spawn(step: Array) -> void:
	var id := String(step[1])
	var opts: Dictionary = step[5] if step.size() > 5 else {}
	var tint := Color(1, 1, 1, 0)
	if opts.get("tint", "") == "vessel":
		tint = UnitLook.VESSEL_TINT
	elif opts.get("tint", "") == "enemy":
		tint = UnitLook.ENEMY_TINT
	var c := _cell(step[3])
	var v := make_unit(String(step[2]), c, tint)
	units[id] = v
	sheets[id] = String(step[2])
	cells[id] = c
	look(v, DIRS[String(step[4])], c)
	if opts.has("alpha"):
		v.set_alpha(float(opts.alpha))


## Walks `id` along one cell or a list of cells.
func _walk(id: String, to, opts: Dictionary) -> void:
	var v: UnitView3D = units[id]
	var path: Array = to if (to is Array and to.size() > 0 and (to[0] is Array or to[0] is String)) else [to]
	var per: float = float(opts.get("t", STEP))
	var anim := String(opts.get("anim", "walk"))
	for p in path:
		var c := _cell(p)
		await walk(v, cells[id], c, per, anim)
		cells[id] = c
	if opts.get("hide", false):
		v.visible = false
	if opts.get("par", false):
		_pending -= 1


func join() -> void:
	while _pending > 0:
		await get_tree().process_frame


# ---- the look: bars, wash, title card, speech bubbles, shake

## Narration sits low on a dark scrim over the scene, clear of the people in it.
func narrate(text: String, hold := 2.6) -> void:
	card.offset_top = 330.0
	card.offset_bottom = -BAR_HEIGHT - 20.0
	if scrim == null:
		scrim = ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		scrim.anchor_top = 1.0
		scrim.offset_top = -330.0
		scrim.offset_bottom = 0.0
		scrim.color = Color(0, 0, 0, 0.62)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scrim.modulate.a = 0.0
		card.get_parent().add_child(scrim)
		card.get_parent().move_child(scrim, card.get_index())
	card.text = text
	card.add_theme_font_size_override("font_size", 34)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.9)
	tw.tween_property(scrim, "modulate:a", 1.0, 0.9)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(card, "modulate:a", 0.0, 0.9)
	tw.parallel().tween_property(scrim, "modulate:a", 0.0, 0.9)
	await tw.finished

func _build_overlays() -> void:
	var ui := fade.get_parent()
	wash = ColorRect.new()
	wash.color = Color(0, 0, 0, 0)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(wash)
	ui.move_child(wash, 0)
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_left = 0.0
		b.anchor_right = 1.0
		b.anchor_top = 0.0 if top else 1.0
		b.anchor_bottom = 0.0 if top else 1.0
		b.offset_top = 0.0 if top else 0.0
		b.offset_bottom = 0.0
		ui.add_child(b)
		bars.append(b)
	ui.move_child(fade, ui.get_child_count() - 1)
	title_big = _title_label(ui, 84, -70)
	title_small = _title_label(ui, 38, 40)
	ui.move_child(fade, card.get_index())  # the black fade is under the narration and chapter cards, which show on it


func _title_label(ui: Node, size: int, y: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", HudStyle.font(true, true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.93, 0.8, 0.5))
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.modulate.a = 0.0
	ui.add_child(l)
	return l


func _bars(on: bool) -> void:
	box.offset_top = -300.0 - (BAR_HEIGHT if on else 0.0)  # the dialogue box stays clear of the bars
	box.offset_bottom = -48.0 - (BAR_HEIGHT if on else 0.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bars[0], "offset_bottom", BAR_HEIGHT if on else 0.0, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bars[1], "offset_top", -BAR_HEIGHT if on else 0.0, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _title(big: String, small: String, hold: float) -> void:
	title_big.text = big
	title_small.text = small
	var tw := create_tween()
	tw.tween_property(title_big, "modulate:a", 1.0, 1.1)
	tw.parallel().tween_property(title_small, "modulate:a", 1.0, 1.6)
	tw.tween_interval(hold)
	tw.tween_property(title_big, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(title_small, "modulate:a", 0.0, 1.0)
	await tw.finished


## A few words over a unit's head that rise and fade (an "!" or a murmur).
func _bubble(v: UnitView3D, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = HudStyle.font(true)
	l.font_size = 64
	l.pixel_size = 0.0045
	l.outline_size = 14
	l.modulate = Color(1, 0.95, 0.8)
	l.no_depth_test = true
	l.position = v.position + Vector3(0, 1.7, 0)
	board.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.5, 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


## A short shake of the picture: the camera is nudged and put back (the lens, angle and distance never change).
func _shake(strength: float, seconds: float) -> void:
	var cam := board.cam
	var h0 := cam.h_offset
	var v0 := cam.v_offset
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var k := (1.0 - t) * strength
		cam.h_offset = h0 + sin(t * 70.0) * k
		cam.v_offset = v0 + cos(t * 83.0) * k, 0.0, 1.0, seconds)
	await tw.finished
	cam.h_offset = h0
	cam.v_offset = v0


# ---- the townsfolk (as in the town scenes before): they keep running about for the whole scene, out of the stage

func _wander(v: UnitView3D, from: Vector2i) -> void:
	var at := from
	await get_tree().create_timer(_rng.randf_range(0.0, 1.2)).timeout
	while _busy and is_inside_tree():
		var goal := _pick_goal(at)
		if goal == TacticalGrid.NO_CELL:
			return
		var path := _path(at, goal)
		if path.size() > 1:
			await _run_path(v, path)
			at = goal
		v.play("idle")
		await get_tree().create_timer(_rng.randf_range(0.4, 1.8)).timeout


func _stage_rect() -> Rect2i:
	var r: Array = data.get("stage", [0, 0, 0, 0])
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


func _open(c: Vector2i) -> bool:
	if not board.in_bounds(c):
		return false
	var t: Dictionary = board.map.tiles[c.y][c.x]
	return t.t in ["g", "d", "s", "m", "f", "h", "e"] and t.h <= 1


func _pick_goal(from: Vector2i) -> Vector2i:
	var open: Array[Vector2i] = []
	var stage := _stage_rect()
	for y in board.map.d:
		for x in board.map.w:
			var c := Vector2i(x, y)
			if _open(c) and not stage.has_point(c) and absi(c.x - from.x) + absi(c.y - from.y) >= 4:
				open.append(c)
	return open[_rng.randi() % open.size()] if not open.is_empty() else TacticalGrid.NO_CELL


func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var stage := _stage_rect()
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
			if prev.has(n) or not _open(n) or stage.has_point(n):
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
		tw.tween_property(v, "position", board.top_point(path[i].x, path[i].y), 0.3)
		await tw.finished
