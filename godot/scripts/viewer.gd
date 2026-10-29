extends Node2D
## Terrain and sprite viewer: shows a sample map from samples/ with every character standing on it.
## Drag to pan, pinch or wheel to zoom, Q/E (or two-finger double tap) to rotate, Tab for the next sample.

const SAMPLES := ["res://samples/all_terrains.json", "res://samples/grass_hills.json", "res://samples/intro_forest.json"]

static var start_sample := 0

var sample := 0
var chars: Array = []  ## [Character, grid x, grid y]
var _touches := {}
var _drag = null
var _pinch = null

@onready var terrain: Terrain = $Terrain
@onready var cam: Camera2D = $Camera


func _ready() -> void:
	show_sample(start_sample)


func show_sample(i: int) -> void:
	sample = posmod(i, SAMPLES.size())
	for c in chars:
		c[0].queue_free()
	chars = []
	var m := Terrain.load_map(SAMPLES[sample])
	terrain.show_map(m)
	var names := Character.names()
	var step := minf(2.0, (m.w - 3.0) / names.size())  # narrow maps (the intro forest) fit the cast by closing the gaps
	for k in names.size():
		var x := 2.0 + k * step
		var y: float = m.d / 2.0 + (k % 2) * 2.0 - 1.0
		while terrain.tile_at(x, y).t in ["W", "l", "t"]:
			y += 1.0
		var c := Character.new()
		terrain.field.add_child(c)
		c.setup(names[k])
		chars.append([c, x, y])
	_place()
	cam.position = terrain.stand_point(m.w / 2.0, m.d / 2.0)
	cam.zoom = Vector2.ONE * clampf(get_viewport_rect().size.x / ((m.w + m.d) * Terrain.TW * .62), .45, 2.4)


func _place() -> void:
	for c in chars:
		var ch: Character = c[0]
		ch.position = terrain.stand_point(c[1], c[2])
		var t = terrain.tile_at(c[1], c[2])
		ch.set_wading(t.t == "w")


func rotate_view(dir: int) -> void:
	terrain.rotate_view(dir)
	_place()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_Q: rotate_view(-1)
			KEY_E: rotate_view(1)
			KEY_TAB: show_sample(sample + 1)
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_drag = [e.position, cam.position]
			elif _touches.size() == 2:
				var ps: Array = _touches.values()
				_pinch = {"d": max(1.0, ps[0].distance_to(ps[1])), "z": cam.zoom.x}
				if e.double_tap:
					rotate_view(1)
		else:
			_touches.erase(e.index)
			if _touches.size() < 2:
				_pinch = null
			if _touches.is_empty():
				_drag = null
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() == 2 and _pinch != null:
			var ps: Array = _touches.values()
			cam.zoom = Vector2.ONE * clampf(_pinch.z * ps[0].distance_to(ps[1]) / _pinch.d, .45, 2.4)
		elif _drag != null and _touches.size() == 1:
			cam.position = _drag[1] - (e.position - _drag[0]) / cam.zoom.x
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam.zoom = Vector2.ONE * clampf(cam.zoom.x * (1.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else .9), .45, 2.4)
