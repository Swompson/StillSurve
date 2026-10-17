uniform bool optimize_fixture_samples = true;
uniform sampler2D fixture_shadows : filter_nearest, repeat_disable;
float fixture_amount(vec2 point, vec2 source, int row, float power) {
	vec2 offset = point - source;
	// Reject zero-contribution pixels before angle and shadow texture fetches.
	if (optimize_fixture_samples && (power <= 0.0 || dot(offset, offset) >= 60025.0)) { return 0.0; }
	float angle = fract(atan(offset.y, offset.x) / 6.28318530718 + 1.0);
	float reach = 245.0;
	for (int i = -1; i <= 1; i++) {
		float sample_angle = fract(angle + float(i) / 1024.0 + 1.0);
		reach = min(reach, texture(fixture_shadows, vec2(sample_angle, (float(row) + 0.5) / 6.0)).r * 245.0);
	}
	float shadow = 1.0 - smoothstep(max(reach - 3.0, 0.0), reach, length(offset));
	return (1.0 - smoothstep(25.0, 245.0, length(offset))) * power * shadow;
}
