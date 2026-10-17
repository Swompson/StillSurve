shader_type canvas_item;
render_mode unshaded;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rough(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(grain(cell), grain(cell + vec2(1, 0)), t.x), mix(grain(cell + vec2(0, 1)), grain(cell + vec2(1)), t.x), t.y);
}

void fragment() {
	vec2 p = UV * vec2(1280.0, 720.0);
	float stone = rough(p * 0.028) * 0.65 + rough(p * 0.11) * 0.25 + grain(floor(p)) * 0.10;
	float stain = rough(p * vec2(0.018, 0.003));
	float scratches = step(0.992, grain(vec2(floor(p.x * 0.7), floor(p.y * 0.018)))) * 0.025;
	float light = exp(-length((UV - vec2(0.29, 0.12)) * vec2(2.0, 1.0)) * 3.2);
	float vignette = 1.0 - smoothstep(0.2, 0.78, length((UV - 0.5) * vec2(1.1, 0.85)));
	vec3 wall = vec3(0.023, 0.024, 0.021) + vec3(0.065, 0.064, 0.052) * stone * light;
	wall *= (0.45 + stain * 0.55) * vignette;
	COLOR = vec4(wall + scratches * light, 0.985);
}
