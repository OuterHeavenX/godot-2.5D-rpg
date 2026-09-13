extends Node3D
## Weather: snow that thickens the further north you go, and mist that
## hangs over the black water. Also breathes on the world fog: denser and
## colder in the north, heavier near the water.

const SNOW_START_Z := -30.0    # the north gate
const SNOW_FULL_Z := -150.0    # full blizzard from here on
const MIST_COUNT := 7

var _snow: GPUParticles3D
var _env: Environment
var _mist: Array[MeshInstance3D] = []
var _t := 0.0
var _base_fog_density := 0.015
var _base_fog_color := Color(0.1, 0.13, 0.2)

func _ready() -> void:
	var we := get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		_env = we.environment
		_base_fog_density = _env.fog_density
		_base_fog_color = _env.fog_light_color
	_build_snow()
	_build_mist()

func _build_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.amount = 500
	_snow.lifetime = 5.0
	_snow.preprocess = 3.0
	_snow.emitting = false
	_snow.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 10.0
	pm.initial_velocity_min = 1.8
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.03
	pm.scale_max = 0.09
	pm.color = Color(0.92, 0.96, 1.0, 0.9)
	_snow.process_material = pm
	var flake := SphereMesh.new()
	flake.radius = 0.06
	flake.height = 0.12
	flake.radial_segments = 4
	flake.rings = 2
	_snow.draw_pass_1 = flake
	add_child(_snow)

## Low translucent sheets drifting over the black water near the shore.
func _build_mist() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.65, 0.8, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in MIST_COUNT:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(rng.randf_range(8, 14), rng.randf_range(6, 10))
		mi.mesh = plane
		mi.material_override = mat
		mi.position = Vector3(
			rng.randf_range(IslandLake.WATER_X0 - 2.0, IslandLake.WATER_X0 + 22.0),
			rng.randf_range(0.4, 1.1),
			rng.randf_range(IslandLake.WATER_Z0 + 2.0, IslandLake.WATER_Z1 - 2.0))
		mi.set_meta("phase", rng.randf() * TAU)
		mi.set_meta("home", mi.position)
		add_child(mi)
		_mist.append(mi)

func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pp := player.global_position
	var indoors := pp.x > 400.0
	# Snow: none south of the gate, a full blizzard deep in the north.
	var north := clampf((SNOW_START_Z - pp.z) / (SNOW_START_Z - SNOW_FULL_Z), 0.0, 1.0)
	if indoors:
		north = 0.0
	_snow.amount_ratio = maxf(0.05, north)
	_snow.emitting = north > 0.04
	_snow.global_position = Vector3(pp.x, pp.y + 9.0, pp.z)
	# Mist drifts slowly.
	for mi in _mist:
		var home: Vector3 = mi.get_meta("home")
		var ph: float = mi.get_meta("phase")
		mi.position = home + Vector3(sin(_t * 0.15 + ph) * 2.0, sin(_t * 0.4 + ph) * 0.1, cos(_t * 0.12 + ph) * 1.5)
	# Fog: heavier by the water, denser and colder in the north.
	if _env != null:
		var dx := maxf(0.0, maxf(IslandLake.WATER_X0 - pp.x, pp.x - IslandLake.WATER_X1))
		var dz := maxf(0.0, maxf(IslandLake.WATER_Z0 - pp.z, pp.z - IslandLake.WATER_Z1))
		var water_near := clampf(1.0 - Vector2(dx, dz).length() / 18.0, 0.0, 1.0)
		if indoors:
			water_near = 0.0
		var density := _base_fog_density + 0.028 * water_near + 0.014 * north
		_env.fog_density = lerpf(_env.fog_density, density, minf(1.0, delta * 1.5))
		var cold := _base_fog_color.lerp(Color(0.55, 0.65, 0.78), north * 0.6)
		_env.fog_light_color = _env.fog_light_color.lerp(cold, minf(1.0, delta * 1.5))

func snow_intensity() -> float:
	return _snow.amount_ratio if _snow.emitting else 0.0
