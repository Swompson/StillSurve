shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE;
	vec3 background = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb * 0.4;
	background += textureLod(screen_texture, SCREEN_UV + vec2(step_size.x, 0.0), blur_lod).rgb * 0.15;
	background += textureLod(screen_texture, SCREEN_UV - vec2(step_size.x, 0.0), blur_lod).rgb * 0.15;
	background += textureLod(screen_texture, SCREEN_UV + vec2(0.0, step_size.y), blur_lod).rgb * 0.15;
	background += textureLod(screen_texture, SCREEN_UV - vec2(0.0, step_size.y), blur_lod).rgb * 0.15;
	float shade = mix(0.34, 0.56, smoothstep(0.0, 0.65, SCREEN_UV.x));
	COLOR = vec4(background * shade, 1.0);
}
