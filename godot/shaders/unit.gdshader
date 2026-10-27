// Unit sprite: optional color tint (so one character sheet can play several roles),
// hit flash, knocked-out gray, and a waterline cut when wading.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0); // rgb = tint color, a = amount
uniform float hue_shift = 0.0;     // 0..1 around the color wheel
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float gray = 0.0;
uniform float cut = 2.0;           // texture v below which pixels are under water

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.a *= 1.0 - smoothstep(cut - 0.004, cut + 0.004, UV.y);
	if (hue_shift != 0.0) {
		vec3 h = rgb2hsv(c.rgb);
		h.x = fract(h.x + hue_shift);
		c.rgb = hsv2rgb(h);
	}
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, c.rgb * tint.rgb * 1.6, tint.a);
	c.rgb = mix(c.rgb, vec3(l) * vec3(0.78, 0.8, 0.9), gray);
	c.rgb = mix(c.rgb, flash_color.rgb, flash_color.a * step(0.05, c.a));
	COLOR = c * COLOR;
}
