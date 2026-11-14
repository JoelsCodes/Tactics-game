class_name SteelMenu
extends Control
## The battle's command menu (Nov 2026, from the owner's reference): a vertical list of SteelButtons, sleek and dark.
##
## Every bar is engraved dark steel (drawn here, behind the buttons: a chamfered bar with a thin lit upper edge and a dark lower one); a command that cannot be
## used is muted steel with no glow. Only the SELECTED command is lit: one selector (menu_select.gdshader: navy-to-slate gradient, faint brushed streaks, a thin
## icy outline, a shimmer along its lower edge) that GLIDES to the next bar in GLIDE seconds when the selection changes (the mouse over a bar, or focus), and
## flashes for FLASH seconds when a command is confirmed. Two quiet metallic sounds go with them (menu_tick, menu_confirm). Thin ornament lines with a diamond
## close the list above and below. The menu only shows things and reports presses: the buttons' own `pressed` signals do the work.

const MIN_WIDTH := 500.0
const GAP := 3
const ORNAMENT := 14.0   ## room above and below the bars for the ornament lines
const PAD := 10.0        ## the selector's margin around its bar, for the glow
const GLIDE := 0.12
const FLASH := 0.08

var selected: SteelButton
var selector: ColorRect
var selector_target := Rect2()  ## the selected bar's rectangle, in this menu's coordinates (where the selector is gliding to)
var _list: VBoxContainer
var _tween: Tween
var _flash_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	selector = ColorRect.new()
	selector.name = "Selector"
	selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selector.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_select.gdshader")
	selector.material = mat
	selector.resized.connect(func(): mat.set_shader_parameter("rect_size", selector.size))
	add_child(selector)  # before the list: the words are drawn over the lit bar
	_list = VBoxContainer.new()
	_list.name = "Commands"
	_list.add_theme_constant_override("separation", GAP)
	_list.anchor_right = 1.0
	_list.anchor_bottom = 1.0
	_list.offset_top = ORNAMENT
	_list.offset_bottom = -ORNAMENT
	_list.sort_children.connect(_on_sorted)
	_list.minimum_size_changed.connect(update_minimum_size)
	add_child(_list)


func _get_minimum_size() -> Vector2:
	return Vector2(MIN_WIDTH, _list.get_combined_minimum_size().y + 2.0 * ORNAMENT)


func add_command(b: SteelButton) -> SteelButton:
	_list.add_child(b)
	b.mouse_entered.connect(_hover.bind(b))
	b.focus_entered.connect(_hover.bind(b))
	b.pressed.connect(_confirm.bind(b))
	b.visibility_changed.connect(func(): refresh())
	return b


func commands() -> Array[SteelButton]:
	var out: Array[SteelButton] = []
	for c in _list.get_children():
		if c is SteelButton:
			out.append(c)
	return out


func _selectable(b: SteelButton) -> bool:
	return b != null and b.visible and not b.disabled


## Keeps the lit bar on a command that can be used: where it is if it still can be (unless `reset`), else the first one that can.
func refresh(reset := false) -> void:
	if not (selected != null and not reset and _selectable(selected)):
		var first: SteelButton = null
		for b in commands():
			if _selectable(b):
				first = b
				break
		select(first, false, false)
	for b in commands():
		b.lit = b == selected
		b.queue_redraw()
	queue_redraw()


## Lights `b`. The selector glides there (`animate`); a change of selection ticks (`sound`).
func select(b: SteelButton, animate := true, sound := false) -> void:
	var changed := selected != b
	if selected != null and changed:
		selected.lit = false
	selected = b
	if b != null:
		b.lit = true
	_move_selector(animate and changed)
	if sound and changed:
		CombatAudio.play(self, "menu_tick", 1.0, -4.0)
	queue_redraw()


func _hover(b: SteelButton) -> void:
	if _selectable(b) and b != selected:
		select(b, true, true)


func _confirm(b: SteelButton) -> void:
	if b != selected and _selectable(b):
		select(b, true, false)
	CombatAudio.play(self, "menu_confirm", 1.0, -3.0)
	var mat := selector.material as ShaderMaterial
	mat.set_shader_parameter("flash", 1.0)
	if _flash_tween != null:
		_flash_tween.kill()
	if is_inside_tree():
		_flash_tween = create_tween()
		_flash_tween.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 1.0, 0.0, FLASH)


func _on_sorted() -> void:
	queue_redraw()
	_move_selector(false)  # the bars moved (the first layout, a command shown or hidden): snap, do not glide


func _move_selector(animate: bool) -> void:
	if selected == null or not selected.visible:
		selector.visible = false
		return
	var r := Rect2(_list.position + selected.position, selected.size)
	selector_target = r
	var pos := r.position - Vector2(PAD, PAD)
	var sz := r.size + Vector2(PAD, PAD) * 2.0
	if _tween != null:
		_tween.kill()
	if not animate or not selector.visible or not is_inside_tree():
		selector.position = pos
		selector.size = sz
		selector.visible = r.size.x > 1.0
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(selector, "position", pos, GLIDE)
	_tween.tween_property(selector, "size", sz, GLIDE)


func _draw() -> void:
	for b in commands():
		if b.visible:
			_draw_bar(Rect2(_list.position + b.position, b.size), b.disabled)
	_draw_ornament(ORNAMENT * 0.5)
	_draw_ornament(size.y - ORNAMENT * 0.5)


## An engraved bar: a chamfered hexagon in dark steel with a thin lit upper edge, a dark lower edge and a faint inner line. A command that cannot be used
## is flatter, lighter muted steel.
func _draw_bar(r: Rect2, off: bool) -> void:
	var pts := _hex(r)
	var top := Color("#151c26")
	var mid := Color("#19212c")
	var low := Color("#1f2834")
	if off:
		top = Color("#262d35")
		mid = Color("#292f38")
		low = Color("#2c323b")
	draw_polygon(pts, PackedColorArray([mid, top, top, mid, low, low]))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3]]), Color(0.75, 0.85, 1.0, 0.07 if off else 0.11), 1.0, true)
	draw_polyline(PackedVector2Array([pts[3], pts[4], pts[5], pts[0]]), Color(0, 0, 0, 0.55), 1.0, true)
	var inner := _hex(r.grow(-3.0))
	inner.append(inner[0])
	draw_polyline(inner, Color(0.75, 0.85, 1.0, 0.035 if off else 0.05), 1.0, true)


static func _hex(r: Rect2) -> PackedVector2Array:
	var c := r.size.y * 0.5
	var m := r.position.y + c
	return PackedVector2Array([
		Vector2(r.position.x, m), Vector2(r.position.x + c, r.position.y), Vector2(r.end.x - c, r.position.y),
		Vector2(r.end.x, m), Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y)])


## A thin line with a small diamond at its middle, in cool steel.
func _draw_ornament(y: float) -> void:
	var cx := size.x * 0.5
	var col := Color("#8fb4d4", 0.34)
	draw_line(Vector2(26, y), Vector2(cx - 12, y), col, 1.0, true)
	draw_line(Vector2(cx + 12, y), Vector2(size.x - 26, y), col, 1.0, true)
	var d := PackedVector2Array([Vector2(cx, y - 4), Vector2(cx + 5, y), Vector2(cx, y + 4), Vector2(cx - 5, y)])
	draw_colored_polygon(d, Color("#8fb4d4", 0.45))
