extends Node3D
## Weather, by region: snow that thickens the further north you go, mist
## over the black water, and ash falling through the highlands in the west.
## Also breathes on the world fog — denser and colder in the north, heavier
## near the water, a dry brown haze on the ash.

const SNOW_START_Z := -30.0    # the north gate
const SNOW_FULL_Z := -150.0    # full blizzard from here on
const ASH_START_X := -30.0     # the west gate
const ASH_FULL_X := -120.0     # thick ashfall from here on
const MIST_COUNT := 7

var _snow: GPUParticles3D
var _ash: GPUParticles3D
var _env: Environment
var _mist: Array[MeshInstance3D] = []
var _t := 0.0
## The clear-weather baseline. Held as constants rather than read off
## the Environment: that resource is shared between runs of the scene, so
## quitting to the title in a fogged region and starting again used to
## read the fogged value back as "clear" and pile the region's fog on top
## of it, thicker every time until the village was fogged in.
const BASE_FOG_DENSITY := 0.015
const BASE_FOG_COLOR := Color(0.1, 0.13, 0.2)

var _base_fog_density := BASE_FOG_DENSITY
var _base_fog_color := BASE_FOG_COLOR

func _ready() -> void:
	var we := get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		# A copy of our own, so nothing we do to the fog outlives the run.
		_env = we.environment.duplicate()
		we.environment = _env
		_env.fog_density = _base_fog_density
		_env.fog_light_color = _base_fog_color
	_build_snow()
	_build_ash()
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

## Ash drifting down over the highlands: slower and heavier than snow,
## and the colour of a cold fire.
func _build_ash() -> void:
	_ash = GPUParticles3D.new()
	_ash.amount = 320
	_ash.lifetime = 7.0
	_ash.preprocess = 4.0
	_ash.emitting = false
	_ash.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(-0.4, -1, 0.0)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.9
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.04
	pm.scale_max = 0.12
	pm.color = Color(0.62, 0.58, 0.55, 0.85)
	_ash.process_material = pm
	var flake := BoxMesh.new()
	flake.size = Vector3(0.09, 0.02, 0.09)
	_ash.draw_pass_1 = flake
	add_child(_ash)

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
	# Ash: only in the highlands, thickening towards Kael's end of the road.
	var ash := 0.0
	if not indoors and Regions.at(pp.x, pp.z) == Regions.WEST:
		ash = clampf((ASH_START_X - pp.x) / (ASH_START_X - ASH_FULL_X), 0.15, 1.0)
	_ash.amount_ratio = maxf(0.05, ash)
	_ash.emitting = ash > 0.04
	_ash.global_position = Vector3(pp.x, pp.y + 9.0, pp.z)
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
		var density := _base_fog_density + 0.028 * water_near + 0.014 * north \
			+ 0.020 * ash
		_env.fog_density = lerpf(_env.fog_density, density, minf(1.0, delta * 1.5))
		var tint := _base_fog_color.lerp(Color(0.55, 0.65, 0.78), north * 0.6)
		tint = tint.lerp(Color(0.34, 0.26, 0.22), ash * 0.75)
		_env.fog_light_color = _env.fog_light_color.lerp(tint, minf(1.0, delta * 1.5))

func snow_intensity() -> float:
	return _snow.amount_ratio if _snow.emitting else 0.0

func ash_intensity() -> float:
	return _ash.amount_ratio if _ash.emitting else 0.0
