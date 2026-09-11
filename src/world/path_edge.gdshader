shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// Cobblestone path: darker curb border along the sides and an
// irregular noisy alpha fade so the edge melts into the grass.

uniform sampler2D cobble : source_color;
uniform vec2 tiles = vec2(1.0, 1.0);
uniform float curb_width : hint_range(0.0, 0.3) = 0.10;
uniform float fade_width : hint_range(0.0, 0.2) = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = texture(cobble, uv * tiles).rgb;

	// Curb: darker stone band along both long edges.
	float edge = min(uv.x, 1.0 - uv.x);
	float curb = 1.0 - smoothstep(curb_width * 0.55, curb_width, edge);
	col *= mix(1.0, 0.66, curb);

	// Ragged alpha fade at the long edges (noise stretched along length).
	float n = vnoise(vec2(uv.x * 9.0, uv.y * 70.0));
	float fade = smoothstep(0.0, fade_width * (0.35 + 0.9 * n), edge);

	// Gentle fade at the short ends too (both are tucked out of sight).
	float end_edge = min(uv.y, 1.0 - uv.y);
	float n2 = vnoise(vec2(uv.x * 70.0, uv.y * 9.0));
	float fade2 = smoothstep(0.0, fade_width * (0.35 + 0.9 * n2), end_edge);

	ALBEDO = col;
	ROUGHNESS = 0.95;
	ALPHA = min(fade, fade2);
}
