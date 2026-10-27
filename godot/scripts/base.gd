extends Node
## The clan's base: Skyhold, a hub of floating marble islands. A viewer for now: the clan idles
## around the plaza and you can pan, zoom and rotate. Menus (shop, bazaar, clan) come later.

## [job index into Rules.new_party(), x, y]
const SPOTS := [[0, 13, 3], [1, 22, 12], [2, 2, 11], [3, 9, 13], [4, 12, 8], [5, 15, 11]]

var B: Dictionary

@onready var world: BattleWorld = $World
@onready var sky: TextureRect = $Backdrop/Sky


func _ready() -> void:
	var map := Rules.parse_map("base")
	B = {"map": map, "units": [], "objs": [], "law": null}
	var party := Rules.new_party()
	for s in SPOTS:
		var bu := Rules.make_bu(party[s[0]], 0, s[1], s[2], 2)
		bu.f = 2 if s[2] < 11 else 0
		B.units.append(bu)
	world.setup(B)
	var g: Gradient = (sky.texture as GradientTexture2D).gradient
	var cols: Array = world.sky_colors()
	g.set_color(0, cols[0])
	g.set_color(1, cols[1])
	world.cam.zoom = Vector2.ONE * clampf(.9, world.min_zoom, world.max_zoom)
	_buttons()


func _buttons() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var row := HBoxContainer.new()
	row.anchor_left = 0
	row.anchor_right = 1
	row.anchor_top = 1
	row.anchor_bottom = 1
	row.offset_top = -64
	row.offset_bottom = -12
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	for spec in [["Back", func(): get_tree().change_scene_to_file("res://scenes/title.tscn")], ["⟲", func(): world.rotate_view(-1)],
			["⟳", func(): world.rotate_view(1)], ["+", func(): world.zoom_by(1.2)], ["−", func(): world.zoom_by(.83)]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(spec[1])
		row.add_child(b)
	var title := Label.new()
	title.text = "Skyhold"
	title.theme_type_variation = "HeaderLabel"
	title.position = Vector2(16, 14)
	layer.add_child(title)
