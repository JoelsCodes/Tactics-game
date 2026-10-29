class_name TreeView3D
extends Node3D
## A tree on the 3D board: the 2D tree sprite as an upright billboard (nearest filtering) with an
## invisible trunk-and-crown shape that casts its shadow.

var sprite := Sprite3D.new()


func setup(size: float, flip: bool) -> void:
	var tex: Texture2D = load("res://assets/props/tree.png")
	sprite.texture = tex
	sprite.pixel_size = size * Board3D.UNIT_SCALE / Board3D.PX_PER_UNIT
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.modulate = Color(.92, .92, .86)
	sprite.flip_h = flip
	sprite.offset = Vector2(0, tex.get_height() / 2.0 - 6)  # the trunk's foot on the origin
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	var h := tex.get_height() * sprite.pixel_size
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = tex.get_width() * sprite.pixel_size * .36
	sphere.height = h * .6
	crown.mesh = sphere
	crown.position.y = h * .62
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(crown)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = .06
	cyl.bottom_radius = .08
	cyl.height = h * .4
	trunk.mesh = cyl
	trunk.position.y = h * .2
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(trunk)


func fit(k: float) -> void:
	sprite.scale = Vector3(1, k, 1)
