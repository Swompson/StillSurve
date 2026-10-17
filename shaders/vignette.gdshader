shader_type canvas_item;
render_mode unshaded;
uniform float strength : hint_range(0.0, 1.0) = 0.48;
void fragment() {
	vec2 position = (UV - 0.5) * 2.0;
	float edge = smoothstep(0.42, 1.38, length(position * vec2(0.88, 1.0)));
	COLOR = vec4(0.006, 0.009, 0.012, edge * strength);
}
