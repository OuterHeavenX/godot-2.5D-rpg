shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

// Stylized grass tuft: gradient from base to tip, gentle wind sway.
// Per-instance phase comes from the MultiMesh custom data (red channel).

uniform vec4 color_base : source_color = vec4(0.15, 0.36, 0.15, 1.0);
uniform vec4 color_tip : source_color = vec4(0.45, 0.70, 0.30, 1.0);
uniform float sway_strength = 0.07;
uniform float sway_speed = 2.4;

void vertex() {
	float h = clamp(UV.y, 0.0, 1.0);
	float phase = INSTANCE_CUSTOM.x * 6.28318;
	float sway = sin(TIME * sway_speed + phase) * sway_strength * h * h;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	ALBEDO = mix(color_base.rgb, color_tip.rgb, h);
	ROUGHNESS = 0.95;
}
