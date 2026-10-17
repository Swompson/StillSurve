shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://shaders/fixture_lighting.gdshaderinc"
uniform vec2 lamp_origin;
uniform int lamp_row = 0;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 glow = texture(TEXTURE, UV) * COLOR;
	glow.a *= fixture_amount(world_point, lamp_origin, lamp_row, 1.0);
	COLOR = glow;
}
