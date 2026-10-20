shader_type canvas_item;
render_mode unshaded;

uniform bool use_detail_texture = false;
uniform bool editor_preview = false;
uniform sampler2D detail_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 detail_tint : source_color = vec4(0.68, 0.70, 0.65, 1.0);
uniform float detail_texels_per_unit = 5.5;
uniform vec2 detail_uv_offset = vec2(0.0);
uniform float detail_uv_angle = 0.0;
varying vec2 detail_position;
varying vec2 stone_metric_scale;
uniform bool stone_relief = false;
uniform vec2 stone_outline[8];

void vertex() {
	// Rotate in world-sized local coordinates, including nonuniform prop scale.
	detail_position = VERTEX * vec2(length(MODEL_MATRIX[0].xy), length(MODEL_MATRIX[1].xy));
	// Saved stone masks use four texture pixels per local world unit.
	stone_metric_scale = 4.0 * vec2(length(MODEL_MATRIX[0].xy), length(MODEL_MATRIX[1].xy));
}

uniform vec2 observer_position = vec2(0.0);
uniform vec2 light_origin = vec2(0.0);
uniform float facing_angle = 0.0;
uniform float half_fov = 0.72;
uniform float beam_range = 560.0;
uniform float beam_fade_start = 336.0;
uniform float beam_strength = 0.0;
uniform float ambient_radius = 180.0;
uniform float ambient_softness = 72.0;
uniform vec2 lamp_position = vec2(-100000.0);
uniform float lamp_radius = 245.0;
uniform float lamp_power = 0.0;
uniform vec4 lamp_tint : source_color = vec4(1.0, 0.91, 0.66, 1.0);
uniform vec2 surface_origin = vec2(0.0);
uniform vec2 surface_axis_x = vec2(1.0, 0.0);
uniform vec2 surface_axis_y = vec2(0.0, 1.0);
uniform int box_count = 0;
uniform int circle_count = 0;
uniform vec4 occluder_boxes[96];
uniform vec4 occluder_circles[8];
uniform int polygon_edge_count = 0;
uniform vec4 occluder_polygon_edges[256];

float visibility_from(vec2 source, vec2 target) {
	vec2 delta = target - source;
	vec2 safe_delta = mix(vec2(0.0001), delta, greaterThan(abs(delta), vec2(0.0001)));
	for (int i = 0; i < polygon_edge_count; i++) {
		vec4 edge = occluder_polygon_edges[i];
		vec2 segment = edge.zw - edge.xy;
		float denominator = delta.x * segment.y - delta.y * segment.x;
		if (abs(denominator) < 0.00001) { continue; }
		vec2 offset = edge.xy - source;
		float t = (offset.x * segment.y - offset.y * segment.x) / denominator;
		float u = (offset.x * delta.y - offset.y * delta.x) / denominator;
		if (t > 0.001 && t < 0.999 && u >= 0.0 && u <= 1.0) { return 0.0; }
	}
	for (int i = 0; i < box_count; i++) {
		vec4 box = occluder_boxes[i];
		vec2 a = (box.xy - source) / safe_delta;
		vec2 b = (box.zw - source) / safe_delta;
		vec2 near_hit = min(a, b);
		vec2 far_hit = max(a, b);
		float enter = max(near_hit.x, near_hit.y);
		float exit = min(far_hit.x, far_hit.y);
		if (exit >= max(enter, 0.0) && enter < 0.999 && exit > 0.001) { return 0.0; }
	}
	for (int i = 0; i < circle_count; i++) {
		vec4 circle = occluder_circles[i];
		float t = clamp(dot(circle.xy - source, delta) / max(dot(delta, delta), 0.001), 0.001, 0.999);
		if (distance(source + delta * t, circle.xy) < circle.z) { return 0.0; }
	}
	return 1.0;
}

void fragment() {
	vec2 world_position = surface_origin + UV.x * surface_axis_x + UV.y * surface_axis_y;
	// Fragment COLOR already contains the sampled texture and sprite modulation.
	vec4 surface = COLOR;
	vec2 texture_slope = vec2(0.0);
	if (use_detail_texture) {
		vec2 uv = detail_position;
		float c = cos(detail_uv_angle);
		float s = sin(detail_uv_angle);
		uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
		uv = uv * detail_texels_per_unit / vec2(textureSize(detail_texture, 0)) + vec2(0.5) + detail_uv_offset;
		// Keep the saved polygon alpha while sampling the user's original image.
		surface.rgb = texture(detail_texture, uv).rgb * detail_tint.rgb;
		if (stone_relief) {
			vec2 texel = 1.0 / vec2(textureSize(detail_texture, 0));
			float height = dot(textureLod(detail_texture, uv, 1.0).rgb, vec3(0.3333));
			float hx = dot(textureLod(detail_texture, uv + vec2(texel.x * 2.0, 0.0), 1.0).rgb, vec3(0.3333));
			float hy = dot(textureLod(detail_texture, uv + vec2(0.0, texel.y * 2.0), 1.0).rgb, vec3(0.3333));
			vec2 slope = vec2(height - hx, height - hy);
			texture_slope = vec2(c * slope.x + s * slope.y, -s * slope.x + c * slope.y) * 1.6;
		}
	}
	vec2 offset = world_position - light_origin;
	float relative = atan(offset.y, offset.x) - facing_angle;
	float angle = abs(atan(sin(relative), cos(relative)));
	float cone = 1.0 - smoothstep(max(half_fov - 0.20944, 0.0), half_fov, angle);
	float beam = cone * (1.0 - smoothstep(beam_fade_start, beam_range, length(offset))) * beam_strength;
	float ambient = 1.0 - smoothstep(max(ambient_radius - ambient_softness, 0.0), ambient_radius, distance(world_position, observer_position));
	float lamp = (1.0 - smoothstep(25.0, lamp_radius, distance(world_position, lamp_position))) * lamp_power;
	if (beam > 0.001) { beam *= visibility_from(light_origin, world_position); }
	if (ambient > 0.001) { ambient *= visibility_from(observer_position, world_position); }
	if (lamp > 0.001) { lamp *= visibility_from(lamp_position, world_position); }
	// Lamp color must not reveal pixels outside the player's visibility mask.
	float amount = max(ambient, beam);
	vec3 tone = mix(vec3(0.74, 0.80, 0.76), vec3(1.0, 0.98, 0.90), beam);
	tone = mix(tone, lamp_tint.rgb, lamp * amount);
	if (stone_relief) {
		// All volume stays within the physical silhouette, including the contact rim.
		float edge_distance = 10000.0;
		vec2 outward = vec2(0.0);
		for (int i = 0; i < 8; i++) {
			vec2 a = stone_outline[i] * stone_metric_scale;
			vec2 b = stone_outline[(i + 1) % 8] * stone_metric_scale;
			vec2 edge = b - a;
			vec2 nearest = a + edge * clamp(dot(detail_position - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
			float d = distance(nearest, detail_position);
			if (d < edge_distance) {
				edge_distance = d;
				outward = (nearest - detail_position) / max(d, 0.001);
			}
		}
		float chipped_width = 4.8 + sin(detail_position.x * 0.83 + sin(detail_position.y * 1.2)) * 0.8;
		float bevel = 1.0 - smoothstep(0.45, chipped_width, edge_distance);
		float crown = 1.0 - smoothstep(4.0, 23.0, edge_distance);
		vec3 normal = normalize(vec3(outward * (0.23 * crown + 1.25 * bevel) + texture_slope, 1.0));
		vec2 source = beam >= lamp ? light_origin : lamp_position;
		vec2 direction = source - world_position;
		vec2 local_direction = vec2(dot(direction, normalize(surface_axis_x)), dot(direction, normalize(surface_axis_y)));
		vec3 incoming = normalize(vec3(local_direction / max(length(local_direction), 0.001), 0.85));
		if (editor_preview) { incoming = normalize(vec3(-0.7, -0.8, 0.85)); }
		float diffuse = 0.42 + 0.95 * max(dot(normal, incoming), 0.0);
		float side = mix(1.0, 0.92, bevel);
		float contact = mix(0.42, 1.0, smoothstep(0.0, 0.85, edge_distance));
		surface.rgb *= diffuse * side * contact;
	}
	COLOR = editor_preview ? surface : vec4(surface.rgb * tone * amount, surface.a * amount);
}
