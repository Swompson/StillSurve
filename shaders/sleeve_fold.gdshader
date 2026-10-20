shader_type canvas_item;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float edge = length(point);
	COLOR.a *= 1.0 - smoothstep(0.65, 1.0, edge);
}
