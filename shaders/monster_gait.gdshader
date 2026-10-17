shader_type canvas_item;
render_mode unshaded;
uniform float gait = 0.0;
uniform float movement = 0.0;
uniform float breath = 0.0;
void vertex() {
	float side = UV.x < 0.5 ? -1.0 : 1.0;
	float limb = smoothstep(0.12, 0.33, abs(UV.x - 0.5));
	float hands = smoothstep(0.42, 0.95, UV.y);
	float phase = gait + (side > 0.0 ? 3.14159265 : 0.0);
	VERTEX.y += sin(phase) * limb * movement * mix(5.0, 11.0, hands);
	VERTEX.x += cos(phase) * limb * movement * 3.5;
	float torso = 1.0 - smoothstep(0.10, 0.30, abs(UV.x - 0.5));
	VERTEX.x *= 1.0 + sin(breath) * 0.012 * torso;
	VERTEX.y += sin(gait * 2.0) * movement * 0.8 * torso;
}
