// Neon-blue tile overlay for movement ranges, attack footprints and skill target areas.
// Drawn on a tile's top face (a 4-point polygon, UV (0,0) (1,0) (1,1) (0,1) from the top corner
// clockwise). The vertex COLOR carries which edges are on the outside of the highlighted area
// (r: top-right edge, g: bottom-right, b: bottom-left, a: top-left), so a region glows only along its
// border while the inside keeps a faint tile grid and a soft blue wash.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.2, 0.66, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);  // border and grid lines
uniform float fill = 0.22;       // blue wash over the tile
uniform float edge = 0.95;       // outer border strength
uniform float edge_width = 0.06;
uniform float grid = 0.22;       // thin line on every tile edge
uniform float hatch = 0.0;       // diagonal stripes (attack footprints)
uniform float pulse = 0.0;       // breathing (target areas)
uniform float brackets = 0.0;    // corner brackets (the aimed tile)

float line(float d, float w) {
	return 1.0 - smoothstep(0.0, w, d);
}

void fragment() {
	vec4 flags = COLOR;
	float d0 = UV.y;
	float d1 = 1.0 - UV.x;
	float d2 = 1.0 - UV.y;
	float d3 = UV.x;
	float border = max(max(flags.r * line(d0, edge_width), flags.g * line(d1, edge_width)),
			max(flags.b * line(d2, edge_width), flags.a * line(d3, edge_width)));
	float cell = line(min(min(d0, d1), min(d2, d3)), 0.02);
	float stripes = hatch * step(0.6, fract((UV.x + UV.y) * 4.0 - TIME * 0.5));
	float breathe = 1.0 + pulse * 0.45 * sin(TIME * 4.0);
	float corner = 0.0;
	if (brackets > 0.0) {
		vec2 q = abs(UV - 0.5);
		corner = brackets * step(0.42, max(q.x, q.y)) * step(0.3, min(q.x, q.y));
	}
	float glow = max(border * edge, max(cell * grid, corner));
	float a = clamp(fill * breathe + stripes * 0.16 + glow, 0.0, 0.95);
	vec3 col = mix(tint.rgb, glow_color.rgb, clamp(glow * 1.2, 0.0, 1.0));
	COLOR = vec4(col, a);
}
