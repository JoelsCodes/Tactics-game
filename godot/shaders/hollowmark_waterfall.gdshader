shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;
// Hollowmark waterfalls (meshes named FX_Waterfall*); top_y / bottom_y set per mesh by HollowmarkScenery. World-space so the exported ribbons need no UVs:
// two noise layers scroll down at different rates and accelerate with the drop; streaky alpha, foam at the lip and the impact.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float top_y = 2.3;
uniform float bottom_y = -1.65;
uniform float speed = 1.1;
uniform vec4 water_tint : source_color = vec4(0.78, 0.94, 0.9, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float t = clamp((top_y - wpos.y) / (top_y - bottom_y), 0.0, 1.0);
	float fall = TIME * speed + t * t * 1.6;
	float s1 = texture(noise_tex, vec2(wpos.x * 0.9, wpos.y * 0.12 + fall)).r;
	float s2 = texture(noise_tex, vec2(wpos.x * 2.3 + 0.37, wpos.y * 0.25 + fall * 1.43)).r;
	float streak = smoothstep(0.35, 0.75, s1 * 0.65 + s2 * 0.5);
	float lip = smoothstep(0.12, 0.0, t);
	float splash = smoothstep(0.8, 1.0, t);
	ALBEDO = water_tint.rgb * (0.7 + 0.5 * streak) + vec3(0.2) * (lip + splash);
	EMISSION = water_tint.rgb * (0.12 + 0.25 * streak + 0.3 * splash);
	ROUGHNESS = 0.15;
	ALPHA = clamp(0.25 + 0.6 * streak + 0.35 * (lip + splash), 0.0, 0.92);
}
