shader_type canvas_item;
render_mode unshaded;
uniform sampler2D walk_sheet : source_color, filter_linear, repeat_disable;
uniform sampler2D run_sheet : source_color, filter_linear, repeat_disable;
uniform float cycle = 0.0;
uniform float movement = 0.0;
uniform float running = 0.0;
varying vec2 frame_uv;

void vertex() { frame_uv = VERTEX / 444.0 + vec2(0.5); }

vec4 premultiply(vec4 c) { return vec4(c.rgb * c.a, c.a); }

void fragment() {
	float frame = mod(cycle, 8.0);
	float first = floor(frame);
	float next = mod(first + 1.0, 8.0);
	float blend = smoothstep(0.0, 1.0, fract(frame));
	vec2 a = vec2((frame_uv.x + first) / 8.0, frame_uv.y);
	vec2 b = vec2((frame_uv.x + next) / 8.0, frame_uv.y);
	vec4 walk = mix(premultiply(texture(walk_sheet, a)), premultiply(texture(walk_sheet, b)), blend);
	vec4 run = mix(premultiply(texture(run_sheet, a)), premultiply(texture(run_sheet, b)), blend);
	vec4 idle = premultiply(texture(walk_sheet, vec2(frame_uv.x / 8.0, frame_uv.y)));
	vec4 result = mix(idle, mix(walk, run, running), movement);
	COLOR = vec4(result.rgb / max(result.a, 0.0001), result.a);
}
