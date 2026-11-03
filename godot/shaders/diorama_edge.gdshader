// The board's cutaway rim (the cross-section along the outer walls): a rocky, earthy cliff face instead of a flat texture. Strata
// lines, dark crevices and moss near the top break up the tile texture; with depth it sinks into a dark void colour, and the lowest
// part dissolves away completely (alpha, with a ragged noise edge) into the mist and the backdrop, so the island has a soft,
// magical drop-off rather than a cut-off. Lit like the other faces.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 void_color : source_color = vec4(0.03, 0.025, 0.08, 1.0);
uniform float fade_top = -0.5;      // world y where the sinking into the void starts
uniform float fade_bottom = -2.6;   // world y of the board's lowest edge
uniform float void_amount = 1.0;    // how dark the lowest edge gets (1 = the void colour)
uniform float dissolve_start = 0.6; // fraction of the fade where the rock starts to dissolve
uniform float ragged_scale = 2.4;   // noise cells per world unit along the face

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
	float along = wpos.x + wpos.z;  // runs along either kind of face
	float depth = clamp((fade_top - wpos.y) / (fade_top - fade_bottom), 0.0, 1.0);
	float n = noise(vec2(along * ragged_scale, wpos.y * 1.3)) * 0.65 + noise(vec2(along * ragged_scale * 2.7, wpos.y * 3.1)) * 0.35;
	// rock character: strata, crevices, moss under the grass line
	float strata = sin(wpos.y * 11.0 + noise(vec2(along * 1.7, wpos.y * 2.0)) * 4.0) * 0.5 + 0.5;
	float crev = noise(vec2(along * 5.0, wpos.y * 4.5));
	vec3 c = t.rgb * tint.rgb;
	c *= mix(0.82, 1.08, strata * 0.5 + crev * 0.5);
	c *= mix(0.62, 1.05, smoothstep(0.15, 0.55, crev));
	float moss = (1.0 - clamp(-wpos.y / 0.55, 0.0, 1.0)) * smoothstep(0.3, 0.7, noise(vec2(along * 3.0, wpos.y * 2.0)));
	c = mix(c, vec3(0.2, 0.36, 0.1) * (0.6 + 0.6 * crev), moss * 0.55);
	// into the void, and out of existence at the bottom, the break line wandering with the noise
	float e = depth + (n - 0.5) * 0.45 * smoothstep(0.25, 0.8, depth);
	float k = smoothstep(0.1, 0.95, e) * void_amount;
	ALBEDO = mix(c, void_color.rgb, k);
	ALPHA = 1.0 - smoothstep(dissolve_start, 0.98, e);
	ROUGHNESS = 1.0;
}
