// Diorama finish for the battlefield, drawn over the world and under the HUD: tilt-shift blur toward
// the top and bottom of the screen (a miniature photographed up close), a warm grade, a little extra
// saturation and a soft vignette. Also the cinematic finish: a glow (bloom) around bright pixels, a film
// grade (S-curve contrast, cool shadows, warm highlights) and fine film grain. The glow, grade and grain
// stand in for the glow / color-correction of a WorldEnvironment (which only exists for 3D scenes).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float focus_center = 0.45;  // screen height of the sharp band (0 top, 1 bottom): the space between the HUD bands
uniform float focus_width = 0.24;   // half-height of the sharp band
uniform float blur_px = 3.0;        // blur radius at the edges, in pixels
uniform vec3 warmth = vec3(1.05, 1.0, 0.93);
uniform float saturation = 1.08;
uniform float vignette = 0.32;
uniform float glow_amount = 0.38;      // strength of the bloom added back
uniform float glow_threshold = 0.62;   // brightness where the bloom starts
uniform float glow_radius = 9.0;       // bloom spread in pixels
uniform float contrast = 0.55;         // S-curve strength (0 flat .. 1 strong)
uniform vec3 shadow_tint = vec3(0.86, 0.93, 1.06);     // multiplies the darks (moody blue)
uniform vec3 highlight_tint = vec3(1.08, 1.0, 0.9);    // multiplies the lights (warm gold)
uniform float grain = 0.035;

const vec2 TAPS[12] = vec2[](
	vec2(1.0, 0.0), vec2(0.5, 0.866), vec2(-0.5, 0.866), vec2(-1.0, 0.0), vec2(-0.5, -0.866), vec2(0.5, -0.866),
	vec2(0.5, 0.0), vec2(0.25, 0.433), vec2(-0.25, 0.433), vec2(-0.5, 0.0), vec2(-0.25, -0.433), vec2(0.25, -0.433));

void fragment() {
	float off = abs(SCREEN_UV.y - focus_center);
	float amount = smoothstep(focus_width, focus_width + 0.3, off);
	vec3 c = texture(screen, SCREEN_UV).rgb;
	if (amount > 0.01) {
		vec2 r = SCREEN_PIXEL_SIZE * blur_px * amount;
		vec3 sum = c;
		for (int i = 0; i < 12; i++) {
			sum += texture(screen, SCREEN_UV + TAPS[i] * r).rgb;
		}
		c = sum / 13.0;
	}
	// bloom: bright pixels sampled on two rings
	vec3 bloom = vec3(0.0);
	vec2 gr = SCREEN_PIXEL_SIZE * glow_radius;
	for (int i = 0; i < 6; i++) {
		vec3 a = texture(screen, SCREEN_UV + TAPS[i] * gr).rgb;
		vec3 b = texture(screen, SCREEN_UV + TAPS[i] * gr * 2.2).rgb;
		bloom += max(a - vec3(glow_threshold), 0.0) + max(b - vec3(glow_threshold), 0.0) * 0.7;
	}
	c += bloom / 6.0 * glow_amount * 2.0;
	c *= warmth;
	// grade: smooth S-curve, then split-tone by luminance
	c = mix(c, c * c * (3.0 - 2.0 * c), contrast);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tint, highlight_tint, smoothstep(0.15, 0.75, lum));
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.35, 0.85, length(v * vec2(1.0, 0.8)));
	float n = fract(sin(dot(SCREEN_UV * vec2(1731.0, 947.0) + fract(TIME) * 13.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
