class_name PropView3D
extends Node3D
## A prop from the catalogue (assets/props/catalogue.json, cut by tools/art/props.py) standing on the 3D board: an
## upright billboard like the trees, its foot on the tile's top. A map lists its props as
## {"id": "sword_in_stone", "x": 7, "y": 7, "h": 1.6, "flip": false}: `h` is the prop's height in world units
## (the King stands about 1.9), so a statue can tower over a unit and a lantern stay small.

const CATALOGUE := "res://assets/props/catalogue.json"
const DEFAULT_HEIGHT := 1.5

static var _catalogue := {}

var id := ""
var sprite := Sprite3D.new()


static func catalogue() -> Dictionary:
	if _catalogue.is_empty():
		_catalogue = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	return _catalogue


func setup(prop_id: String, height := DEFAULT_HEIGHT, flip := false) -> void:
	id = prop_id
	var tex: Texture2D = load("res://assets/props/" + String(catalogue()[prop_id].file))
	sprite.texture = tex
	sprite.pixel_size = height / tex.get_height()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.modulate = Color(.92, .92, .88)
	sprite.flip_h = flip
	sprite.offset = Vector2(0, tex.get_height() / 2.0 - 2)  # the foot on the origin
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)


func fit(k: float) -> void:
	sprite.scale = Vector3(1, k, 1)
