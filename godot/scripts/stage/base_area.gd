class_name BaseArea
extends Cutscene3D
## The base: the altar chamber's ruins and the wild growing through them, 30x30 tiles (samples/base.json, made by
## tools/make_base_map.py). Not a battle: Alaric walks about freely, not tile by tile, and talks to the others. Arrow keys / WASD
## walk (Shift runs), a click walks there, E / Enter / Space uses what is nearby. On the same 3D board, lens, angle and distance
## as everything else, but the map is wider than the screen, so here (and only here, the owner's choice) the camera follows
## Alaric, stopping at the map's edges.
##   the altar        opens the barracks (the loadout and mentorship menus)
##   the gate         opens the world map
##   Bram and Lyra   stand about and talk (their lines are a first draft by Claude)
## Walls, deep water, trees and the altar block the way; a step of more than one level is a cliff. Shallow water is waded.
## Cells are (column, row); a position is a Vector2 in tile units (a tile's centre is at x + 0.5, y + 0.5): the column is the
## depth (up the screen), the row runs left to right.

const MAP := "res://samples/base.json"
const WALK := 3.2  ## tiles a second
const RUN := 5.4
const RADIUS := 0.2  ## how wide Alaric's feet are, for the walls
const INTERACT := 1.7  ## how near a hotspot must be to use it
const BLOCKED_TILES := ["q", "v", "W", "t"]  ## walls, openings, deep water, trees
const ALTAR_CELL := Vector2i(28, 15)  ## the altar block itself
const START := Vector2(5.5, 15.5)  ## on the plaza just inside the gate
const FOLLOW_SPEED := 5.0  ## how quickly the camera catches up
const VIEW_DEPTH := 9.0  ## how far (tiles) the camera stops from the map's near and far edges
const VIEW_SIDE := 13.0  ## ... and from its left and right edges
const NEXT_BARRACKS := "res://scenes/barracks.tscn"
const NEXT_WORLD := "res://scenes/world_map.tscn"
## [id, kind, name, where, prompt] (the prompt shows when it can be used)
const SPOTS := [
	["altar", "altar", "The altar", Vector2(27.4, 15.5), "Barracks"],
	["gate", "gate", "The gate", Vector2(1.6, 15.5), "World map"],
	["bram", "npc", "Bram", Vector2(4.6, 19.6), "Talk to Bram"],
	["lyra", "npc", "Lyra", Vector2(25.5, 12.5), "Talk to Lyra"],
]
## Drafted by Claude, in their voices (the owner writes the story: reword freely).
const TALK := {
	"bram": ["Quiet so far. I don't trust quiet.", "I'll keep the gate. Somebody has to."],
	"lyra": ["Every road we found runs back to this altar. I am still reading what it keeps.", "The ruins and the roots grew into each other. I find that hopeful."],
}

@export var go_on := true  ## false in the checks: record the action instead of changing scene

var player: UnitView3D
var pos := START  ## where Alaric is, in tile units
var run := false
var talking := false
var last_action := ""  ## "barracks" / "world_map" / "talk:<id>" (what the last interaction did)
var spots := {}  ## id -> {"kind", "at": Vector2, "prompt", "view": UnitView3D or null}
var prompt: Label
var nearest := ""  ## the hotspot in reach right now
var _path: Array[Vector2] = []
var _goal := ""  ## a hotspot being walked to by a click
var _y := 0.0
var _talk_i := {}
var _t := 0.0
var _rings: Array[MeshInstance3D] = []
var _cam_at := Vector3.ZERO  ## where the camera is pointed now (it eases toward Alaric)


func _ready() -> void:
	setup_scene(MAP)
	player = make_unit("king", Vector2i(floori(START.x), floori(START.y)))
	_y = _ground(pos)
	_place_player()
	_cam_at = _follow_point()
	_lock_camera()
	look(player, Vector2i(1, 0), cell_of(pos))
	_build_spots()
	_build_ui()
	_build_fireflies()
	fade.modulate.a = 1.0
	fade_to(0.0, 1.4)


# ---------- the ground ----------

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))


func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < board.map.w and c.y < board.map.d


func tile_code(c: Vector2i) -> String:
	return board.map.tiles[c.y][c.x].t


func level_at(c: Vector2i) -> int:
	return int(board.map.tiles[c.y][c.x].h)


## True when the tile itself can be stood on.
func tile_open(c: Vector2i) -> bool:
	return in_map(c) and not BLOCKED_TILES.has(tile_code(c)) and c != ALTAR_CELL


## True when Alaric's feet fit at `p`, coming from level `from_level`.
func can_stand(p: Vector2, from_level: int) -> bool:
	for dx in [-RADIUS, RADIUS]:
		for dy in [-RADIUS, RADIUS]:
			var c := cell_of(p + Vector2(dx, dy))
			if not tile_open(c) or absi(level_at(c) - from_level) > 1:
				return false
	return true


func _ground(p: Vector2) -> float:
	var c := cell_of(p)
	return board.top_point(c.x, c.y).y if in_map(c) else 0.0


func _place_player() -> void:
	player.position = Vector3(pos.x, _y, pos.y)
	player.set_wading(tile_code(cell_of(pos)) == "w")


# ---------- moving ----------

func _process(delta: float) -> void:
	_t += delta
	if player == null:
		return
	var dir := Vector2.ZERO
	if not talking:
		dir = _key_dir()
		if dir != Vector2.ZERO:
			_path.clear()
			_goal = ""
		elif not _path.is_empty():
			var to := _path[0] - pos
			if to.length() < 0.1:
				_path.pop_front()
				if _path.is_empty() and _goal != "":
					var g := _goal
					_goal = ""
					if nearest == g:
						interact(g)
			else:
				dir = to.normalized()
	var moved := step(dir, delta)
	player.play(("run" if run else "walk") if moved else "idle")
	_y = lerpf(_y, _ground(pos), minf(1.0, 14.0 * delta))
	_place_player()
	_follow(delta)
	_update_nearest()
	for i in _rings.size():
		_rings[i].scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 2.4 + i))


## Walks `dir` (a unit vector or zero, in tile units) for `delta` seconds, sliding along walls. Returns true if it moved.
func step(dir: Vector2, delta: float) -> bool:
	if dir == Vector2.ZERO:
		return false
	var speed := RUN if run else WALK
	var from_level := level_at(cell_of(pos))
	var d := dir * speed * delta
	var moved := false
	for axis in [Vector2(d.x, 0), Vector2(0, d.y)]:  # one axis at a time, so a wall is slid along
		if axis != Vector2.ZERO and can_stand(pos + axis, from_level):
			pos += axis
			moved = true
	if moved:
		var major := Vector2i(signi(int(roundf(dir.x * 100))), 0) if absf(dir.x) >= absf(dir.y) else Vector2i(0, signi(int(roundf(dir.y * 100))))
		look(player, major, cell_of(pos))
	return moved


func _key_dir() -> Vector2:
	run = Input.is_key_pressed(KEY_SHIFT)
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.x += 1.0  # up the screen is deeper into the map
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.y -= 1.0
	return d.normalized()


## The tiles to walk to reach `to` from where Alaric stands (breadth first over the open tiles, one level at a time), as the
## centres of the tiles; [] when it cannot be reached.
func path_to(to: Vector2i) -> Array[Vector2]:
	var start := cell_of(pos)
	var out: Array[Vector2] = []
	if not tile_open(to):
		return out
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not came.has(n) and tile_open(n) and absi(level_at(n) - level_at(c)) <= 1:
				came[n] = c
				queue.append(n)
	if not came.has(to):
		return out
	var c := to
	while c != start:
		out.push_front(Vector2(c.x + 0.5, c.y + 0.5))
		c = came[c]
	return out


func walk_to(c: Vector2i) -> bool:
	var p := path_to(c)
	if p.is_empty() and c != cell_of(pos):
		return false
	_path = p
	return true


func _unhandled_input(e: InputEvent) -> void:
	if talking:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var c := board.pick(e.position)
		if not in_map(c):
			return
		_goal = ""
		for id in spots:
			if spots[id].at.distance_to(Vector2(c.x + 0.5, c.y + 0.5)) <= 1.0:
				_goal = id
		if _goal != "":
			if nearest == _goal:
				interact(_goal)
				return
			c = cell_of(spots[_goal].at)
		walk_to(c)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if nearest != "":
					interact(nearest)
			KEY_M:
				interact("gate")


# ---------- the camera ----------

## Where the camera points when it has caught up: Alaric, kept inside the map's edges (so the view never shows past them).
func _follow_point() -> Vector3:
	var w := float(board.map.w)
	var d := float(board.map.d)
	var x := clampf(pos.x, minf(VIEW_DEPTH, w / 2.0), maxf(w - VIEW_DEPTH, w / 2.0))
	var y := clampf(pos.y, minf(VIEW_SIDE, d / 2.0), maxf(d - VIEW_SIDE, d / 2.0))
	return Vector3(x, 0.6 + _ground(Vector2(x, y)) * 0.5, y)


func _follow(delta: float) -> void:
	_cam_at = _cam_at.lerp(_follow_point(), 1.0 - exp(-FOLLOW_SPEED * delta))
	_apply_camera()


func _apply_camera() -> void:
	if board == null or board.cam == null:
		return
	var view := get_viewport().get_visible_rect().size
	board.follow(_cam_at, Rect2(Vector2.ZERO, view), view)


## The base's camera follows Alaric (Cutscene3D calls this when the window changes size too).
func _lock_camera() -> void:
	_apply_camera()


# ---------- things to use ----------

func _build_spots() -> void:
	for s in SPOTS:
		var view: UnitView3D = null
		if s[1] == "npc":
			view = make_unit("warden" if s[0] == "bram" else "mira", cell_of(s[3]), UnitLook.VESSEL_TINT)
			view.position = Vector3(s[3].x, board.top_point(cell_of(s[3]).x, cell_of(s[3]).y).y, s[3].y)
			look(view, Vector2i(0, -1), cell_of(s[3]))
		else:  # a glowing ring on the ground
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.5
			ring.mesh = torus
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.85, 0.45, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring.material_override = m
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var c := cell_of(s[3])
			ring.position = Vector3(s[3].x, board.top_point(c.x, c.y).y + 0.03, s[3].y)
			ring.scale = Vector3(1, 0.05, 1)
			board.add_child(ring)
			_rings.append(ring)
		var tag := Label3D.new()
		tag.text = s[2]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.pixel_size = 0.0065
		tag.font_size = 40
		tag.outline_size = 14
		tag.modulate = Color(1.0, 0.93, 0.7)
		var cc := cell_of(s[3])
		tag.position = Vector3(s[3].x, board.top_point(cc.x, cc.y).y + (1.9 if s[1] == "npc" else 1.0), s[3].y)
		board.add_child(tag)
		spots[s[0]] = {"kind": s[1], "at": s[3], "prompt": s[4], "view": view}


func _update_nearest() -> void:
	var best := ""
	var best_d := INF
	for id in spots:
		var d: float = spots[id].at.distance_to(pos)
		if d <= INTERACT and d < best_d:
			best = id
			best_d = d
	nearest = best
	if prompt != null:
		prompt.visible = best != "" and not talking
		if best != "":
			prompt.text = "E   ·   %s" % spots[best].prompt
	for id in spots:  # the others turn to face Alaric when he is near
		var v: UnitView3D = spots[id].view
		if v != null and spots[id].at.distance_to(pos) < 3.2:
			var to: Vector2 = pos - spots[id].at
			look(v, Vector2i(signi(int(roundf(to.x * 100))), 0) if absf(to.x) >= absf(to.y) else Vector2i(0, signi(int(roundf(to.y * 100)))), cell_of(spots[id].at))


## Uses a hotspot: the altar (barracks), the gate (world map) or a talk.
func interact(id: String) -> void:
	if not spots.has(id) or talking:
		return
	var s: Dictionary = spots[id]
	match s.kind:
		"altar":
			last_action = "barracks"
			_leave(NEXT_BARRACKS)
		"gate":
			last_action = "world_map"
			_leave(NEXT_WORLD)
		"npc":
			last_action = "talk:%s" % id
			var lines: Array = TALK[id]
			var i: int = _talk_i.get(id, 0)
			_talk_i[id] = i + 1
			talking = true
			_path.clear()
			await say(lines[i % lines.size()], "warden" if id == "bram" else "mira", String(s_name(id)).to_upper())
			talking = false


func s_name(id: String) -> String:
	return "Bram" if id == "bram" else "Lyra"


func _leave(scene: String) -> void:
	if not go_on:
		return
	GameSession.game = GameSession.current()
	await fade_to(1.0, 0.8)
	get_tree().change_scene_to_file(scene)


# ---------- screen furniture and mood ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var head := Label.new()
	head.text = "THE HOLLOW BASE"
	head.add_theme_font_override("font", HudStyle.font(true, true))
	head.add_theme_font_size_override("font_size", 38)
	head.add_theme_color_override("font_color", Color("#f3e6c4"))
	head.add_theme_constant_override("outline_size", 10)
	head.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	head.position = Vector2(56, 36)
	ui.add_child(head)
	var hint := Label.new()
	hint.text = "WASD / arrows to walk  ·  Shift to run  ·  click to walk there  ·  E to use  ·  M for the world map"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(56, -52)
	ui.add_child(hint)
	prompt = Label.new()
	prompt.add_theme_font_override("font", HudStyle.font(true, true))
	prompt.add_theme_font_size_override("font_size", 30)
	prompt.add_theme_color_override("font_color", Color("#f4d27a"))
	prompt.add_theme_constant_override("outline_size", 10)
	prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.95))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.offset_top = -150
	prompt.visible = false
	ui.add_child(prompt)
	ui.move_child(fade.get_parent() if false else prompt, ui.get_child_count() - 1)


## Fireflies drifting over the pond and the tower court.
func _build_fireflies() -> void:
	for at in [Vector2(17.5, 6.5), Vector2(11.5, 2.5), Vector2(16.5, 25.5), Vector2(25.5, 26.5), Vector2(25.5, 10.5), Vector2(6.5, 12.5)]:
		var p := CPUParticles3D.new()
		p.amount = 12
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 2.0
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.08
		p.initial_velocity_max = 0.25
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.4
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.95, 0.5)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = m
		p.mesh = quad
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 0.6, 0.0))
		ramp.add_point(0.5, Color(1, 0.95, 0.5, 0.95))
		ramp.set_color(1, Color(1, 1, 0.6, 0.0))
		p.color_ramp = ramp
		var c := cell_of(at)
		p.position = Vector3(at.x, board.top_point(c.x, c.y).y + 0.7, at.y)
		board.add_child(p)
