shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 deep_water : source_color = vec4(0.046, 0.15, 0.21, 1.0);
uniform vec4 sky_reflection : source_color = vec4(0.34, 0.53, 0.72, 1.0);
uniform float flow_speed = 0.021;
varying vec3 surface_position;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = surface_position.xz;
	vec2 a = texture(ripple_normal, p * vec2(0.10, 0.074) + TIME * vec2(0.004, flow_speed)).rg * 2.0 - 1.0;
	vec2 q = vec2(p.x * 0.74 - p.y * 0.67, p.x * 0.67 + p.y * 0.74);
	vec2 b = texture(ripple_normal, q * vec2(0.21, 0.15) - TIME * vec2(0.008, flow_speed * 0.52)).rg * 2.0 - 1.0;
	vec2 slope = a * 0.85 + b * 0.38;
	vec3 up_view = normalize(mat3(VIEW_MATRIX) * vec3(0.0, 1.0, 0.0));
	vec3 n_world = normalize(vec3(slope.x * 0.78, 1.0, slope.y * 0.82));
	vec3 n_view = normalize(mat3(VIEW_MATRIX) * n_world);
	float fresnel = pow(1.0 - clamp(dot(n_view, VIEW), 0.0, 1.0), 3.0);
	float sky_band = exp(-pow((p.x + 11.0 + (p.y + 17.0) * 0.18) / 9.0, 2.0));
	float gate_band = exp(-pow((p.x - 6.9) / 4.2, 2.0) - pow((p.y + 17.0) / 12.0, 2.0));
	float sparkles = smoothstep(0.029, 0.12, dot(slope, vec2(0.47, 0.88)));
	float horizontal = smoothstep(0.25, 0.85, dot(NORMAL, up_view));
	float bank_distance = abs(abs(p.x) - 16.4);
	float bank_tint = exp(-bank_distance * 0.73) * (1.0 - smoothstep(9.0, 18.0, abs(p.y + 11.0)));
	ALBEDO = mix(deep_water.rgb, vec3(0.032, 0.112, 0.108), bank_tint * 0.58) * (0.80 + 0.30 * sky_band);
	NORMAL = normalize(mix(NORMAL, n_view, horizontal));
	ROUGHNESS = 0.19 + 0.13 * (1.0 - sky_band);
	METALLIC = 0.0;
	SPECULAR = 0.72;
	EMISSION = sky_reflection.rgb * horizontal * (0.085 + fresnel * 0.28 + (sky_band * 0.29 + gate_band * 0.21) * sparkles);
}
