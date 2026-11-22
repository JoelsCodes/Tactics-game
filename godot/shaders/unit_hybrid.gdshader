// Hybrid character rendering (HD-2D prototype, Claude, Nov 2026; see UnitView3D.RenderMode.HYBRID). The drawn pixels are shown exactly as drawn
// (nearest filtering, no smoothing, no recolouring of the outline): only the LIGHT on them changes.
//   result = albedo * (fill + env_influence * scene_light)
// `fill` is a flat baseline so no frame goes dark; `scene_light` is the map's own lights (sun, torches, braziers) seen through a wrapped
// (half-Lambert) diffuse so a light from behind still dims the figure instead of blacking it out. The normal is a gentle fake bulge, or the
// frame's own normal map (`normal_tex`, optional).
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_disable;
uniform bool use_normal = false;
uniform vec4 base : source_color = vec4(1.0);   // side tint, KO gray, fade (what Sprite3D.modulate did)
uniform float fill : hint_range(0.0, 1.5) = 0.5;
uniform float env_influence : hint_range(0.0, 2.0) = 1.0;
uniform float wrap : hint_range(0.0, 1.0) = 0.55;
uniform float bulge : hint_range(0.0, 1.5) = 0.55;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.5;
uniform float rim : hint_range(0.0, 1.0) = 0.0;   // optional cool edge light (off by default)
uniform vec4 rim_color : source_color = vec4(0.62, 0.74, 1.0, 1.0);

varying vec2 v_uv;
#include "res://shaders/upright_shear.gdshaderinc"

void vertex() {
	if (shear_upright) {
		upright_shear_vertex(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX, POSITION);
	}
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * base.rgb;
	ALPHA = c.a * base.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;   // cut-out like the original sprite: opaque pass, writes depth (fog, SSAO and depth of field see it)
	vec3 n;
	if (use_normal) {
		vec3 nm = texture(normal_tex, UV).xyz * 2.0 - 1.0;
		n = normalize(vec3(nm.xy * normal_strength, max(nm.z, 0.05)));
	} else {
		vec2 p = (UV - vec2(0.5)) * 2.0;
		n = normalize(vec3(p.x * bulge, -p.y * bulge * 0.6, 1.0));
	}
	NORMAL = n;
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * fill;
	if (rim > 0.0) {
		vec2 px = 1.0 / vec2(textureSize(tex, 0));
		float edge = 1.0 - texture(tex, UV + vec2(-px.x, -px.y)).a;
		EMISSION += rim_color.rgb * edge * rim * (0.35 + dot(c.rgb, vec3(0.333)));
	}
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float w = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * w * env_influence;
}
