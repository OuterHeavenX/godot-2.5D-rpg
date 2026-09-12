extends Node3D
## Wilderness decoration: low-poly pine trees, oak trees, rocks, bushes,
## and dead trees scattered across the southern wilds (z=34 to 66).
## Built from primitives in the KayKit low-poly style.

const WILD_MIN := Vector2(-27, 34)
const WILD_MAX := Vector2(27, 66)
const ISLAND_LAKE := preload("res://src/world/island_lake.gd")
const TREE_COUNT := 35
const ROCK_COUNT := 25
const BUSH_COUNT := 30
const DEAD_TREE_COUNT := 12

var _rng := RandomNumberGenerator.new()

# Shared materials.
var _trunk_mat: StandardMaterial3D
var _pine_mat: StandardMaterial3D
var _oak_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D
var _bush_mat: StandardMaterial3D
var _dead_mat: StandardMaterial3D

func _ready() -> void:
	_rng.seed = 12345  # Consistent layout.
	_make_materials()
	var collision_body := StaticBody3D.new()
	collision_body.name = "WildernessCollision"
	add_child(collision_body)
	for i in TREE_COUNT:
		_place_pine(_random_pos(), collision_body)
	for i in ROCK_COUNT:
		_place_rock(_random_pos(), collision_body)
	for i in BUSH_COUNT:
		_place_bush(_random_pos(), collision_body)
	for i in DEAD_TREE_COUNT:
		_place_dead_tree(_random_pos(), collision_body)
	# A few oaks near the village edge (north part of wilderness).
	for i in 8:
		var pos := Vector3(_rng.randf_range(-25, 25), 0, _rng.randf_range(34, 42))
		_place_oak(pos, collision_body)

func _random_pos() -> Vector3:
	# Keep trees and rocks out of the black water and off the bridge.
	for attempt in 12:
		var p := Vector3(
			_rng.randf_range(WILD_MIN.x, WILD_MAX.x), 0,
			_rng.randf_range(WILD_MIN.y, WILD_MAX.y))
		if ISLAND_LAKE.is_in_lake(p.x, p.z, 1.5):
			continue
		if ISLAND_LAKE.is_on_bridge_path(p.x, p.z):
			continue
		return p
	return Vector3(_rng.randf_range(-20, -10), 0, _rng.randf_range(36, 44))

func _make_materials() -> void:
	_trunk_mat = _mat(Color(0.35, 0.25, 0.18))
	_pine_mat = _mat(Color(0.16, 0.35, 0.20))
	_oak_mat = _mat(Color(0.22, 0.45, 0.25))
	_rock_mat = _mat(Color(0.50, 0.50, 0.52))
	_bush_mat = _mat(Color(0.25, 0.48, 0.28))
	_dead_mat = _mat(Color(0.30, 0.24, 0.20))

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _place_pine(pos: Vector3, collision_body: StaticBody3D) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = _rng.randf() * TAU
	var s := _rng.randf_range(0.8, 1.4)
	tree.scale = Vector3(s, s, s)
	# Trunk.
	var trunk := _cylinder(0.18, 0.25, 1.2, _trunk_mat)
	trunk.position = Vector3(0, 0.6, 0)
	tree.add_child(trunk)
	# Three stacked cones for foliage.
	for i in 3:
		var r := 1.4 - i * 0.35
		var cone := _cone(r, 1.2, _pine_mat)
		cone.position = Vector3(0, 1.5 + i * 0.8, 0)
		tree.add_child(cone)
	add_child(tree)
	_add_trunk_collision(pos, collision_body)

func _place_oak(pos: Vector3, collision_body: StaticBody3D) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = _rng.randf() * TAU
	var s := _rng.randf_range(0.9, 1.3)
	tree.scale = Vector3(s, s, s)
	var trunk := _cylinder(0.22, 0.30, 1.8, _trunk_mat)
	trunk.position = Vector3(0, 0.9, 0)
	tree.add_child(trunk)
	# Round foliage: 3 spheres.
	for offset in [Vector3(0, 2.4, 0), Vector3(0.6, 2.0, 0.3), Vector3(-0.5, 2.1, -0.2)]:
		var blob := _sphere(_rng.randf_range(0.8, 1.1), _oak_mat)
		blob.position = offset
		tree.add_child(blob)
	add_child(tree)
	_add_trunk_collision(pos, collision_body)

func _place_dead_tree(pos: Vector3, collision_body: StaticBody3D) -> void:
	# Spooky bare tree for the skeleton wilds.
	var tree := Node3D.new()
	tree.position = pos
	tree.rotation.y = _rng.randf() * TAU
	var s := _rng.randf_range(0.7, 1.1)
	tree.scale = Vector3(s, s, s)
	var trunk := _cylinder(0.15, 0.22, 2.2, _dead_mat)
	trunk.position = Vector3(0, 1.1, 0)
	tree.add_child(trunk)
	# Bare branches.
	for i in 3:
		var branch := _cylinder(0.05, 0.08, 1.0, _dead_mat)
		branch.position = Vector3(0, 1.8 + i * 0.3, 0)
		branch.rotation.z = _rng.randf_range(0.6, 1.0) * (1 if i % 2 == 0 else -1)
		branch.rotation.y = _rng.randf() * TAU
		tree.add_child(branch)
	add_child(tree)
	_add_trunk_collision(pos, collision_body)

func _place_rock(pos: Vector3, collision_body: StaticBody3D) -> void:
	var rock := _box(
		Vector3(_rng.randf_range(0.5, 1.2), _rng.randf_range(0.4, 0.9), _rng.randf_range(0.5, 1.2)),
		_rock_mat)
	rock.position = pos + Vector3(0, 0.2, 0)
	rock.rotation.y = _rng.randf() * TAU
	rock.rotation.x = _rng.randf_range(-0.1, 0.1)
	add_child(rock)
	# Collision.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	col.position = pos + Vector3(0, 0.4, 0)
	collision_body.add_child(col)

func _place_bush(pos: Vector3, _collision_body: StaticBody3D) -> void:
	# Bushes have no collision (walk through).
	var bush := _sphere(_rng.randf_range(0.4, 0.7), _bush_mat)
	bush.position = pos + Vector3(0, 0.3, 0)
	bush.scale.y = 0.7
	add_child(bush)

func _cylinder(r_top: float, r_bot: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = height
	mesh.radial_segments = 7  # Low-poly.
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi

func _cone(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi

func _sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 6
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi

func _add_trunk_collision(pos: Vector3, collision_body: StaticBody3D) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 2.0
	col.shape = shape
	col.position = pos + Vector3(0, 1.0, 0)
	collision_body.add_child(col)
