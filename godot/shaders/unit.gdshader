// Unit sprite: palette swap of one hue band (FFT-style job colors from one sprite),
// hit flash, knocked-out gray, and a waterline cut when wading.
shader_type canvas_item;

uniform bool recolor = false;
uniform float src_hue = 0.58;      // hue of the band to swap (0..1)
uniform float band = 0.085;        // half-width of the band
uniform vec3 dst = vec3(0.58, 1.0, 1.0); // new hue, saturation multiplier, value multiplier
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
	if (recolor) {
		vec3 h = rgb2hsv(c.rgb);
		float d = abs(h.x - src_hue);
		d = min(d, 1.0 - d);
		float w = (1.0 - smoothstep(band * 0.65, band, d)) * smoothstep(0.12, 0.28, h.y);
		vec3 n = vec3(dst.x, clamp(h.y * dst.y, 0.0, 1.0), clamp(h.z * dst.z, 0.0, 1.0));
		c.rgb = mix(c.rgb, hsv2rgb(n), w);
	}
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l) * vec3(0.78, 0.8, 0.9), gray);
	c.rgb = mix(c.rgb, flash_color.rgb, flash_color.a);
	COLOR = c * COLOR;
}
