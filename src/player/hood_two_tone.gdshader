shader_type spatial;
render_mode cull_disabled;

// Two-tone hood: outside black, inside red.
// The KayKit rogue mesh has flipped winding/normals, so the outer surface
// renders as front faces (FRONT_FACING) and the inner surface as backfaces.
// Non-hood parts of the head (face) keep the original texture.

uniform sampler2D albedo_tex : filter_linear, repeat_disable;
uniform vec3 outside_color : source_color = vec3(0.015, 0.015, 0.015);
uniform vec3 inside_color : source_color = vec3(0.62, 0.03, 0.03);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

// UV bounds of the hood region in the texture atlas (1024px).
const vec2 HOOD_MIN = vec2(0.1416, 0.2930);
const vec2 HOOD_MAX = vec2(0.2246, 0.4346);

void fragment() {
	vec2 uv = UV;
	bool is_hood = (uv.x > HOOD_MIN.x && uv.x < HOOD_MAX.x
		&& uv.y > HOOD_MIN.y && uv.y < HOOD_MAX.y);
	if (is_hood) {
		ALBEDO = FRONT_FACING ? outside_color : inside_color;
	} else {
		ALBEDO = texture(albedo_tex, uv).rgb;
	}
	ROUGHNESS = roughness;
}
