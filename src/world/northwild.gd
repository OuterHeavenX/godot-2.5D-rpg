extends Node3D
## Northern wilderness: a harsher, colder wilds stretching from the north
## village gate (z=-30) to the far north wall (z=-270). Denser dead trees,
## jagged rocks, and fewer living pines — the land itself feels wrong here.
## Built from primitives in the KayKit low-poly style.

const WILD_MIN := Vector2(-28, -268)
const WILD_MAX := Vector2(28, -32)
# Keep the road to Grimholt clear: a 4m-wide path from the north gate
# (0, -30) to Grimholt's south gate (0, -243).
const ROAD_X := 0.0
const ROAD_HALF := 2.5

var _rng := RandomNumberGenerator.new()

var _trunk_mat: StandardMaterial3D
var _pine_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D
var _dead_mat: StandardMaterial3D
var _snow_mat: StandardMaterial3D

func _ready() -> void:
	_rng.seed = 98765  # Consistent layout.
	_make_materials()
	var collision_body := StaticBody3D.new()
	collision_body.name = "NorthWildCollision"
	add_child(collision_body)
	# Sparse living pines (the cold kills most).
	for i in 70:
		_place_pine(_random_pos(), collision_body)
	# Many dead trees — the signature of the north.
	for i in 120:
		_place_dead_tree(_random_pos(), collision_body)
	# Jagged rocks everywhere.
	for i in 140:
		_place_rock(_random_pos(), collision_body)
	# Snow-dusted bushes.
	for i in 85:
		_place_bush(_random_pos(), collision_body)

func _random_pos() -> Vector3:
	# Keep clear of the road to Grimholt.
	for attempt in 15:
		var p := Vector3(
			_rng.randf_range(WILD_MIN.x, WILD_MAX.x), 0,
			_rng.randf_range(WILD_MIN.y, WILD_MAX.y))
		if absf(p.x - ROAD_X) <= ROAD_HALF + 1.5:
			continue
		# The town square and its houses stay clear of wild clutter.
		if Grimholt.is_in_town(p.x, p.z, 1.5):
			continue
		return p
	return Vector3(20, 0, -60)

func _make_materials() -> void:
	_trunk_mat = StandardMaterial3D.new()
	_trunk_mat.albedo_color = Color(0.28, 0.20, 0.15)
	_trunk_mat.roughness = 0.9
	_pine_mat = StandardMaterial3D.new()
	_pine_mat.albedo_color = Color(0.16, 0.28, 0.20)  # Darker, colder green.
	_pine_mat.roughness = 0.85
	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.38, 0.39, 0.42)  # Gray-blue stone.
	_rock_mat.roughness = 0.95
	_dead_mat = StandardMaterial3D.new()
	_dead_mat.albedo_color = Color(0.32, 0.28, 0.25)  # Pale dead wood.
	_dead_mat.roughness = 0.9
	_snow_mat = StandardMaterial3D.new()
	_snow_mat.albedo_color = Color(0.75, 0.78, 0.82)
	_snow_mat.roughness = 0.7

func _place_pine(pos: Vector3, collision_body: StaticBody3D) -> void:
	var tree := Node3D.new()
	tree.position = pos
	var s := _rng.randf_range(0.9, 1.5)
	tree.scale = Vector3(s, s, s)
	add_child(tree)
	var trunk := _box(Vector3(0.35, 1.2, 0.35), _trunk_mat)
	trunk.position = Vector3(0, 0.6, 0)
	tree.add_child(trunk)
	for i in 3:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.1 - i * 0.25
		cm.height = 1.0
		cone.mesh = cm
		cone.material_override = _pine_mat
		cone.position = Vector3(0, 1.5 + i * 0.7, 0)
		tree.add_child(cone)
	# Snow cap on top.
	var snow := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.0
	sm.bottom_radius = 0.45
	sm.height = 0.35
	snow.mesh = sm
	snow.material_override = _snow_mat
	snow.position = Vector3(0, 3.6, 0)
	tree.add_child(snow)
	_add_trunk_collision(pos, collision_body)

func _place_dead_tree(pos: Vector3, collision_body: StaticBody3D) -> void:
	var tree := Node3D.new()
	tree.position = pos
	var s := _rng.randf_range(0.8, 1.4)
	tree.scale = Vector3(s, s, s)
	add_child(tree)
	var trunk := _box(Vector3(0.3, 2.2, 0.3), _dead_mat)
	trunk.position = Vector3(0, 1.1, 0)
	tree.add_child(trunk)
	# Twisted branches.
	for i in 4:
		var branch := _box(Vector3(0.15, 1.0, 0.15), _dead_mat)
		var ang := _rng.randf_range(0.0, TAU)
		branch.position = Vector3(cos(ang) * 0.4, 1.8 + i * 0.25, sin(ang) * 0.4)
		branch.rotation = Vector3(
			_rng.randf_range(-0.6, 0.6), ang, _rng.randf_range(-0.6, 0.6))
		tree.add_child(branch)
	_add_trunk_collision(pos, collision_body)

func _place_rock(pos: Vector3, collision_body: StaticBody3D) -> void:
	var rock := MeshInstance3D.new()
	var rm := BoxMesh.new()
	# Jagged: random non-uniform scale.
	rm.size = Vector3(1, 1, 1)
	rock.mesh = rm
	rock.material_override = _rock_mat
	rock.position = pos + Vector3(0, 0.3, 0)
	rock.scale = Vector3(
		_rng.randf_range(0.6, 1.6),
		_rng.randf_range(0.5, 1.4),
		_rng.randf_range(0.6, 1.6))
	rock.rotation.y = _rng.randf_range(0.0, TAU)
	rock.rotation.z = _rng.randf_range(-0.15, 0.15)
	add_child(rock)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	col.position = pos + Vector3(0, 0.4, 0)
	collision_body.add_child(col)

func _place_bush(pos: Vector3, _collision_body: StaticBody3D) -> void:
	var bush := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 0.8
	bush.mesh = bm
	bush.material_override = _snow_mat  # Snow-covered.
	bush.position = pos + Vector3(0, 0.3, 0)
	bush.scale.y = 0.7
	add_child(bush)

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi

func _add_trunk_collision(pos: Vector3, collision_body: StaticBody3D) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 2.0
	col.shape = shape
	col.position = pos + Vector3(0, 1.0, 0)
	collision_body.add_child(col)
