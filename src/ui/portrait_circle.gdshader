shader_type canvas_item;
// Circular portrait mask with a gold ring.

uniform vec4 ring_color : source_color = vec4(0.95, 0.78, 0.38, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0; // 0 at center, 1 at edge
	if (r > 1.0) {
		discard;
	}
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;
	float a = tex.a;
	if (r > 0.90) {
		col = ring_color.rgb;
		a = ring_color.a;
	} else if (r > 0.84) {
		// Soft inner shadow for depth.
		float t = (r - 0.84) / 0.06;
		col = mix(col, col * 0.55, t * 0.6);
	}
	COLOR = vec4(col, a);
}
