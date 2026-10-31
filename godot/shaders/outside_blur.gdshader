shader_type canvas_item;
// Blurs the screen outside a convex outline: `hull` holds `hull_n` corners in pixels, counter-clockwise in the sense
// that a point is inside when every edge has it on its left. Inside the outline the picture is left sharp; across
// `feather` pixels it turns into the blur. Used by OutsideBlur (scripts/stage/outside_blur.gd).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 hull[8];
uniform int hull_n = 4;
uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform float blur_px = 10.0;
uniform float feather = 36.0;

const int TAPS = 24;
const float LOD = 2.0;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	vec2 p = SCREEN_UV * view_size;
	bool inside = true;
	float edge = 1e9;
	for (int i = 0; i < 8; i++) {
		if (i >= hull_n) {
			break;
		}
		vec2 a = hull[i];
		vec2 b = hull[(i + 1) % hull_n];
		vec2 e = b - a;
		if (e.x * (p.y - a.y) - e.y * (p.x - a.x) < 0.0) {
			inside = false;
		}
		edge = min(edge, segment_distance(p, a, b));
	}

	vec3 sharp = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 soft = vec3(0.0);
	for (int i = 0; i < TAPS; i++) {
		// sunflower spiral of taps over the blur disc
		float r = sqrt((float(i) + 0.5) / float(TAPS)) * blur_px;
		float a = float(i) * 2.39996323;
		soft += textureLod(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * r / view_size, LOD).rgb;
	}
	soft /= float(TAPS);

	float outside = smoothstep(-feather, feather, inside ? -edge : edge);
	COLOR = vec4(mix(sharp, soft, outside), 1.0);
}
