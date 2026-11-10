class_name UnitBars
extends Control
## A small HP bar over every unit on the board (green for the player's units, cyan for vessels, red for enemies), drawn on the HUD
## at the unit's place on screen. When a unit is hurt, the lost part stays white for a moment and then drains, so the size of a
## blow is seen. Knocked-out, fled and faded units have none. Presentation only.

const W := 46.0
const H := 5.0
const DRAIN_WAIT := 0.35  ## seconds the lost part stays before it drains
const DRAIN_SPEED := 1.6  ## bar widths per second

var board: Board3D
var views: Dictionary  ## BattleUnit -> UnitView3D (the stage's own dictionary)
var current: BattleUnit  ## the acting unit: its bar is a little brighter and has a marker
var _shown := {}  ## BattleUnit -> [ghost ratio, seconds to wait]
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(b: Board3D, v: Dictionary) -> void:
	board = b
	views = v


func _process(delta: float) -> void:
	_t += delta
	for bu in views:
		var r := _ratio(bu)
		if not _shown.has(bu):
			_shown[bu] = [r, 0.0]
			continue
		var s: Array = _shown[bu]
		if r >= s[0]:
			s[0] = r  # healed: the bar follows at once
			s[1] = DRAIN_WAIT
		elif s[1] > 0.0:
			s[1] -= delta
		else:
			s[0] = maxf(r, s[0] - DRAIN_SPEED * delta)
			if s[0] <= r:
				s[1] = DRAIN_WAIT
	for bu in _shown.keys():
		if not views.has(bu):
			_shown.erase(bu)
	queue_redraw()


static func _ratio(bu: BattleUnit) -> float:
	return clampf(float(bu.hp) / maxf(1.0, float(bu.max_hp())), 0.0, 1.0)


func _draw() -> void:
	if board == null or board.cam == null:
		return
	var cam := board.cam
	for bu in views:
		var v: UnitView3D = views[bu]
		if not is_instance_valid(v) or not v.visible or bu.is_down() or v.get_alpha() < 0.5:
			continue
		var foot := v.global_position
		if cam.is_position_behind(foot):
			continue
		# the sprite stands upright on screen (Board3D.upright_orient), so the bar sits straight above the feet by the figure's height on screen
		var at := cam.unproject_position(foot)
		var p := Vector2(at.x, at.y - board._projected_height(foot, v.figure_height()) - 10.0)
		var r := Rect2(p.x - W / 2.0, p.y - H, W, H)
		var col := HudStyle.ENEMY if bu.team != 0 else (HudStyle.VESSEL if bu.is_vessel() else HudStyle.HP)
		draw_rect(r.grow(1.5), Color(0, 0, 0, 0.75))
		var ratio := _ratio(bu)
		var ghost: float = _shown[bu][0] if _shown.has(bu) else ratio
		if ghost > ratio:
			draw_rect(Rect2(r.position, Vector2(W * ghost, H)), Color(1, 1, 1, 0.9))
		if ratio > 0.0:
			draw_rect(Rect2(r.position, Vector2(W * ratio, H)), col)
			draw_rect(Rect2(r.position, Vector2(W * ratio, H * 0.4)), Color(1, 1, 1, 0.22))
		if bu == current:  # a small gold marker bobbing over the acting unit
			var y := r.position.y - 9.0 - 3.0 * absf(sin(_t * 4.0))
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 7, y - 8), Vector2(p.x + 7, y - 8), Vector2(p.x, y)]), HudStyle.GOLD)
			draw_polyline(PackedVector2Array([Vector2(p.x - 7, y - 8), Vector2(p.x + 7, y - 8), Vector2(p.x, y), Vector2(p.x - 7, y - 8)]), Color(0.15, 0.08, 0.0, 0.9), 1.5)
