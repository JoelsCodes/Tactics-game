// Frosted glass for the HUD panels: wherever the panel texture is translucent (its glass center), the
// game behind it is shown blurred (a low mip of the screen) and tinted, then the panel is laid over it.
// The stone frame and gold trim stay as drawn; outside the panel's rounded corners nothing is drawn.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 3.2;
uniform vec4 frost_tint : source_color = vec4(0.04, 0.06, 0.12, 1.0);
uniform float frost_mix = 0.35;
uniform float frost_light = 1.08;

varying vec4 vc;

void vertex() {
	vc = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV) * vc;
	vec3 bg = textureLod(screen, SCREEN_UV, blur_lod).rgb * frost_light;
	bg = mix(bg, frost_tint.rgb, frost_mix);
	vec3 c = mix(bg, t.rgb, t.a);
	COLOR = vec4(c, clamp(t.a * 6.0, 0.0, 1.0));
}
