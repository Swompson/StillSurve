shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(780.0, 500.0);
uniform float feather = 42.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 edge = min(local_position, panel_size - local_position);
	COLOR.a *= smoothstep(0.0, feather, min(edge.x, edge.y));
}
