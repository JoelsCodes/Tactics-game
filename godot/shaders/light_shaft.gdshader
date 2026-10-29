// One volumetric light shaft (god-ray): a long soft quad laid along the sun's direction, turned to face
// the camera around its own axis (Board3D._place_shafts). Brightest in the middle of its width, fading
// in from the sky and out high above the ground, with slow drifting streaks so it shimmers like light through
// dust. Additive, unshaded, no depth write; it fades where it meets geometry (depth), so it never cuts.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 shaft_color : source_color = vec4(1.0, 0.8, 0.52, 1.0);
uniform float intensity = 0.18;
uniform float seed = 0.0;
uniform float soft_depth = 0.8;

void fragment() {
	float across = max(1.0 - abs(UV.x * 2.0 - 1.0), 0.0);  // (pow of a value rounding below 0 is NaN)
	across = pow(across, 2.2);
	// in from the sky, gone well above the ground: a shaft never reaches the board, so it cannot look
	// like it comes off a unit or a tile
	float along = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.4, 0.62, UV.y));
	float streak = 0.65 + 0.35 * sin(UV.x * 23.0 + seed * 7.0 + TIME * 0.35) * sin(UV.x * 9.0 - seed * 3.0 - TIME * 0.2);
	float flicker = 0.85 + 0.15 * sin(TIME * 0.6 + seed * 5.0);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	world.xyz /= max(abs(world.w), 1e-5) * sign(world.w + 1e-9);  // the sky (far plane) gives w = 0
	float prox = clamp(length(world.xyz - VERTEX) / soft_depth, 0.0, 1.0);
	ALBEDO = shaft_color.rgb * intensity * across * along * streak * flicker * prox;
}
