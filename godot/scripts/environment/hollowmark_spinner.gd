class_name HollowmarkSpinner
extends Node3D
## A part of a Hollowmark scenery that turns slowly about its own vertical axis (a gear under a glass floor, an orrery ring and its planet).
## HollowmarkScenery makes one for every GLB node named SPIN_<name>_p<rate> or _n<rate> (p = turns one way, n = the other; the rate is in
## hundredths of a radian per second). Blender builds the part with its origin at the pivot and its own Z as the axis; glTF makes that Y.
var rate := 0.1


func _process(delta: float) -> void:
	rotate_object_local(Vector3.UP, rate * delta)
