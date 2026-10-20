shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 pixel = floor(FRAGCOORD.xy);
	float grain = fract(sin(dot(pixel, vec2(127.1, 311.7))) * 43758.5453);
	float worn = fract(sin(dot(floor(pixel / vec2(5.0, 2.0)), vec2(41.7, 93.1))) * 15327.7);
	COLOR.rgb *= mix(0.55, 1.16, grain) * mix(0.76, 1.0, worn);
}
