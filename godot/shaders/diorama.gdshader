// Diorama finish for the battlefield, drawn over the world and under the HUD: tilt-shift blur toward
// the top and bottom of the screen (a miniature photographed up close), a warm grade, a little extra
// saturation and a soft vignette.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float focus_center = 0.5;   // screen height of the sharp band (0 top, 1 bottom)
uniform float focus_width = 0.2;    // half-height of the sharp band
uniform float blur_px = 3.0;        // blur radius at the edges, in pixels
uniform vec3 warmth = vec3(1.05, 1.0, 0.93);
uniform float saturation = 1.08;
uniform float vignette = 0.32;

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
	c *= warmth;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.35, 0.85, length(v * vec2(1.0, 0.8)));
	COLOR = vec4(c, 1.0);
}
