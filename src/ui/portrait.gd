extends Control
## Live 3D portrait: the actual KayKit rogue rig on a slow turntable,
## rendered in a SubViewport and masked to a gold-ringed circle.
## Inherits PROCESS_MODE_ALWAYS from the character menu, so it keeps
## spinning while the game is paused.

const ROGUE_SCENE := preload("res://src/player/rogue_hooded.glb")
const HOOD_SHADER := preload("res://src/player/hood_two_tone.gdshader")
const CAPE_SHADER := preload("res://src/player/cape_two_tone.gdshader")
const ROGUE_TEXTURE := preload("res://src/player/rogue_hooded_rogue_texture.png")
const CIRCLE_SHADER := preload("res://src/ui/portrait_circle.gdshader")
const HIDDEN_PROPS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var _rig: Node3D
var _sway_t := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(168, 168)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(256, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_build_3d(viewport)

	var tex := TextureRect.new()
	tex.texture = viewport.get_texture()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_SHADER
	tex.material = mat
	# Don't let the portrait eat clicks meant for the dim behind it.
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _rig != null:
		# Face the camera, swaying gently — never shows the full back.
		_sway_t += delta
		_rig.rotation.y = PI + sin(_sway_t * 0.7) * 0.45

func _build_3d(viewport: SubViewport) -> void:
	# Soft studio backdrop.
	var world_env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.12, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.74, 0.86)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = e
	viewport.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	viewport.add_child(fill)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.08, 2.35)
	cam.fov = 38.0
	cam.current = true
	viewport.add_child(cam)
	cam.look_at(Vector3(0, 0.74, 0))

	_rig = ROGUE_SCENE.instantiate() as Node3D
	viewport.add_child(_rig)
	# Keep only the dagger, like the in-game player.
	for prop_name in HIDDEN_PROPS:
		var prop := _rig.find_child(prop_name) as MeshInstance3D
		if prop != null:
			prop.visible = false
	_apply_two_tone()
	var anim := _rig.find_child("AnimationPlayer") as AnimationPlayer
	if anim != null:
		anim.play("Idle")

## Same black-outside / red-inside hood and cape as the in-game player.
func _apply_two_tone() -> void:
	var head := _rig.find_child("Rogue_Head_Hooded") as MeshInstance3D
	if head != null:
		var hood_mat := ShaderMaterial.new()
		hood_mat.shader = HOOD_SHADER
		hood_mat.set_shader_parameter("albedo_tex", ROGUE_TEXTURE)
		head.set_surface_override_material(0, hood_mat)
	var cape := _rig.find_child("Rogue_Cape") as MeshInstance3D
	if cape != null:
		var cape_mat := ShaderMaterial.new()
		cape_mat.shader = CAPE_SHADER
		cape.set_surface_override_material(0, cape_mat)
