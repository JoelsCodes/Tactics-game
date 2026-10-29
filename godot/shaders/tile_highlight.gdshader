// Neon-blue floor highlight for movement ranges, attack footprints and skill target areas.
// Drawn on a tile's top face (a 4-point polygon, UV (0,0) (1,0) (1,1) (0,1) from the top corner
// clockwise). The vertex COLOR carries which edges are on the outside of the highlighted area
// (r: top-right edge, g: bottom-right, b: bottom-left, a: top-left), so a region glows along its
// border: a bright core line with a soft falloff inward, while the inside keeps a faint tile grid,
// a pale diamond inlay and a slow light sweep that runs over the whole region (from world position).
// Premultiplied blending: the light adds blue and takes a little of the ground color under it, so the
// neon stays blue on bright grass and the stone detail still shows through.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 tint : source_color = vec4(0.2, 0.66, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);  // border and grid lines
uniform float fill = 0.22;       // blue wash over the tile
uniform float edge = 0.95;       // outer border strength
uniform float edge_width = 0.05; // core line width (UV units)
uniform float edge_glow = 0.28;  // how far the soft glow reaches inward
uniform float grid = 0.22;       // thin line on every tile edge
uniform float hatch = 0.0;       // diagonal stripes (attack footprints)
uniform float pulse = 0.0;       // breathing (target areas)
uniform float brackets = 0.0;    // corner brackets (the aimed tile)

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
	// distance to the nearest outer edge (large when no edge is on the border)
	float db = min(min(mix(9.0, d0, flags.r), mix(9.0, d1, flags.g)), min(mix(9.0, d2, flags.b), mix(9.0, d3, flags.a)));
	float core = line(db, edge_width) * edge;
	float soft = exp(-db / edge_glow * 3.0) * edge * 0.55;
	float dc = min(min(d0, d1), min(d2, d3));
	float cell = line(dc, 0.025);
	// diamond inlay and a faint inner ring: geometric floor-sigil feel
	float dia = abs(UV.x - 0.5) + abs(UV.y - 0.5);
	float ring = line(abs(dia - 0.3), 0.02) * 0.35 + line(abs(dia - 0.12), 0.015) * 0.25;
	// light sweep across the region in world space
	float sweep = pow(0.5 + 0.5 * sin((wpos.x + wpos.y * 1.7) * 0.045 - TIME * 1.6), 6.0);
	float stripes = hatch * step(0.6, fract((UV.x + UV.y) * 4.0 - TIME * 0.5));
	float breathe = 1.0 + pulse * 0.45 * sin(TIME * 4.0);
	float corner = 0.0;
	if (brackets > 0.0) {
		vec2 q = abs(UV - 0.5);
		corner = brackets * step(0.42, max(q.x, q.y)) * step(0.3, min(q.x, q.y));
	}
	float body = fill * breathe * (0.78 + 0.35 * sweep) + stripes * 0.14;
	float lines = max(max(core, cell * grid), max(corner, ring * grid * 2.0));
	vec3 col = tint.rgb * (body + soft) + glow_color.rgb * lines * (1.0 + 0.5 * sweep);
	// hot white core on the outer line
	col += vec3(0.6, 0.85, 1.0) * core * core * 0.5;
	float a = clamp(body * 1.15 + soft * 0.8 + lines * 0.7, 0.0, 0.88);
	COLOR = vec4(min(col, vec3(a + 0.35)), a);
}
