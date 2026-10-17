shader_type canvas_item;
render_mode unshaded;
uniform vec2 patch_size = vec2(51.8);
varying vec2 joint_uv;
void vertex() {
	joint_uv = VERTEX / patch_size + vec2(0.5);
}
void fragment() {
	vec4 patch = texture(TEXTURE, UV);
	patch.a *= 1.0 - smoothstep(0.34, 0.49, length(joint_uv - vec2(0.5)));
	COLOR = patch;
}
