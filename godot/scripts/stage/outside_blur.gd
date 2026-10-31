class_name OutsideBlur
extends CanvasLayer
## Blurs everything on screen outside the map's footprint (the hallway's 8x10), so the floor the story happens on
## stays sharp and the floor beyond it is out of focus. The footprint is the outline of the map's corners, from the
## floor up past its tallest tile, projected through the board's camera every frame (so it follows the view).
## Drawn on layer 0: under the dialogue box and the fade, over the 3D board.

const BLUR_PX := 10.0  ## blur radius on screen, in pixels
const FEATHER := 36.0  ## the soft edge where sharp turns to blurred, in pixels

var board: Board3D
var _mat: ShaderMaterial


func _init(b: Board3D) -> void:
	board = b
	layer = 0


func _ready() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/outside_blur.gdshader")
	_mat.set_shader_parameter("blur_px", BLUR_PX)
	_mat.set_shader_parameter("feather", FEATHER)
	rect.material = _mat
	add_child(rect)


func _process(_delta: float) -> void:
	if board == null or board.cam == null or not board.cam.is_inside_tree():
		return
	var top := board.max_height() + 0.5
	var points: Array[Vector2] = []
	for x in [0.0, float(board.map.w)]:
		for z in [0.0, float(board.map.d)]:
			for y in [-Board3D.BASE, top]:
				points.append(board.cam.unproject_position(Vector3(x, y, z)))
	var outline := _hull(points)
	var count := outline.size()  # 8 corners at most (a box)
	while outline.size() < 8:  # the shader's array is fixed at 8; the padding is never read
		outline.append(outline[-1])
	_mat.set_shader_parameter("hull", outline)
	_mat.set_shader_parameter("hull_n", count)
	_mat.set_shader_parameter("view_size", get_viewport().get_visible_rect().size)


## The convex outline of `points` (Andrew's monotone chain), counter-clockwise in the sense the shader tests:
## a point is inside when every edge has it on its left.
static func _hull(points: Array[Vector2]) -> Array[Vector2]:
	var p := points.duplicate()
	p.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var h: Array[Vector2] = []
	for pt in p:
		while h.size() >= 2 and _cross(h[h.size() - 2], h[h.size() - 1], pt) <= 0.0:
			h.pop_back()
		h.append(pt)
	var lower := h.size() + 1
	for i in range(p.size() - 2, -1, -1):
		var pt: Vector2 = p[i]
		while h.size() >= lower and _cross(h[h.size() - 2], h[h.size() - 1], pt) <= 0.0:
			h.pop_back()
		h.append(pt)
	h.pop_back()
	return h


static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
