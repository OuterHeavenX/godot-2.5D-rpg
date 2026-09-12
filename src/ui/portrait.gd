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

var portrait_size := 168.0
var _rig: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(portrait_size, portrait_size)
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

	# Frontal key light: dimmer now, keeps the face half in the hood's shadow.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-18, 0, 0)
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = 0.85
	key.shadow_enabled = false
	viewport.add_child(key)

	# Cool rim from behind for definition.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 155, 0)
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.7
	rim.shadow_enabled = false
	viewport.add_child(rim)

	# Faint red under-glow: menace.
	var menace := OmniLight3D.new()
	menace.position = Vector3(0, 0.7, 1.2)
	menace.light_color = Color(0.9, 0.15, 0.1)
	menace.light_energy = 0.35
	menace.omni_range = 2.5
	viewport.add_child(menace)

	# Headshot framing: low Dutch angle, hood-forward and menacing.
	var cam := Camera3D.new()
	cam.position = Vector3(0.6, 0.75, 2.1)
	cam.fov = 40.0
	cam.current = true
	viewport.add_child(cam)
	cam.look_at(Vector3(0, 1.38, 0))

	_rig = ROGUE_SCENE.instantiate() as Node3D
	# rotation.y = 0 faces the camera (rig forward is +Z). Static: no sway.
	_rig.rotation.y = 0.0
	viewport.add_child(_rig)
	# Keep only the dagger, like the in-game player.
	for prop_name in HIDDEN_PROPS:
		var prop := _rig.find_child(prop_name) as MeshInstance3D
		if prop != null:
			prop.visible = false
	_apply_two_tone()
	_add_angry_brows()
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

## Angled brows for a meaner look: inner ends low, outer ends high.
func _add_angry_brows() -> void:
	var brow_mat := StandardMaterial3D.new()
	brow_mat.albedo_color = Color(0.05, 0.03, 0.02)
	brow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var brow := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.14, 0.045, 0.03)
		mesh.material = brow_mat
		brow.mesh = mesh
		# Sit on the face, covering the model's painted brows.
		brow.position = Vector3(side * 0.13, 1.56, 0.50)
		# Inner end down: left brow (side -1) tilts -22°, right +22°.
		brow.rotation.z = deg_to_rad(side * 22.0)
		brow.rotation.y = deg_to_rad(side * -8.0)
		_rig.add_child(brow)
