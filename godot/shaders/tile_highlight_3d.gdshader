// Neon-blue floor highlight on the 3D board (the 3D twin of tile_highlight.gdshader): one quad per
// tile, laid just above its top. UV (0,0) (1,0) (1,1) (0,1) run along grid +x then +y, and the vertex
// COLOR says which edges are on the outside of the highlighted region (r: the -y edge, g: +x, b: +y,
// a: -x), so a region glows along its border: a bright core line with a soft falloff inward, a faint
// tile grid, a diamond inlay and a slow light sweep over the whole region (from world position), plus
// the classic tactics-RPG overlay: bright cyan grid lines on every tile edge, a breathing pulse and thin
// scanlines that roll across the range.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.2, 0.66, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform float fill = 0.22;
uniform float edge = 0.95;
uniform float edge_width = 0.05;
uniform float edge_glow = 0.28;
uniform float grid = 0.22;
uniform float hatch = 0.0;
uniform float pulse = 0.0;
uniform float brackets = 0.0;
uniform float grid_glow = 0.55;   // the cyan line on every tile edge (inner edges included)
uniform float scanlines = 0.5;    // rolling scanline strength
uniform float breathe_all = 0.18; // a slow pulse on the whole overlay

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float d, float w) {
	return 1.0 - smoothstep(0.0, w, d);
}

void fragment() {
	vec4 flags = COLOR;
	float d0 = UV.y;
	float d1 = 1.0 - UV.x;
	float d2 = 1.0 - UV.y;
	float d3 = UV.x;
	float db = min(min(mix(9.0, d0, flags.r), mix(9.0, d1, flags.g)), min(mix(9.0, d2, flags.b), mix(9.0, d3, flags.a)));
	float core = line(db, edge_width) * edge;
	float soft = exp(-db / edge_glow * 3.0) * edge * 0.55;
	float dc = min(min(d0, d1), min(d2, d3));
	float cell = line(dc, 0.035);
	float cell_soft = exp(-dc * 18.0) * 0.5;
	float dia = abs(UV.x - 0.5) + abs(UV.y - 0.5);
	float ring = line(abs(dia - 0.3), 0.02) * 0.35 + line(abs(dia - 0.12), 0.015) * 0.25;
	float sweep = pow(0.5 + 0.5 * sin((wpos.x + wpos.z) * 1.4 - TIME * 1.6), 6.0);
	float stripes = hatch * step(0.6, fract((UV.x + UV.y) * 4.0 - TIME * 0.5));
	float breathe = 1.0 + pulse * 0.45 * sin(TIME * 4.0);
	float corner = 0.0;
	if (brackets > 0.0) {
		vec2 q = abs(UV - 0.5);
		corner = brackets * step(0.42, max(q.x, q.y)) * step(0.3, min(q.x, q.y));
	}
	// scanlines: thin bright bands rolling across the board (world space, so they cross tiles seamlessly)
	float scan = pow(0.5 + 0.5 * sin((wpos.x - wpos.z) * 22.0 - TIME * 6.0), 12.0) * scanlines;
	float roll = smoothstep(0.85, 1.0, sin((wpos.x + wpos.z) * 0.35 - TIME * 1.2)) * scanlines;
	float pulse_all = 1.0 + breathe_all * sin(TIME * 2.4);
	float body = (fill * breathe * (0.78 + 0.35 * sweep) + stripes * 0.14 + scan * 0.18 + roll * 0.25) * pulse_all;
	float lines = max(max(core, max(cell, cell_soft) * max(grid, grid_glow) * pulse_all), max(corner, ring * grid * 2.0));
	vec3 col = tint.rgb * (body + soft) + glow_color.rgb * lines * (1.0 + 0.5 * sweep);
	col += vec3(0.6, 0.85, 1.0) * core * core * 0.5;
	float a = clamp(body * 1.15 + soft * 0.8 + lines * 0.7, 0.0, 0.88);
	// emit the light (HDR, so the glow pass blooms the border lines)
	ALBEDO = min(col / max(a, 0.05), vec3(1.6));
	ALPHA = a;
}
