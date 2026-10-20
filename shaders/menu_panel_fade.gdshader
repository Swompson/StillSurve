shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(700.0, 500.0);
uniform float feather = 64.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 edge = min(local_position, panel_size - local_position);
	vec2 fade = smoothstep(vec2(0.0), vec2(feather), edge);
	COLOR.a *= fade.x * fade.y;
}
