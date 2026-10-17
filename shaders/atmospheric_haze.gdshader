shader_type canvas_item;
render_mode unshaded;
uniform float drift_time = 0.0;
uniform vec2 camera_position = vec2(0);
uniform vec2 view_size = vec2(1280, 720);
uniform float density = 0.38;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	vec2 p = (camera_position + (UV - 0.5) * view_size) * 0.006;
	vec2 drift = vec2(drift_time * 0.035, drift_time * -0.013);
	vec2 q = p + drift;
	q += vec2(sin(q.y * 0.8), cos(q.x * 0.65)) * 0.8;
	float cloud = 0.5 + sin(q.x * 0.9 + q.y * 0.53) * 0.22;
	cloud += sin(q.x * 1.8 - q.y * 1.1) * 0.15;
	cloud += cos(q.y * 3.4 + sin(q.x * 1.4)) * 0.08;
	float tendrils = pow(0.5 + 0.5 * sin(q.y * 6.0 + sin(q.x * 1.7) * 2.0), 3.0);
	cloud = smoothstep(0.20, 0.85, cloud) * 0.7 + tendrils * 0.3;
	vec3 scene = texture(scene_texture, SCREEN_UV).rgb;
	float visible_surface = smoothstep(0.002, 0.035, dot(scene, vec3(0.299, 0.587, 0.114)));
	float opacity = (0.25 + cloud * 0.75) * density * mix(0.14, 1.0, visible_surface);
	COLOR = vec4(vec3(0.28, 0.38, 0.39), opacity);
}
