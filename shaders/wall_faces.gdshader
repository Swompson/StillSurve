shader_type canvas_item;
render_mode unshaded;
uniform vec2 light_origin = vec2(0);
uniform vec2 observer_position = vec2(0);
uniform float light_angle = 0.0;
uniform float light_range = 700.0;
uniform float light_power = 1.0;
uniform float half_fov = 0.8063;
uniform float angular_feather = 0.20944;
uniform float ambient_radius = 180.0;
uniform float ambient_softness = 72.0;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0, 1)).xy; }
void fragment() {
	vec2 offset = world_point - light_origin;
	float relative = atan(offset.y, offset.x) - light_angle;
	float angle = abs(atan(sin(relative), cos(relative)));
	float cone = 1.0 - smoothstep(max(0.0, half_fov - angular_feather), half_fov, angle);
	float reach = 1.0 - smoothstep(light_range * 0.45, light_range, length(offset));
	float ambient = 1.0 - smoothstep(max(0.0, ambient_radius - ambient_softness), ambient_radius, distance(world_point, observer_position));
	float illumination = cone * reach * light_power;
	vec3 surface = mix(vec3(0.10, 0.14, 0.14), vec3(0.86, 0.82, 0.64), illumination);
	float opacity = max(ambient * 0.18, illumination * 0.64);
	COLOR = vec4(surface, COLOR.a * opacity);
}
