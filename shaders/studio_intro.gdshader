shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	float halo = exp(-length(p * vec2(1.1, 2.2)) * 6.0);
	float noise = hash(floor(UV * vec2(1280.0, 720.0)) + floor(clock * 24.0)) * 0.012;
	float scan = pow(max(0.0, 1.0 - abs(UV.y - fract(clock * 0.18)) * 90.0), 3.0) * 0.009;
	COLOR = vec4(vec3(0.003, 0.006, 0.007) + vec3(0.035, 0.048, 0.045) * halo + noise + scan, 1.0);
}
