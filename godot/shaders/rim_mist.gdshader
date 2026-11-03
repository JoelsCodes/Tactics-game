// Low mist wrapped around the foot of the floating board: a sheet below the board, larger than it, densest right at the
// rim and thinning out to the sheet's border. Two layers of slowly drifting noise; it also fades where it meets
// geometry (depth buffer), so it softens the board's cutaway edge and the drop below it instead of showing its own edge.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 mist_color : source_color = vec4(0.26, 0.26, 0.46, 1.0);
uniform float density = 0.35;
uniform float fade_distance = 0.7;   // world units over which the mist fades into geometry
uniform float reach = 2.6;           // world units the mist spreads out past the board's rim
uniform vec4 board_rect = vec4(0.0, 0.0, 16.0, 16.0);  // x0, z0, x1, z1 of the board in world units
uniform float drift = 1.0;

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
	vec2 p = wpos.xz * 0.3;
	float n = fbm(p + vec2(TIME * 0.05, TIME * 0.02) * drift) * 0.6 + fbm(p * 1.7 - vec2(TIME * 0.03, -TIME * 0.04) * drift) * 0.4;
	n = smoothstep(0.3, 0.8, n);
	// distance outside the board's rectangle (0 on it and along its rim)
	vec2 lo = board_rect.xy - wpos.xz;
	vec2 hi = wpos.xz - board_rect.zw;
	float out_d = length(max(max(lo, hi), vec2(0.0)));
	float ring = 1.0 - smoothstep(0.0, reach, out_d);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	world.xyz /= max(abs(world.w), 1e-5) * sign(world.w + 1e-9);
	float prox = clamp(length(world.xyz - VERTEX) / fade_distance, 0.0, 1.0);
	ALBEDO = mist_color.rgb;
	ALPHA = (0.35 + 0.65 * n) * density * ring * ring * prox;
}
