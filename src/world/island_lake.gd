class_name IslandLake
extends Node3D
## The black water: a dark lake in the southeast wilds, a wooden bridge
## crossing it, and a small cursed island holding Vorgath, the Drowned King.

const LAKE_CENTER := Vector2(17.0, 57.0)
const LAKE_RADIUS := 8.5
const ISLAND_RADIUS := 4.5
const ISLAND_TOP_Y := 0.35
const BRIDGE_Z := 57.0
const BRIDGE_X0 := 5.5 # West end, on grass.
const BRIDGE_X1 := 12.8 # East end, on the island.
const BRIDGE_W := 3.0
const BOSS_SCENE := preload("res://src/enemy/boss.tscn")

static func is_in_lake(x: float, z: float, margin := 0.0) -> bool:
	return (Vector2(x, z) - LAKE_CENTER).length() < LAKE_RADIUS + margin

static func is_on_bridge_path(x: float, z: float) -> bool:
	return x > BRIDGE_X0 - 1.5 and x < BRIDGE_X1 + 1.5 \
		and absf(z - BRIDGE_Z) < BRIDGE_W * 0.5 + 1.5

func _ready() -> void:
	_build_water()
	_build_island()
	_build_bridge()
	_build_lake_collision()
	_decorate_island()
	_spawn_boss()

func _mat(color: Color, metallic := 0.0, roughness := 0.9, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var c := color
	c.a = alpha
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _build_water() -> void:
	# Muddy shore ring under the water disc.
	var shore := MeshInstance3D.new()
	var shore_mesh := CylinderMesh.new()
	shore_mesh.top_radius = LAKE_RADIUS + 1.4
	shore_mesh.bottom_radius = LAKE_RADIUS + 1.4
	shore_mesh.height = 0.04
	shore_mesh.radial_segments = 48
	shore.mesh = shore_mesh
	shore.position = Vector3(LAKE_CENTER.x, 0.02, LAKE_CENTER.y)
	shore.material_override = _mat(Color(0.13, 0.11, 0.09))
	add_child(shore)
	# Black water: dark, slightly transparent, moonlit sheen.
	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = LAKE_RADIUS
	water_mesh.bottom_radius = LAKE_RADIUS
	water_mesh.height = 0.04
	water_mesh.radial_segments = 48
	water.mesh = water_mesh
	water.position = Vector3(LAKE_CENTER.x, 0.05, LAKE_CENTER.y)
	water.material_override = _mat(Color(0.03, 0.06, 0.11), 0.75, 0.18, 0.94)
	add_child(water)

func _build_island() -> void:
	var rock_mat := _mat(Color(0.16, 0.15, 0.18))
	var top_mat := _mat(Color(0.20, 0.21, 0.20))
	# Raised rock base.
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = ISLAND_RADIUS
	base_mesh.bottom_radius = ISLAND_RADIUS + 1.0
	base_mesh.height = 0.9
	base_mesh.radial_segments = 24
	base.mesh = base_mesh
	base.position = Vector3(LAKE_CENTER.x, ISLAND_TOP_Y - 0.45, LAKE_CENTER.y)
	base.material_override = rock_mat
	add_child(base)
	# Walkable top.
	var top := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = ISLAND_RADIUS
	top_mesh.bottom_radius = ISLAND_RADIUS
	top_mesh.height = 0.08
	top_mesh.radial_segments = 24
	top.mesh = top_mesh
	top.position = Vector3(LAKE_CENTER.x, ISLAND_TOP_Y - 0.04, LAKE_CENTER.y)
	top.material_override = top_mat
	add_child(top)
	# Collision for the island top.
	var body := StaticBody3D.new()
	body.name = "IslandCollision"
	add_child(body)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ISLAND_RADIUS
	cyl.height = 1.0
	cs.shape = cyl
	cs.position = Vector3(LAKE_CENTER.x, ISLAND_TOP_Y - 0.5, LAKE_CENTER.y)
	body.add_child(cs)

func _build_bridge() -> void:
	var wood := _mat(Color(0.32, 0.22, 0.14))
	var wood_dark := _mat(Color(0.24, 0.16, 0.10))
	var length := BRIDGE_X1 - BRIDGE_X0
	var rise := ISLAND_TOP_Y - 0.05
	var slope_ang := atan2(rise, length)
	var mid_x := (BRIDGE_X0 + BRIDGE_X1) * 0.5
	# Planks laid along the slope.
	var planks := 14
	for i in planks:
		var t := (float(i) + 0.5) / planks
		var px := lerpf(BRIDGE_X0, BRIDGE_X1, t)
		var py := lerpf(0.05, ISLAND_TOP_Y, t)
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(length / planks + 0.06, 0.07, BRIDGE_W)
		plank.mesh = pm
		plank.position = Vector3(px, py, BRIDGE_Z)
		plank.rotation.z = slope_ang
		plank.material_override = wood if i % 2 == 0 else wood_dark
		add_child(plank)
	# Side rails: posts + beams.
	for side in [-1.0, 1.0]:
		var rz: float = BRIDGE_Z + side * (BRIDGE_W * 0.5 - 0.12)
		for i in 4:
			var t := float(i) / 3.0
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.14, 0.9, 0.14)
			post.mesh = post_mesh
			post.position = Vector3(lerpf(BRIDGE_X0, BRIDGE_X1, t),
				lerpf(0.05, ISLAND_TOP_Y, t) + 0.45, rz)
			post.material_override = wood_dark
			add_child(post)
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(length + 0.3, 0.12, 0.12)
		beam.mesh = beam_mesh
		beam.position = Vector3(mid_x, (0.05 + ISLAND_TOP_Y) * 0.5 + 0.85, rz)
		beam.rotation.z = slope_ang
		beam.material_override = wood
		add_child(beam)
	# Collision: sloped deck + side rails.
	var body := StaticBody3D.new()
	body.name = "BridgeCollision"
	add_child(body)
	var deck := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(length + 0.6, 0.25, BRIDGE_W)
	deck.shape = deck_box
	deck.position = Vector3(mid_x, (0.05 + ISLAND_TOP_Y) * 0.5 - 0.06, BRIDGE_Z)
	deck.rotation.z = slope_ang
	body.add_child(deck)
	for side in [-1.0, 1.0]:
		var rail := CollisionShape3D.new()
		var rail_box := BoxShape3D.new()
		rail_box.size = Vector3(length + 0.6, 1.0, 0.15)
		rail.shape = rail_box
		rail.position = Vector3(mid_x, (0.05 + ISLAND_TOP_Y) * 0.5 + 0.5,
			BRIDGE_Z + side * (BRIDGE_W * 0.5 - 0.05))
		rail.rotation.z = slope_ang
		body.add_child(rail)

func _build_lake_collision() -> void:
	# Ring of blockers around the water, with a gap at the bridge (west).
	var body := StaticBody3D.new()
	body.name = "LakeCollision"
	add_child(body)
	var segs := 10
	var r := LAKE_RADIUS + 0.4
	for i in segs:
		var ang := TAU * float(i) / segs
		# Skip the segment facing the bridge (angle PI = west).
		if absf(wrapf(ang - PI, -PI, PI)) < TAU / segs * 0.5 + 0.12:
			continue
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * r / segs * 1.15, 3.0, 1.4)
		col.shape = box
		col.position = Vector3(
			LAKE_CENTER.x + r * cos(ang), 1.0, LAKE_CENTER.y + r * sin(ang))
		col.rotation.y = -ang
		body.add_child(col)

func _decorate_island() -> void:
	var bone_mat := _mat(Color(0.82, 0.80, 0.74))
	var dead_mat := _mat(Color(0.25, 0.20, 0.17))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	# Dead trees.
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.5
		var tp := Vector3(LAKE_CENTER.x + 2.6 * cos(ang), ISLAND_TOP_Y,
			LAKE_CENTER.y + 2.6 * sin(ang))
		var tree := Node3D.new()
		tree.position = tp
		tree.rotation.y = rng.randf() * TAU
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.12
		tm.bottom_radius = 0.2
		tm.height = 2.0
		tm.radial_segments = 7
		trunk.mesh = tm
		trunk.position = Vector3(0, 1.0, 0)
		trunk.material_override = dead_mat
		tree.add_child(trunk)
		for b in 3:
			var branch := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.04
			bm.bottom_radius = 0.07
			bm.height = 0.9
			bm.radial_segments = 6
			branch.mesh = bm
			branch.position = Vector3(0, 1.6 + b * 0.25, 0)
			branch.rotation.z = 0.7 * (1 if b % 2 == 0 else -1)
			branch.rotation.y = rng.randf() * TAU
			branch.material_override = dead_mat
			tree.add_child(branch)
		add_child(tree)
	# Scattered bones.
	for i in 8:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1.0, ISLAND_RADIUS - 0.6)
		var bone := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.2, 0.5), 0.12, rng.randf_range(0.15, 0.3))
		bone.mesh = bm
		bone.position = Vector3(LAKE_CENTER.x + dist * cos(ang), ISLAND_TOP_Y + 0.06,
			LAKE_CENTER.y + dist * sin(ang))
		bone.rotation.y = rng.randf() * TAU
		bone.material_override = bone_mat
		add_child(bone)
	# Eerie green light over the island.
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.9, 0.55)
	light.light_energy = 0.7
	light.omni_range = 12.0
	light.position = Vector3(LAKE_CENTER.x, 3.0, LAKE_CENTER.y)
	add_child(light)

func _spawn_boss() -> void:
	var boss := BOSS_SCENE.instantiate()
	boss.position = Vector3(LAKE_CENTER.x, ISLAND_TOP_Y + 0.1, LAKE_CENTER.y + 1.5)
	add_child(boss)
