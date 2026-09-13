class_name IslandLake
extends Node3D
## The black water: open dark water off the east side of the wilderness,
## a wooden bridge from the mainland shore, and a separate round cursed
## island holding Vorgath, the Drowned King.

const WATER_X0 := 24.0 # West edge: the mainland shoreline.
const WATER_X1 := 70.0 # East edge: runs off into the fog.
const WATER_Z0 := 40.0 # North edge.
const WATER_Z1 := 74.0 # South edge.
const ISLAND_CENTER := Vector2(37.0, 57.0)
const ISLAND_RADIUS := 7.0
const ISLAND_TOP_Y := 0.35
const BRIDGE_Z := 57.0
const BRIDGE_X0 := 22.0 # West end, on grass.
const BRIDGE_X1 := 30.6 # East end, on the island.
const BRIDGE_W := 3.0
const BOSS_SCENE := preload("res://src/enemy/boss.tscn")

static func is_in_water(x: float, z: float, margin := 0.0) -> bool:
	return x > WATER_X0 - margin and x < WATER_X1 + margin \
		and z > WATER_Z0 - margin and z < WATER_Z1 + margin

static func is_on_bridge_path(x: float, z: float) -> bool:
	return x > BRIDGE_X0 - 1.5 and x < BRIDGE_X1 + 1.5 \
		and absf(z - BRIDGE_Z) < BRIDGE_W * 0.5 + 1.5

## Push a world position out of the water and off the bridge (wild dead).
static func keep_out_of_water(p: Vector3) -> Vector3:
	var v := Vector2(p.x, p.z)
	if is_on_bridge_path(v.x, v.y):
		v.y = BRIDGE_Z - BRIDGE_W * 0.5 - 1.6
	if is_in_water(v.x, v.y, 0.4):
		v.x = WATER_X0 - 0.6
	p.x = v.x
	p.z = v.y
	return p

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.SOUTH)
	_build_water()
	_build_island()
	_build_bridge()
	_build_shore_collision()
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
	# Muddy shoreline where the water meets the mainland grass.
	var shore := MeshInstance3D.new()
	var shore_mesh := BoxMesh.new()
	shore_mesh.size = Vector3(2.6, 0.05, WATER_Z1 - WATER_Z0)
	shore.mesh = shore_mesh
	shore.position = Vector3(WATER_X0 - 0.5, 0.02, (WATER_Z0 + WATER_Z1) * 0.5)
	shore.material_override = _mat(Color(0.13, 0.11, 0.09))
	add_child(shore)
	# Black water: dark, slightly transparent, moonlit sheen.
	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(WATER_X1 - WATER_X0, WATER_Z1 - WATER_Z0)
	water.mesh = water_mesh
	water.position = Vector3(
		(WATER_X0 + WATER_X1) * 0.5, 0.05, (WATER_Z0 + WATER_Z1) * 0.5)
	water.material_override = _mat(Color(0.03, 0.06, 0.11), 0.75, 0.18, 0.94)
	add_child(water)

func _build_island() -> void:
	var rock_mat := _mat(Color(0.23, 0.22, 0.26))
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_texture = load("res://src/world/grass_ground.png")
	top_mat.uv1_scale = Vector3(6, 6, 6)
	top_mat.roughness = 0.95
	var c := Vector3(ISLAND_CENTER.x, 0.0, ISLAND_CENTER.y)
	# Raised rock base.
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = ISLAND_RADIUS
	base_mesh.bottom_radius = ISLAND_RADIUS + 1.2
	base_mesh.height = 0.9
	base_mesh.radial_segments = 28
	base.mesh = base_mesh
	base.position = c + Vector3(0, ISLAND_TOP_Y - 0.45, 0)
	base.material_override = rock_mat
	add_child(base)
	# Walkable top.
	var top := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = ISLAND_RADIUS
	top_mesh.bottom_radius = ISLAND_RADIUS
	top_mesh.height = 0.08
	top_mesh.radial_segments = 28
	top.mesh = top_mesh
	top.position = c + Vector3(0, ISLAND_TOP_Y - 0.04, 0)
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
	cs.position = c + Vector3(0, ISLAND_TOP_Y - 0.5, 0)
	body.add_child(cs)

func _build_bridge() -> void:
	var wood := _mat(Color(0.46, 0.33, 0.21))
	var wood_dark := _mat(Color(0.37, 0.26, 0.16))
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

func _build_shore_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WaterCollision"
	add_child(body)
	# North shore: keeps the player from stepping off the grass onto the
	# strip of water that lies inside the east wall.
	var x := WATER_X0 - 1.0
	while x <= 32.0:
		var ncol := CollisionShape3D.new()
		var nbox := BoxShape3D.new()
		nbox.size = Vector3(3.8, 3.0, 1.4)
		ncol.shape = nbox
		ncol.position = Vector3(x, 1.0, WATER_Z0 - 0.6)
		body.add_child(ncol)
		x += 3.4
	# Mainland shore: a line of blockers with a gap at the bridge.
	var z := WATER_Z0
	while z <= WATER_Z1:
		if absf(z - BRIDGE_Z) > 2.8:
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.4, 3.0, 3.8)
			col.shape = box
			col.position = Vector3(WATER_X0 - 0.6, 1.0, z)
			body.add_child(col)
		z += 3.4
	# Island ring: blockers all around except where the bridge lands (west).
	# Slim segments leave a clean, corner-free gap at the landing; the
	# bridge rails block the sides there so the hero cannot slip off.
	var segs := 28
	var r := ISLAND_RADIUS + 0.6
	for i in segs:
		var ang := TAU * float(i) / segs
		if absf(wrapf(ang - PI, -PI, PI)) < 0.28:
			continue
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * r / segs * 1.1, 3.0, 1.6)
		col.shape = box
		col.position = Vector3(
			ISLAND_CENTER.x + r * cos(ang), 1.0, ISLAND_CENTER.y + r * sin(ang))
		col.rotation.y = -ang
		body.add_child(col)

func _decorate_island() -> void:
	var bone_mat := _mat(Color(0.58, 0.56, 0.50))
	var dead_mat := _mat(Color(0.25, 0.20, 0.17))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var c := Vector3(ISLAND_CENTER.x, ISLAND_TOP_Y, ISLAND_CENTER.y)
	# Dead trees.
	for i in 4:
		var ang := TAU * float(i) / 4.0 + 0.5
		var tp := c + Vector3(4.2 * cos(ang), 0, 4.2 * sin(ang))
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
	for i in 10:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1.5, ISLAND_RADIUS - 0.8)
		var bone := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.2, 0.5), 0.12, rng.randf_range(0.15, 0.3))
		bone.mesh = bm
		bone.position = c + Vector3(dist * cos(ang), 0.06, dist * sin(ang))
		bone.rotation.y = rng.randf() * TAU
		bone.material_override = bone_mat
		add_child(bone)
	# Eerie green light over the island.
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.9, 0.55)
	light.light_energy = 1.1
	light.omni_range = 14.0
	light.position = c + Vector3(0, 3.0, 0)
	add_child(light)

func _spawn_boss() -> void:
	var boss := BOSS_SCENE.instantiate()
	boss.position = Vector3(
		ISLAND_CENTER.x, ISLAND_TOP_Y + 0.1, ISLAND_CENTER.y + 1.5)
	add_child(boss)
