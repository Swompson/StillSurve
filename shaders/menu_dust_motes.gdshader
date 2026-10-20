shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float opacity = 0.35;
uniform float field_width = 1280.0;
varying float phase;
varying float world_x;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	world_x = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x;
}

void fragment() {
	float distance = length((UV - 0.5) * 4.0);
	float feather = max(fwidth(distance), 0.035);
	float core = 1.0 - smoothstep(0.48 - feather, 0.48 + feather, distance);
	float body = 1.0 - smoothstep(1.0 - feather, 1.0 + feather, distance);
	float halo = 1.0 - smoothstep(1.55, 2.0, distance);
	float light = exp(-pow((world_x / max(field_width, 1.0) - 0.70) / 0.10, 2.0));
	float breathing = 0.76 + sin(clock * 0.33 + phase) * 0.24;
	float alpha = opacity * (0.035 + light * 0.965) * breathing;
	COLOR = vec4(mix(vec3(0.83, 0.81, 0.73), vec3(0.93, 0.90, 0.81), core), alpha * min(1.0, core + body * 0.3 + halo * 0.09));
}
