class_name FxSprite
extends MeshInstance3D
## One frame-by-frame effect from the owner's effect sheet (assets/sprites/effects/fx_<look>_<piece>.png: six frames side by side): a quad whose
## texture window steps through the strip. It plays once and then frees itself, or loops until `stop_looping` / `fade_out`. EffectLibrary makes these.

signal finished  ## a one-shot has shown its last frame (emitted once; the node frees itself right after)

var frames := 6
var fps := 12.0
var loop := false
var _t := 0.0
var _mat: StandardMaterial3D
var _done := false


## `strip` is the whole strip; `size` the quad in world units (width, height); `additive` adds the colours to the scene instead of blending.
func setup(strip: Texture2D, size: Vector2, frame_count: int, frames_per_second: float, looping: bool, additive := false) -> void:
	frames = frame_count
	fps = frames_per_second
	loop = looping
	var q := QuadMesh.new()
	q.size = size
	mesh = q
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_texture = strip
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat.uv1_scale = Vector3(1.0 / float(frames), 1.0, 1.0)
	_mat.render_priority = 6
	_mat.disable_receive_shadows = true
	if additive:
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show(0)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var f := int(_t * fps)
	if f >= frames:
		if loop:
			f = f % frames
		else:
			_done = true
			_show(frames - 1)
			finished.emit()
			queue_free()
			return
	_show(f)


func _show(f: int) -> void:
	if _mat != null:
		_mat.uv1_offset = Vector3(float(f) / float(frames), 0.0, 0.0)


## Stops a looping effect with a short fade, then frees it.
func fade_out(secs := 0.25) -> void:
	loop = false
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "transparency", 1.0, secs)
	tw.tween_callback(queue_free)
	finished.emit()
