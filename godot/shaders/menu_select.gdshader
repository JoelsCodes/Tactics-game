shader_type canvas_item;
// The lit bar of the battle's command menu (Nov 2026): polished enchanted steel. A chamfered bar (the tips at mid height) with a navy-to-slate
// gradient, extremely faint brushed streaks (only here: the other bars are plain engraved steel), a thin icy outline lit steadily, a soft glow
// outside it, a faint shimmer travelling along the lower edge, and a brief flash when the command is confirmed.
// The rect it fills is the bar plus `pad` pixels all round, for the glow; `rect_size` is that rect's size in pixels.

uniform vec2 rect_size = vec2(300.0, 56.0);
uniform float pad = 10.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ice = vec3(0.55, 0.85, 1.0);
uniform vec3 navy = vec3(0.045, 0.110, 0.215);
uniform vec3 slate = vec3(0.190, 0.310, 0.440);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Distance to the bar's edge, negative inside. p is from the bar's centre, b the bar's size; the chamfer is 45 degrees.
float sd_bar(vec2 p, vec2 b) {
	vec2 q = abs(p);
	float h = b.y * 0.5;
	float c = h;
	float d_top = q.y - h;
	vec2 n = normalize(vec2(h, c));
	float d_slant = dot(vec2(q.x - (b.x * 0.5 - c), q.y - h), n);
	return max(d_top, d_slant);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 bar = rect_size - vec2(pad * 2.0);
	float sd = sd_bar(px - rect_size * 0.5, bar);
	float inside = 1.0 - smoothstep(-0.6, 0.6, sd);
	float y = clamp((px.y - pad) / bar.y, 0.0, 1.0);
	vec3 col = mix(navy, slate, smoothstep(0.0, 1.0, y));
	// brushed metal: long horizontal streaks, kept very faint
	float streak = hash(vec2(floor(px.y * 0.9), floor(px.x * 0.035)));
	float fine = hash(vec2(floor(px.y * 2.3), floor(px.x * 0.012 + 3.0)));
	col += (streak - 0.5) * 0.04 + (fine - 0.5) * 0.025;
	// a faint inner glow just inside the outline, and a polished sheen on the upper half
	col += ice * smoothstep(8.0, 0.0, -sd) * 0.20;
	col += vec3(0.7, 0.85, 1.0) * smoothstep(0.55, 0.0, y) * 0.045;
	// the shimmer travelling along the lower edge
	float cycle = fract(TIME * 0.32);
	float sx = (cycle * 1.6 - 0.3) * bar.x + pad;
	float dx = (px.x - sx) / (bar.x * 0.10);
	float band = exp(-dx * dx);
	float low = smoothstep(4.0, 0.0, (pad + bar.y) - px.y);
	col += vec3(0.75, 0.92, 1.0) * band * low * 0.5;
	// the outline: thin, icy, steady (a very slow breath, a few percent)
	float breathe = 0.95 + 0.05 * sin(TIME * 1.4);
	float line = 1.0 - smoothstep(0.0, 1.7, abs(sd + 1.0));
	col = mix(col, ice * breathe, line * 0.95);
	float glow = exp(-max(sd, 0.0) / 4.0) * 0.46 * breathe * (1.0 - inside);
	col = mix(col, vec3(1.0), flash * 0.6 * inside);
	COLOR = vec4(mix(ice, col, inside), max(inside, glow));
}
