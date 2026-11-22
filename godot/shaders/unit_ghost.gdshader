// See-through silhouette of a unit the ground hides (Claude, Nov 2026, approved by the owner). Drawn over everything, but a pixel only
// shows where something nearer than the unit was drawn there: the part of the unit you can see draws nothing, so a unit in plain view
// looks exactly as before. `tex` is the frame's all-white silhouette (UnitView3D._white), `tint` the team colour and strength.
// Only when the head or the feet are hidden (owner, Nov 21 2026): a beam or rail across the middle of a unit whose head and feet both
// show is left in front of it, wood and all, instead of a coloured band through the wood. Two points on the figure's centre line are
// checked, `probe_y` (local heights near the feet and near the head, set by UnitView3D._sync_ghost).
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(0.45, 0.78, 1.0, 0.55);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float margin = 0.08; // world units: what lies closer than this in front of the unit does not count as hiding it
uniform vec2 probe_y = vec2(0.15, 1.0);
#include "res://shaders/upright_shear.gdshaderinc"

varying vec3 v_lo;  // the probe near the feet: screen uv, how far it is
varying vec3 v_hi;  // the probe near the head

vec3 probe(float y, mat4 modelview, mat4 projection) {
	vec4 vp = modelview * vec4(0.0, y, 0.0, 1.0);
	vec4 c = projection * vp;
	vec2 ndc = c.xy / c.w;
	if (shear_upright) {  // the shear stands the centre line straight over the feet
		vec4 f = projection * (modelview * vec4(0.0, 0.0, 0.0, 1.0));
		ndc.x = f.x / f.w;
	}
	return vec3(ndc * 0.5 + 0.5, -vp.z);
}

void vertex() {
	v_lo = probe(probe_y.x, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	v_hi = probe(probe_y.y, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	if (shear_upright) {
		upright_shear_vertex(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX, POSITION);
	}
}

float scene_depth(vec2 uv, mat4 inv_projection) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;  // how far the nearest drawn surface is at this point of the screen
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	bool lo_hidden = scene_depth(v_lo.xy, INV_PROJECTION_MATRIX) < v_lo.z - margin;
	bool hi_hidden = scene_depth(v_hi.xy, INV_PROJECTION_MATRIX) < v_hi.z - margin;
	if (!lo_hidden && !hi_hidden) {
		discard;  // head and feet both in sight: whatever crosses the middle stays in front
	}
	if (scene_depth(SCREEN_UV, INV_PROJECTION_MATRIX) > -VERTEX.z - margin) {
		discard;  // nothing in front: the unit itself is what you see here
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
