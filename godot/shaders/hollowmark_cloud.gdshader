shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
// Hollowmark cloud bank (Last Terrace Garden): a flat card under the cliff, noise shaped, soft edges, drifting slowly.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.97, 0.98, 1.0, 1.0);
uniform float drift = 0.004;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float edge = clamp(1.0 - dot(c, c), 0.0, 1.0);
	float n = texture(noise_tex, UV * 1.3 + TIME * vec2(drift, drift * 0.6)).r * 0.65 + texture(noise_tex, UV * 3.1 - TIME * drift).r * 0.35;
	ALBEDO = tint.rgb * (0.86 + 0.14 * n);
	ALPHA = clamp(smoothstep(0.25, 0.75, n) * edge * 1.3, 0.0, 0.92);
}
