extends CanvasLayer
## Grimdark vignette: darkens the screen edges for a cinematic, moody frame.
## Pure 2D overlay — no 3D perf cost.

func _ready() -> void:
	layer = 5  # Above the world, below UI.
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.02, 1.0);\nuniform float strength = 0.6;\nuniform float inner_radius = 0.55;\nvoid fragment() {\n\tvec2 centered = (UV - vec2(0.5)) * vec2(1.4, 1.0);\n\tfloat d = length(centered) * 2.0;\n\tfloat v = smoothstep(inner_radius, 1.5, d) * strength;\n\tCOLOR = vec4(edge_color.rgb, v);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
