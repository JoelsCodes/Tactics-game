// Stone and ground detail for the terrain faces: a local-contrast boost (high-pass of the texture added
// back, so grain, cracks and grout read deeper), a slow large-scale tint drift so big areas are not
// uniform, and the vertex colors (ambient occlusion, warm light, cast shadows baked by terrain.gd).
shader_type canvas_item;

uniform float detail = 0.7;
uniform float macro = 0.12;
uniform float macro_scale = 0.011;
uniform vec3 macro_warm = vec3(1.06, 1.0, 0.9);
uniform vec3 macro_cool = vec3(0.92, 0.98, 1.06);

varying vec4 vc;
varying vec2 wpos;

void vertex() {
	vc = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * 1.6;
	vec3 blur = (texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb + texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).rgb + texture(TEXTURE, UV - vec2(0.0, px.y)).rgb) * 0.25;
	vec3 c = t.rgb + (t.rgb - blur) * detail * 2.2;
	float n = sin(wpos.x * macro_scale * 2.3 + sin(wpos.y * macro_scale * 3.1)) * 0.5
			+ sin(wpos.y * macro_scale * 1.7 - wpos.x * macro_scale * 0.9) * 0.5;
	c *= mix(macro_cool, macro_warm, n * 0.5 + 0.5) * (1.0 + n * macro);
	COLOR = vec4(max(c, vec3(0.0)) * vc.rgb, t.a * vc.a);
}
