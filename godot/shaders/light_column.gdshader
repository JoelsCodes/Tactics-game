shader_type spatial;
// A see-through column of light standing on an affected tile (owner's reference, Nov 2026): bright at the foot, fading
// toward the top, with glowing edges; additive, unshaded. `alpha` is tweened to fade it in and out.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform float alpha = 0.0;
uniform float height = 2.2;
uniform float edge = 0.06;
varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float h = clamp(local.y / height, 0.0, 1.0);
	// distance to the column's vertical edges (the box is 1 x height x 1 around its centre line)
	vec2 xz = abs(local.xz) * 2.0;
	float e = max(xz.x, xz.y);
	float rim = smoothstep(1.0 - edge * 2.0, 1.0, e);
	float rows = 0.55 + 0.45 * sin(local.y * 22.0 - TIME * 6.0);  // faint rising bands
	float fade = mix(1.0, 0.25, h);  // glassy: still visible near the top
	float glint = smoothstep(0.92, 1.0, 1.0 - abs(h - fract(TIME * 0.35)) );  // a soft light sweeping up
	float glow = (0.06 + 0.04 * rows + rim * 0.95 + glint * 0.12) * fade + (1.0 - smoothstep(0.0, 0.04, h)) * 0.35;
	ALBEDO = mix(tint.rgb, vec3(1.0), rim * 0.35) * glow;
	ALPHA = clamp(glow * alpha, 0.0, 1.0);
}
