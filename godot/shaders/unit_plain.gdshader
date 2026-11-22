// A unit's frame drawn exactly as the plain unshaded sprite drew it (Claude, Nov 2026): picture times `base` (what Sprite3D.modulate did:
// side tint, KO gray, fade), cut out at half alpha. It exists so every character can stand upright on screen by the shear in
// upright_shear.gdshaderinc instead of being turned (a turn tilts the rows of pixels). UnitView3D makes a fading copy without the cut-out.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 base : source_color = vec4(1.0);
#include "res://shaders/upright_shear.gdshaderinc"

void vertex() {
	if (shear_upright) {
		upright_shear_vertex(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX, POSITION);
	}
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * base.rgb;
	ALPHA = c.a * base.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
