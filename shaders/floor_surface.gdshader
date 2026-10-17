shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/fixture_lighting.gdshaderinc"
uniform vec2 light_origin = vec2(0);
uniform vec2 observer_position = vec2(0);
uniform float light_angle = 0.0;
uniform float light_range = 700.0;
uniform float light_power = 1.0;
uniform float half_fov = 0.8063;
uniform sampler2D normal_texture : hint_normal, repeat_enable;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec2 fixture_a = vec2(-100000.0);
uniform vec2 fixture_b = vec2(-100000.0);
uniform vec2 fixture_c = vec2(-100000.0);
uniform vec2 fixture_d = vec2(-100000.0);
uniform vec4 fixture_power = vec4(0.0);
uniform vec2 fixture_e = vec2(-100000.0);
uniform float fixture_power_e = 0.0;
uniform vec2 fixture_f = vec2(-100000.0);
uniform float fixture_power_f = 0.0;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0, 1)).xy; }
void fragment() {
	vec4 surface = texture(TEXTURE, UV);
	float value = dot(surface.rgb, vec3(0.299, 0.587, 0.114));
	vec2 offset = world_point - light_origin;
	float relative = atan(offset.y, offset.x) - light_angle;
	float angle = abs(atan(sin(relative), cos(relative)));
	float cone = 1.0 - smoothstep(half_fov * 0.65, half_fov, angle);
	float reach = 1.0 - smoothstep(light_range * 0.4, light_range, length(offset));
	float pool = exp(-dot(world_point - observer_position, world_point - observer_position) / 18000.0);
	vec3 cold = mix(surface.rgb, vec3(value) * vec3(0.55, 0.73, 0.76), 0.70);
	vec3 warm = mix(surface.rgb, vec3(value) * vec3(1.18, 1.11, 0.88), 0.64);
	vec3 lit = mix(cold * (0.7 + pool * 0.20), warm * (0.95 + reach * 0.28), cone * reach * light_power);
	if (normal_strength > 0.0) {
	vec3 normal = normalize(texture(normal_texture, UV).rgb * 2.0 - 1.0);
	vec3 direction = normalize(vec3(-offset, 140.0));
	float relief = clamp(dot(normal, direction) / max(direction.z, 0.25), 0.72, 1.22);
	lit *= mix(1.0, relief, cone * reach * light_power * normal_strength);
	}
	float lamp_a = fixture_amount(world_point, fixture_a, 0, fixture_power.x);
	float lamp_b = fixture_amount(world_point, fixture_b, 1, fixture_power.y);
	float lamp_c = fixture_amount(world_point, fixture_c, 2, fixture_power.z);
	float lamp_d = fixture_amount(world_point, fixture_d, 3, fixture_power.w);
	float lamp_e = fixture_amount(world_point, fixture_e, 4, fixture_power_e);
	float lamp_f = fixture_amount(world_point, fixture_f, 5, fixture_power_f);
	lit += surface.rgb * vec3(1.1, 0.91, 0.58) * (lamp_a + lamp_b + lamp_c + lamp_d + lamp_e + lamp_f) * 0.65;
	COLOR = vec4(lit, surface.a);
}
