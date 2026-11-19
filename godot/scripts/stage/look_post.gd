class_name LookPost
extends CanvasLayer
## Whole-frame look over the 3D picture and under the HUD (shaders/look_post.gdshader): tilt-shift blur, split-tone grade, bloom, vignette.
## Prototype and reversible: nothing adds it unless asked (the test scenes add it for `look=ref`).

var material := ShaderMaterial.new()


func _init() -> void:
	layer = -1
	name = "LookPost"
	material.shader = load("res://shaders/look_post.gdshader")
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = material
	add_child(r)
