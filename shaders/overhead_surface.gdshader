shader_type canvas_item;
render_mode unshaded;
uniform vec2 camera_center = vec2(0.0);
uniform float elevation = 0.018;
uniform float exposure = 0.65;
uniform bool projection_enabled = false;
varying vec4 surface_tint;
void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// Project ceiling spans and their mounts together above the floor plane.
	vec2 offset = clamp((world - camera_center) * elevation, vec2(-20.0), vec2(20.0));
	if (projection_enabled) { VERTEX += offset; }
	surface_tint = COLOR;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	COLOR = vec4(texel.rgb * exposure, texel.a) * surface_tint;
}
