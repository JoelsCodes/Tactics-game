// Whole-frame look (prototype, reversible): tilt-shift blur toward the top and bottom edges, a split-tone grade (cool shadows, warm highlights),
// a touch more contrast and saturation, bloom on the bright things, and a vignette. Sits under the HUD (CanvasLayer -1), over the 3D picture,
// sprites included, so the characters and the world share one image. LookPost (scripts/stage/look_post.gd) adds it; nothing else uses it.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_px = 5.0;          // blur radius at the very top/bottom, in screen pixels
uniform float focus_center = 0.52;    // screen height of the sharp band's middle (0 top .. 1 bottom)
uniform float focus_half = 0.26;       // half the height of the fully sharp band
uniform float contrast = 1.06;
uniform float saturation = 1.1;
uniform vec3 shadow_tint : source_color = vec3(0.80, 0.92, 1.10);
uniform vec3 light_tint : source_color = vec3(1.10, 1.02, 0.88);
uniform float bloom = 0.22;
uniform float vignette = 0.3;
uniform float exposure = 1.15;

const vec2 TAPS[12] = vec2[](vec2(0.0, 0.0), vec2(0.5, 0.0), vec2(-0.5, 0.0), vec2(0.0, 0.5), vec2(0.0, -0.5), vec2(0.35, 0.35), vec2(-0.35, 0.35), vec2(0.35, -0.35), vec2(-0.35, -0.35), vec2(0.9, 0.0), vec2(-0.9, 0.0), vec2(0.0, 0.9));

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float d = abs(SCREEN_UV.y - focus_center);
	float k = smoothstep(focus_half, 0.5, d);
	vec3 c = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 12; i++) {
		vec2 o = TAPS[i] * 2.0 * blur_px * k;
		c += texture(screen_tex, SCREEN_UV + o * px).rgb;
		wsum += 1.0;
	}
	c /= wsum;
	// bloom: a wide soft read of what is brighter than ~0.7
	vec3 g = vec3(0.0);
	for (int i = 1; i < 9; i++) {
		vec3 s = texture(screen_tex, SCREEN_UV + TAPS[i] * 26.0 * px).rgb;
		g += max(s - vec3(0.7), vec3(0.0));
	}
	c += g / 8.0 * bloom * 3.0;
	// split-tone grade
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= exposure;
	c *= mix(shadow_tint, light_tint, smoothstep(0.15, 0.75, l));
	l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	// vignette
	vec2 q = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.85, length(q * vec2(1.0, 1.2)));
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
