// Water surface over a riverbed texture. Waves use world coordinates so they
// flow across tile borders. depth 0 = shallows (bed visible), 1 = deep.
shader_type canvas_item;

uniform vec4 shallow : source_color = vec4(0.30, 0.62, 0.78, 0.55);
uniform vec4 deep : source_color = vec4(0.08, 0.24, 0.44, 0.92);
uniform float depth = 0.0;
varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 bed = texture(TEXTURE, UV);
	vec2 p = wp * vec2(0.09, 0.18);
	float t = TIME;
	float a = sin(p.x * 1.3 + p.y * 0.7 + t * 1.4);
	float b = sin(p.x * -0.8 + p.y * 1.6 - t * 1.1);
	float c = sin((p.x + p.y) * 2.1 + t * 2.3);
	float waves = (a + b) * 0.25 + 0.5;
	float glint = smoothstep(0.82, 1.0, waves * (0.5 + 0.5 * c));
	vec4 w = mix(shallow, deep, depth);
	vec3 col = mix(bed.rgb * vec3(0.7, 0.85, 0.9), w.rgb, w.a);
	col *= 0.92 + 0.12 * waves;
	col += vec3(0.75, 0.9, 1.0) * glint * 0.45;
	COLOR = vec4(col, 1.0) * COLOR;
}
