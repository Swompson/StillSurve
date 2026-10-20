shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/fixture_lighting.gdshaderinc"

uniform float ambient_radius = 108.0;
uniform float beam_strength = 1.0;
uniform float beam_range = 700.0;
uniform float fade_start = 420.0;
uniform vec2 ambient_center = vec2(0.0);
uniform float ambient_softness = 24.0;
uniform float facing_angle = 0.0;
uniform float half_fov = 1.0472;
uniform float angular_feather = 0.20944;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 fixture_a = vec2(-100000.0);
uniform vec2 fixture_b = vec2(-100000.0);
uniform vec2 fixture_c = vec2(-100000.0);
uniform vec2 fixture_d = vec2(-100000.0);
uniform vec4 fixture_power = vec4(0.0);
uniform vec2 fixture_e = vec2(-100000.0);
uniform float fixture_power_e = 0.0;
uniform vec2 fixture_f = vec2(-100000.0);
uniform float fixture_power_f = 0.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Fully occluded triangles already determine the final fog alpha.
	if (COLOR.a >= 1.0) {
		COLOR = fog_color;
	} else {
		float relative_angle = atan(local_position.y, local_position.x) - facing_angle;
		float angle_distance = abs(atan(sin(relative_angle), cos(relative_angle)));
		float edge_alpha = smoothstep(max(half_fov - angular_feather, 0.0), half_fov, angle_distance);
		if (half_fov >= 3.1415) { edge_alpha = 1.0; }
		float radial_fade = smoothstep(fade_start, beam_range, length(local_position));
		edge_alpha = max(edge_alpha, radial_fade);
		edge_alpha = mix(1.0, edge_alpha, beam_strength);
		edge_alpha *= smoothstep(max(ambient_radius - ambient_softness, 0.0), ambient_radius, distance(local_position, ambient_center));
		float lamp_a = fixture_amount(local_position, fixture_a, 0, fixture_power.x);
		float lamp_b = fixture_amount(local_position, fixture_b, 1, fixture_power.y);
		float lamp_c = fixture_amount(local_position, fixture_c, 2, fixture_power.z);
		float lamp_d = fixture_amount(local_position, fixture_d, 3, fixture_power.w);
		float lamp_e = fixture_amount(local_position, fixture_e, 4, fixture_power_e);
		float lamp_f = fixture_amount(local_position, fixture_f, 5, fixture_power_f);
		edge_alpha *= 1.0 - clamp(max(max(max(lamp_a, lamp_b), max(lamp_c, lamp_d)), max(lamp_e, lamp_f)), 0.0, 0.96);
		// Mesh alpha fades inward from wall surfaces; opaque geometry hides everything behind them.
		float alpha = max(COLOR.a, edge_alpha);
		COLOR = vec4(fog_color.rgb, fog_color.a * alpha);
	}
}
