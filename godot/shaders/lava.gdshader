// Molten lava: slow churning glow over a dark crust texture, brighter than lit.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 hot : source_color = vec4(1.0, 0.78, 0.30, 1.0);
uniform vec4 warm : source_color = vec4(0.92, 0.32, 0.08, 1.0);
varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 crust = texture(TEXTURE, UV);
	vec2 p = wp * 0.07;
	float t = TIME * 0.6;
	float n = sin(p.x * 1.7 + t) * sin(p.y * 2.3 - t * 1.3) + 0.5 * sin((p.x - p.y) * 3.1 + t * 2.0);
	float heat = clamp(0.55 + 0.45 * n, 0.0, 1.0);
	float l = dot(crust.rgb, vec3(0.33));
	vec3 col = mix(warm.rgb, hot.rgb, heat);
	col = mix(col, crust.rgb * vec3(0.5, 0.3, 0.25), smoothstep(0.42, 0.62, l) * (1.0 - heat) * 0.8);
	COLOR = vec4(col, 1.0) * COLOR;
}
