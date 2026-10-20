shader_type canvas_item;
render_mode unshaded;

uniform vec2 light_origin = vec2(0.0);
uniform float light_angle = 0.0;
uniform float light_range = 560.0;
uniform float fade_start = 336.0;
uniform float half_fov = 0.7257;
uniform float angular_feather = 0.20944;
uniform float light_power : hint_range(0.0, 1.0) = 0.0;
uniform float reflection_strength : hint_range(0.0, 2.0) = 1.2;
uniform int occluder_count = 0;
uniform vec4 occluder_segments[256];
varying vec2 world_point;
varying vec2 surface_x;
varying vec2 surface_y;

float cross_2d(vec2 a, vec2 b) { return a.x * b.y - a.y * b.x; }

float beam_visibility(vec2 target) {
	vec2 ray = target - light_origin;
	for (int index = 0; index < occluder_count; index++) {
		vec4 segment = occluder_segments[index];
		vec2 edge = segment.zw - segment.xy;
		float divisor = cross_2d(ray, edge);
		if (abs(divisor) < 0.0001) { continue; }
		vec2 offset = segment.xy - light_origin;
		float along_ray = cross_2d(offset, edge) / divisor;
		float along_edge = cross_2d(offset, ray) / divisor;
		if (along_ray > 0.001 && along_ray < 0.999 && along_edge >= 0.0 && along_edge <= 1.0) { return 0.0; }
	}
	return 1.0;
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	surface_x = normalize(MODEL_MATRIX[0].xy);
	surface_y = normalize(MODEL_MATRIX[1].xy);
}

void fragment() {
	// Keep the authored translucent decal when the flashlight is off.
	vec4 base = COLOR;
	vec4 source = texture(TEXTURE, UV);
	// Derivatives stay outside varying branches; expensive samples only run in the beam.
	vec2 uv_dx = dFdx(UV);
	vec2 uv_dy = dFdy(UV);
	vec2 tap = max(TEXTURE_PIXEL_SIZE * 2.0, (abs(uv_dx) + abs(uv_dy)) * 0.7);
	if (light_power <= 0.0 || reflection_strength <= 0.0 || source.a <= 0.0) {
		COLOR = base;
	} else {
		vec2 offset = world_point - light_origin;
		float beam = 0.0;
		if (dot(offset, offset) < light_range * light_range) {
			float relative = atan(offset.y, offset.x) - light_angle;
			float angle = abs(atan(sin(relative), cos(relative)));
			float cone = 1.0 - smoothstep(max(0.0, half_fov - angular_feather), half_fov, angle);
			float reach = 1.0 - smoothstep(fade_start, light_range, length(offset));
			beam = cone * reach * light_power;
		}
		if (beam > 0.001) { beam *= beam_visibility(world_point); }
		if (beam <= 0.0) {
			COLOR = base;
		} else {
			// Sample at screen-pixel scale so thin edges survive decal minification.
			float surrounding = min(min(textureGrad(TEXTURE, UV + vec2(tap.x, 0.0), uv_dx, uv_dy).a, textureGrad(TEXTURE, UV - vec2(tap.x, 0.0), uv_dx, uv_dy).a),
			min(textureGrad(TEXTURE, UV + vec2(0.0, tap.y), uv_dx, uv_dy).a, textureGrad(TEXTURE, UV - vec2(0.0, tap.y), uv_dx, uv_dy).a));
			float edge = clamp((source.a - surrounding) * 1.6, 0.0, 1.0);
			vec2 incoming = -offset / max(length(offset), 0.001);
			vec2 local_light = vec2(dot(incoming, surface_x), dot(incoming, surface_y));
			vec2 facet = normalize(vec2(sin(UV.x * 31.0 + UV.y * 13.0), cos(UV.y * 29.0 - UV.x * 7.0)) + vec2(0.001));
			float alignment = pow(abs(dot(facet, local_light)), 14.0);
			vec2 beam_side = vec2(-sin(light_angle), cos(light_angle));
			float band = dot(offset, beam_side) / (18.0 + length(offset) * 0.06);
			float core = exp(-band * band);
			float reflection = beam * reflection_strength * (edge * (0.18 + alignment * 0.82) + alignment * core * 0.12);
			vec3 highlight = vec3(1.0, 0.97, 0.85);
			vec3 color = base.rgb * (1.0 + beam * reflection_strength * 0.12) + highlight * reflection * 0.95;
			float alpha = min(0.95, base.a * (1.0 + reflection_strength * beam * 0.5 + reflection * 2.0));
			// Reflections remain inside the original shard alpha, without a glowing halo.
			COLOR = vec4(color, min(source.a, alpha));
		}
	}
}
