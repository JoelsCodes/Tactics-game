// Contact shadow under a unit's boots (see UnitView3D, hybrid mode): a dark tight core where the soles touch plus a wider soft penumbra,
// a little longer toward the way the sun's shadows fall. Multiplies the floor (and any glass) darker; never draws light.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, blend_mix, cull_disabled;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0;
	float d = length(q);
	float core = 1.0 - smoothstep(0.0, 0.42, d);
	float halo = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = vec3(0.015, 0.015, 0.03);
	ALPHA = strength * clamp(core * 0.85 + halo * halo * 0.45, 0.0, 1.0);
}
