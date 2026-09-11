shader_type spatial;
render_mode cull_disabled;

// Two-tone cape: outside black, inside red.
// The KayKit cape mesh has inverted winding, so the outer surface renders
// as backfaces (!FRONT_FACING) and the inner surface as front faces.

uniform vec3 outside_color : source_color = vec3(0.015, 0.015, 0.015);
uniform vec3 inside_color : source_color = vec3(0.62, 0.03, 0.03);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	ALBEDO = FRONT_FACING ? inside_color : outside_color;
	ROUGHNESS = roughness;
}
