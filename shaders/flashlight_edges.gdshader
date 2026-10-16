shader_type canvas_item;
render_mode unshaded;

uniform float ambient_radius = 108.0;
uniform vec2 ambient_center = vec2(0.0);
uniform float ambient_softness = 24.0;
uniform float facing_angle = 0.0;
uniform float half_fov = 1.0472;
uniform float angular_feather = 0.20944;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float relative_angle = atan(local_position.y, local_position.x) - facing_angle;
	float angle_distance = abs(atan(sin(relative_angle), cos(relative_angle)));
	float edge_alpha = smoothstep(max(half_fov - angular_feather, 0.0), half_fov, angle_distance);
	if (half_fov >= 3.1415) { edge_alpha = 1.0; }
	edge_alpha *= smoothstep(max(ambient_radius - ambient_softness, 0.0), ambient_radius, distance(local_position, ambient_center));
	// Mesh alpha fades inward from wall surfaces; opaque geometry hides everything behind them.
	float alpha = max(COLOR.a, edge_alpha);
	COLOR = vec4(fog_color.rgb, fog_color.a * alpha);
}
