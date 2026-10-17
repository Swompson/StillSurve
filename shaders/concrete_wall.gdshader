shader_type canvas_item;
render_mode unshaded;
uniform float exposure : hint_range(0.0, 1.0) = 0.18;
varying vec2 world_point;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0, 1)).xy; }
void fragment() {
	vec2 p = world_point;
	float aggregate = noise(p * 0.65) * 0.06 + noise(p * 0.19) * 0.08;
	float stains = noise(p * 0.009) * 0.12 + noise(p * 0.035) * 0.06;
	float pores = smoothstep(0.86, 0.96, hash(floor(p * 0.7))) * 0.10;
	float crack_line = abs(noise(vec2(p.x * 0.018, 3.0)) * 65.0 + p.y - floor(p.y / 160.0) * 160.0 - 78.0);
	float crack = (1.0 - smoothstep(0.3, 1.2, crack_line)) * 0.07;
	vec3 concrete = vec3(0.12, 0.16, 0.16) + aggregate + stains - pores - crack;
	COLOR = vec4(concrete * exposure, 1.0) * COLOR;
}
