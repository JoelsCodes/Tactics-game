// The backdrop behind the diorama: a multi-stop radial gradient in screen space, a warm glowing twilight
// amber at the center (just above the board) through dusky rose and slate blue to deep midnight at the
// corners, with a faint grain so the gradient does not band. Only the background: with this backdrop
// Board3D lights the scene with a flat ambient color (the cubemap passes have no screen position).
shader_type sky;


uniform vec4 center_color : source_color = vec4(0.78, 0.48, 0.24, 1.0);  // warm amber glow
uniform vec4 mid_color : source_color = vec4(0.36, 0.22, 0.27, 1.0);    // dusky rose
uniform vec4 slate_color : source_color = vec4(0.15, 0.18, 0.3, 1.0);  // slate blue
uniform vec4 corner_color : source_color = vec4(0.05, 0.06, 0.13, 1.0); // midnight
uniform vec2 center = vec2(0.5, 0.36);  // screen position of the glow (0..1)
uniform float glow_size = 0.95;         // radius scale of the whole gradient
uniform float glow_energy = 1.0;        // brightness of the center (stay under the glow threshold, or it blooms over everything)

void sky() {
	vec2 aspect = vec2(1.78, 1.0);
	float r = length((SCREEN_UV - center) * aspect) / glow_size;
	vec3 c = mix(center_color.rgb * glow_energy, mid_color.rgb, smoothstep(0.0, 0.38, r));
	c = mix(c, slate_color.rgb, smoothstep(0.3, 0.75, r));
	c = mix(c, corner_color.rgb, smoothstep(0.65, 1.15, r));
	c = pow(max(c, vec3(0.0)), vec3(2.2));  // the stops are picked in sRGB; the sky outputs linear light
	float n = fract(sin(dot(SCREEN_UV * 731.7, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = c + (n - 0.5) * 0.004;
}
