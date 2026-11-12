// See-through silhouette of a unit the ground hides (Claude, Nov 2026, approved by the owner). Drawn over everything, but a pixel only
// shows where something nearer than the unit was drawn there: the part of the unit you can see draws nothing, so a unit in plain view
// looks exactly as before. `tex` is the frame's all-white silhouette (UnitView3D._white), `tint` the team colour and strength.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(0.45, 0.78, 1.0, 0.55);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float margin = 0.08; // world units: what lies closer than this in front of the unit does not count as hiding it

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene = -v.z / v.w;  // how far the nearest drawn surface is at this pixel
	if (scene > -VERTEX.z - margin) {
		discard;  // nothing in front: the unit itself is what you see here
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
