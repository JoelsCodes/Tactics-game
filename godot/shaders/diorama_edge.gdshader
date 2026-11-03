// The board's cutaway rim (the cross-section along the outer walls): the stone, soil or bedrock texture sinks into a dark
// void colour with depth, and the bottom edge breaks into a ragged, rocky line (a noise cut-off, scissored) instead of a
// straight line, so the island does not end in a hard floating block. Lit like the other faces; only the colour, the
// alpha scissor and the noise differ.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 void_color : source_color = vec4(0.02, 0.015, 0.04, 1.0);
uniform float fade_top = -0.6;      // world y where the fade into the void starts
uniform float fade_bottom = -2.6;   // world y of the board's lowest edge
uniform float void_amount = 0.92;   // how dark the lowest edge gets (1 = the void colour)
uniform float ragged_start = 0.55;  // fraction of the fade where pieces start to drop out
uniform float ragged_scale = 2.6;   // noise cells per world unit along the face

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float depth = clamp((fade_top - wpos.y) / (fade_top - fade_bottom), 0.0, 1.0);
	float along = wpos.x + wpos.z;  // runs along either kind of face
	float n = noise(vec2(along * ragged_scale, wpos.y * 1.3)) * 0.65 + noise(vec2(along * ragged_scale * 2.7, wpos.y * 3.1)) * 0.35;
	float cut = clamp((depth - ragged_start) / (1.0 - ragged_start), 0.0, 1.0);
	ALPHA = (cut > 0.0 && n < cut * 0.95 + 0.02) ? 0.0 : 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float k = smoothstep(0.0, 1.0, depth) * void_amount;
	// the edge of every surviving piece also goes darker, like shadow in the cracks
	float edge = cut > 0.0 ? 1.0 - smoothstep(0.0, 0.2, n - (cut * 0.95 + 0.02)) : 0.0;
	k = max(k, edge * 0.75);
	ALBEDO = mix(t.rgb * tint.rgb, void_color.rgb, k);
	ROUGHNESS = 1.0;
}
