shader_type spatial;
render_mode cull_back, specular_schlick_ggx, depth_draw_never;
// Hollowmark water (Drowned Reliquary canal, Last Terrace Garden stream). Ripples like canal.gdshader, plus screen-space refraction, depth absorption,
// a soft glow and foam where water meets stone. Parameters per map: HollowmarkScenery.MAPS[...].water.
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 shallow : source_color = vec4(0.24, 0.62, 0.48, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.16, 0.13, 1.0);
uniform vec4 glow : source_color = vec4(0.10, 0.55, 0.38, 1.0);
uniform float absorb_depth = 1.6;
uniform float glow_strength = 0.35;
uniform float flow_speed = 0.03;
uniform float foam_strength = 1.0;  // the swamps' wading water is shallow everywhere: a faint foam, not a white sheet (Nov 2026)
uniform float rough = 0.06;  // how glossy the surface is: the overcast swamps and the hideouts' canals take a duller water so the sun does not glitter white over it (Nov 2026)
uniform float spec = 0.6;  // how strongly it mirrors the sun: dulled on the swamps and the wharf so the sun is a soft sheen, not a white sheet
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec2 a = texture(ripple_normal, p * vec2(0.16, 0.12) + TIME * vec2(0.006, flow_speed)).rg * 2.0 - 1.0;
	vec2 b = texture(ripple_normal, vec2(p.x * 0.74 - p.y * 0.67, p.x * 0.67 + p.y * 0.74) * 0.31 - TIME * vec2(0.01, flow_speed * 0.6)).rg * 2.0 - 1.0;
	vec2 slope = a * 0.7 + b * 0.35;
	// depth below the surface along the view ray
	float d_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d_raw, 1.0); v.xyz /= v.w;
	float thickness = max(0.0, -v.z - (-VERTEX.z));
	float k = clamp(thickness / absorb_depth, 0.0, 1.0);
	vec3 refr = texture(screen_tex, SCREEN_UV + slope * 0.012 * (0.3 + k)).rgb;
	vec3 col = mix(refr * shallow.rgb * 1.6, deep.rgb, k * 0.85);
	float foam = (1.0 - smoothstep(0.0, 0.22, thickness)) * (0.55 + 0.45 * smoothstep(0.0, 0.6, abs(slope.x + slope.y))) * foam_strength;
	vec3 n_world = normalize(vec3(slope.x * 0.6, 1.0, slope.y * 0.6));
	NORMAL = normalize(mat3(VIEW_MATRIX) * n_world);
	ALBEDO = mix(col, vec3(0.85, 0.95, 0.92), foam * 0.8);
	ROUGHNESS = mix(rough, 0.4, foam);
	SPECULAR = spec;
	EMISSION = glow.rgb * glow_strength * (0.4 + 0.6 * (1.0 - k)) + vec3(0.25, 0.35, 0.33) * foam * 0.25;
}
