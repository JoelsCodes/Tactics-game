// A unit's frame drawn as one flat colour (Claude, Nov 2026): the hit flash (hard edges, white), the afterimages (soft, tinted, fading).
// It reads the frame's own texture and uses only its alpha, so no silhouette picture has to be built on the CPU: building one meant reading
// the texture back from the graphics card the first time each animation frame was seen, which stalled the picture for a moment.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool hard = false;  // true: pixels are fully on or off (the flash), false: the frame's own alpha (afterimages)

void fragment() {
	float a = texture(tex, UV).a;
	if (hard) {
		if (a < 0.5) {
			discard;
		}
		a = 1.0;
	}
	ALBEDO = tint.rgb;
	ALPHA = a * tint.a;
}
