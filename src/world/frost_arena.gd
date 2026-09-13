extends Node3D
## The Frozen Arena: a circle of black ice far north of Grimholt, ringed
## with ice crystals. Morvain, the ice golem, sleeps at its heart.
## Reached through the gate in the north wall (x=-3..3, z=-270).

const ARENA_CENTER := Vector3(0, 0, -288)
const ARENA_RADIUS := 15.0
const RING_RADIUS := 13.0
## Half-width of the corridor slab that leads in from the north gate.
## The rim barrier's opening is cut to match it, so the only gap in the
## kerb is the one place there is floor to walk on.
const CORRIDOR_HALF := 3.5

const MorvainScene := preload("res://src/enemy/morvain.tscn")

var _rng := RandomNumberGenerator.new()

var _ice_mat: StandardMaterial3D
var _dark_ice_mat: StandardMaterial3D
var _crystal_mat: StandardMaterial3D
var _glow_crystal_mat: StandardMaterial3D

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.NORTH)
	_rng.seed = 424242
	_make_materials()
	_build_ground()
	_build_corridor()
	_build_ring_wall()
	_build_rim_barrier()
	_build_crystals()
	_build_snow()
	_build_light()
	_spawn_morvain()

func _make_materials() -> void:
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.albedo_color = Color(0.55, 0.72, 0.85)
	_ice_mat.roughness = 0.25
	_ice_mat.metallic = 0.35
	_dark_ice_mat = StandardMaterial3D.new()
	_dark_ice_mat.albedo_color = Color(0.28, 0.44, 0.66)
	_dark_ice_mat.roughness = 0.35
	_dark_ice_mat.metallic = 0.25
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.65, 0.85, 1.0)
	_crystal_mat.roughness = 0.15
	_crystal_mat.metallic = 0.1
	_glow_crystal_mat = StandardMaterial3D.new()
	_glow_crystal_mat.albedo_color = Color(0.5, 0.85, 1.0)
	_glow_crystal_mat.emission_enabled = true
	_glow_crystal_mat.emission = Color(0.35, 0.7, 1.0)
	_glow_crystal_mat.emission_energy_multiplier = 1.5
	_glow_crystal_mat.roughness = 0.2

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "ArenaGround"
	add_child(body)
	# Ice disc.
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = ARENA_RADIUS
	dm.bottom_radius = ARENA_RADIUS
	dm.height = 0.3
	dm.radial_segments = 48
	disc.mesh = dm
	disc.position = ARENA_CENTER + Vector3(0, -0.09, 0)
	disc.material_override = _ice_mat
	add_child(disc)
	# Dark ice inlay ring for the arena look.
	var inlay := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = 9.0
	im.bottom_radius = 9.0
	im.height = 0.32
	im.radial_segments = 48
	inlay.mesh = im
	inlay.position = ARENA_CENTER + Vector3(0, -0.02, 0)
	inlay.material_override = _dark_ice_mat
	add_child(inlay)
	# Collision: the whole disc is walkable (the shard ring keeps the
	# player from the edge). A cylinder matches the mesh exactly.
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ARENA_RADIUS
	cyl.height = 1.0
	cs.shape = cyl
	cs.position = ARENA_CENTER + Vector3(0, -0.38, 0)
	body.add_child(cs)

func _build_corridor() -> void:
	# Short funnel from the north-wall gate (z=-270) to the arena disc.
	var body := StaticBody3D.new()
	body.name = "ArenaCorridor"
	add_child(body)
	for sx in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 3.0, 5.0)
		wall.mesh = bm
		wall.position = Vector3(sx * 3.5, 1.5, -271.5)
		wall.material_override = _dark_ice_mat
		add_child(wall)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 3.0, 5.0)
		cs.shape = shape
		cs.position = Vector3(sx * 3.5, 1.5, -271.5)
		body.add_child(cs)
	# Ice floor for the corridor: runs from the gate (z=-269) all the way
	# onto the disc (z=-279) so there is no gap to fall through.
	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(CORRIDOR_HALF * 2.0, 0.3, 10.0)
	floor_mi.mesh = fm
	floor_mi.position = Vector3(0, -0.19, -274.0)
	floor_mi.material_override = _ice_mat
	add_child(floor_mi)
	var fcs := CollisionShape3D.new()
	var fshape := BoxShape3D.new()
	fshape.size = Vector3(CORRIDOR_HALF * 2.0, 1.0, 10.0)
	fcs.shape = fshape
	fcs.position = Vector3(0, -0.5, -274.0)
	body.add_child(fcs)

func _build_ring_wall() -> void:
	# Jagged ice-shard ring with a gap at the south (entrance).
	var body := StaticBody3D.new()
	body.name = "ArenaRing"
	add_child(body)
	var segments := 36
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		# South gap: angle pointing +Z (toward the gate).
		var dir := Vector2(cos(ang), sin(ang))
		if dir.y > 0.86: # ~60-degree gap facing south.
			continue
		var pos := ARENA_CENTER + Vector3(dir.x * RING_RADIUS, 0, dir.y * RING_RADIUS)
		var h := _rng.randf_range(1.6, 3.2)
		var shard := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(1.1, h, 0.7)
		shard.mesh = sm
		shard.position = pos + Vector3(0, h * 0.5, 0)
		shard.rotation.y = -ang + _rng.randf_range(-0.2, 0.2)
		shard.rotation.z = _rng.randf_range(-0.12, 0.12)
		shard.material_override = _ice_mat if i % 3 else _dark_ice_mat
		add_child(shard)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.2, h, 0.9)
		cs.shape = shape
		cs.position = pos + Vector3(0, h * 0.5, 0)
		cs.rotation.y = shard.rotation.y
		body.add_child(cs)

## The shard ring is jagged on purpose, which leaves gaps a hero can walk
## through — and past the disc there is nothing to stand on. An invisible
## kerb around the rim keeps anyone from stepping off the ice, with the
## same opening as the shards for the way in.
func _build_rim_barrier() -> void:
	var body := StaticBody3D.new()
	body.name = "ArenaRim"
	add_child(body)
	var segments := 48
	var radius := ARENA_RADIUS - 0.7
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		var dir := Vector2(cos(ang), sin(ang))
		# The opening is exactly as wide as the corridor floor, and no
		# wider. Matching the shard ring's 60-degree gap left it fourteen
		# metres across against seven metres of slab: step off the disc
		# anywhere past x = +-3.5 and there was nothing under you as far
		# as the village ground at z = -270, with no way back up.
		if dir.y > 0.86 and absf(dir.x) * radius < CORRIDOR_HALF + 0.2:
			continue  # the way in
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * radius / float(segments) * 1.3, 4.0, 0.8)
		cs.shape = box
		cs.position = ARENA_CENTER + Vector3(dir.x * radius, 2.0, dir.y * radius)
		# Turn each segment side-on to the circle, so they form a wall
		# rather than a row of spokes with gaps between them.
		cs.rotation.y = -ang + PI * 0.5
		body.add_child(cs)

func _build_crystals() -> void:
	# Crystal clusters outside the ring — some glow with cold light.
	for c in 14:
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(RING_RADIUS + 1.5, ARENA_RADIUS - 0.5)
		var base := ARENA_CENTER + Vector3(cos(ang) * r, 0, sin(ang) * r)
		# Skip the entrance gap.
		if base.z > ARENA_CENTER.z + RING_RADIUS * 0.8 and absf(base.x) < 3.0:
			continue
		var shards := _rng.randi_range(2, 4)
		for s in shards:
			var h := _rng.randf_range(1.0, 2.8)
			var w := _rng.randf_range(0.25, 0.5)
			var cry := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = w
			cm.height = h
			cm.radial_segments = 6
			cry.mesh = cm
			cry.position = base + Vector3(
				_rng.randf_range(-0.8, 0.8), h * 0.5, _rng.randf_range(-0.8, 0.8))
			cry.rotation = Vector3(
				_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.0, TAU),
				_rng.randf_range(-0.25, 0.25))
			var glow := _rng.randf() < 0.35
			cry.material_override = _glow_crystal_mat if glow else _crystal_mat
			add_child(cry)
			if glow and _rng.randf() < 0.4:
				var light := OmniLight3D.new()
				light.light_color = Color(0.4, 0.75, 1.0)
				light.light_energy = 0.8
				light.omni_range = 6.0
				light.shadow_enabled = false
				light.position = cry.position + Vector3(0, 1.0, 0)
				add_child(light)

func _build_snow() -> void:
	var snow := GPUParticles3D.new()
	snow.amount = 220
	snow.lifetime = 4.0
	snow.preprocess = 4.0
	snow.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 1, 18)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.04
	pm.scale_max = 0.1
	pm.color = Color(0.9, 0.95, 1.0, 0.9)
	snow.process_material = pm
	var flake := SphereMesh.new()
	flake.radius = 0.06
	flake.height = 0.12
	snow.draw_pass_1 = flake
	snow.position = ARENA_CENTER + Vector3(0, 8, 0)
	add_child(snow)

func _build_light() -> void:
	# Cold blue wash over the arena.
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.7, 1.0)
	light.light_energy = 1.2
	light.omni_range = 40.0
	light.shadow_enabled = false
	light.position = ARENA_CENTER + Vector3(0, 7, 0)
	add_child(light)

func _spawn_morvain() -> void:
	var morvain := MorvainScene.instantiate()
	morvain.position = ARENA_CENTER + Vector3(0, 0.1, -4)
	# The ice is a disc, so confine him to a disc: a box would stop him at
	# the corners and leave the hero standing safely on the rim.
	morvain.set("roam_center", Vector2(ARENA_CENTER.x, ARENA_CENTER.z))
	morvain.set("roam_radius", ARENA_RADIUS - 1.5)
	add_child(morvain)
