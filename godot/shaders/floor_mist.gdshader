// Low-lying mist over the battlefield floor: a flat sheet just above level 0 with two layers of slowly
// drifting noise. It fades out where it meets the ground and the blocks (proximity fade on the depth
// buffer), so it pools in the low ground and around the feet of cliffs instead of showing an edge.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 mist_color : source_color = vec4(1.0, 0.88, 0.74, 1.0);
uniform float density = 0.4;
uniform float fade_distance = 0.6;  // world units over which the mist fades into geometry
uniform float edge_fade = 1.5;      // world units over which the sheet fades at its borders
uniform vec2 sheet_size = vec2(18.0, 20.0);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = wpos.xz * 0.35;
	float n = fbm(p + vec2(TIME * 0.05, TIME * 0.02)) * 0.6 + fbm(p * 1.7 - vec2(TIME * 0.03, -TIME * 0.04)) * 0.4;
	n = smoothstep(0.35, 0.8, n);
	// proximity fade against whatever is behind the sheet
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	world.xyz /= max(abs(world.w), 1e-5) * sign(world.w + 1e-9);  // the sky (far plane) gives w = 0
	float behind = length(world.xyz - VERTEX);
	float prox = clamp(behind / fade_distance, 0.0, 1.0);
	// fade at the sheet's borders
	vec2 local = abs(UV - 0.5) * sheet_size;
	vec2 border = clamp((sheet_size * 0.5 - local) / edge_fade, 0.0, 1.0);
	ALBEDO = mist_color.rgb;
	ALPHA = n * density * prox * border.x * border.y;
}
