// Stands a camera-facing sprite upright ON SCREEN without turning it (Claude, Nov 2026, owner: "why does he look slanted").
// A perspective camera makes a vertical line away from the screen's middle lean outward. Turning the whole sprite back about the view axis
// (Board3D.upright_orient) straightens its columns but tilts its rows, so the pixel art reads as slanted. Instead the sprite keeps the plain
// fixed-Y billboard orientation (rows level on screen) and each vertex is slid sideways in clip space by how far the sprite's centre column has
// drifted at that height from where it stands at the feet (the model's origin): columns vertical, rows level, every pixel square.
uniform bool shear_upright = false;

void upright_shear_vertex(vec3 v, mat4 modelview, mat4 projection, inout vec4 position) {
	vec4 p = projection * (modelview * vec4(v, 1.0));
	vec4 ct = projection * (modelview * vec4(0.0, v.y, 0.0, 1.0));
	vec4 cf = projection * (modelview * vec4(0.0, 0.0, 0.0, 1.0));
	p.x -= (ct.x / ct.w - cf.x / cf.w) * p.w;
	position = p;
}
