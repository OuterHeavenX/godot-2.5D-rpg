extends Node3D
## Wilderness decoration: low-poly pine trees, oak trees, rocks, bushes,
## and dead trees scattered across the southern wilds (z=34 to 66).
## Built from primitives in the KayKit low-poly style and drawn through
## MultiMesh batches, one draw call per kind of part.

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

# Unit meshes, scaled per instance by the batch transforms.
var _batch: PropBatch
var _m_trunk: CylinderMesh
var _m_pine_cone: CylinderMesh
var _m_oak_blob: SphereMesh
var _m_dead_trunk: CylinderMesh
var _m_branch: CylinderMesh
var _m_rock: BoxMesh
var _m_bush: SphereMesh

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.SOUTH)
	_rng.seed = 12345  # Consistent layout.
	_make_materials()
	_make_meshes()
	_batch = PropBatch.new()
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
	_batch.build(self)

func _random_pos() -> Vector3:
	# Keep trees and rocks out of the black water and off the bridge.
	for attempt in 12:
		var p := Vector3(
			_rng.randf_range(WILD_MIN.x, WILD_MAX.x), 0,
			_rng.randf_range(WILD_MIN.y, WILD_MAX.y))
		if ISLAND_LAKE.is_in_water(p.x, p.z, 1.5):
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

## One mesh per kind of part, shared by every copy of it.
func _make_meshes() -> void:
	_m_trunk = _cyl_mesh(0.72, 1.0, 7, _trunk_mat)   # tapered, unit height
	_m_pine_cone = _cyl_mesh(0.0, 1.0, 8, _pine_mat)
	_m_dead_trunk = _cyl_mesh(0.68, 1.0, 7, _dead_mat)
	_m_branch = _cyl_mesh(0.62, 1.0, 5, _dead_mat)
	_m_oak_blob = SphereMesh.new()
	_m_oak_blob.radius = 1.0
	_m_oak_blob.height = 2.0
	_m_oak_blob.radial_segments = 8
	_m_oak_blob.rings = 6
	_m_oak_blob.material = _oak_mat
	_m_bush = SphereMesh.new()
	_m_bush.radius = 1.0
	_m_bush.height = 2.0
	_m_bush.radial_segments = 8
	_m_bush.rings = 5
	_m_bush.material = _bush_mat
	_m_rock = BoxMesh.new()
	_m_rock.size = Vector3(1, 1, 1)
	_m_rock.material = _rock_mat

func _cyl_mesh(top_ratio: float, radius: float, segments: int, mat: Material) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius * top_ratio
	m.bottom_radius = radius
	m.height = 1.0
	m.radial_segments = segments
	m.material = mat
	return m

func _place_pine(pos: Vector3, collision_body: StaticBody3D) -> void:
	var s := _rng.randf_range(0.8, 1.4)
	var yaw := _rng.randf() * TAU
	_batch.add("pine_trunk", _m_trunk, Transform3D(
		Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.25 * s, 1.2 * s, 0.25 * s)),
		pos + Vector3(0, 0.6 * s, 0)))
	for i in 3:
		var r := (1.4 - i * 0.35) * s
		_batch.add("pine_cone", _m_pine_cone, Transform3D(
			Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(r, 1.2 * s, r)),
			pos + Vector3(0, (1.5 + i * 0.8) * s, 0)))
	_add_trunk_collision(pos, collision_body)

func _place_oak(pos: Vector3, collision_body: StaticBody3D) -> void:
	var s := _rng.randf_range(0.9, 1.3)
	var yaw := _rng.randf() * TAU
	_batch.add("oak_trunk", _m_trunk, Transform3D(
		Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.30 * s, 1.8 * s, 0.30 * s)),
		pos + Vector3(0, 0.9 * s, 0)))
	for offset: Vector3 in [Vector3(0, 2.4, 0), Vector3(0.6, 2.0, 0.3), Vector3(-0.5, 2.1, -0.2)]:
		var r := _rng.randf_range(0.8, 1.1) * s
		_batch.add("oak_blob", _m_oak_blob, Transform3D(
			Basis.from_scale(Vector3(r, r, r)), pos + offset * s))
	_add_trunk_collision(pos, collision_body)

func _place_dead_tree(pos: Vector3, collision_body: StaticBody3D) -> void:
	var s := _rng.randf_range(0.7, 1.1)
	var yaw := _rng.randf() * TAU
	_batch.add("dead_trunk", _m_dead_trunk, Transform3D(
		Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.22 * s, 2.2 * s, 0.22 * s)),
		pos + Vector3(0, 1.1 * s, 0)))
	for i in 3:
		var lean := _rng.randf_range(0.6, 1.0) * (1.0 if i % 2 == 0 else -1.0)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.BACK, lean) \
			* Basis.from_scale(Vector3(0.08 * s, 1.0 * s, 0.08 * s))
		_batch.add("branch", _m_branch, Transform3D(b, pos + Vector3(0, (1.8 + i * 0.3) * s, 0)))
	_add_trunk_collision(pos, collision_body)

func _place_rock(pos: Vector3, collision_body: StaticBody3D) -> void:
	var b := Basis(Vector3.UP, _rng.randf() * TAU) \
		* Basis(Vector3.RIGHT, _rng.randf_range(-0.1, 0.1)) \
		* Basis.from_scale(Vector3(
			_rng.randf_range(0.5, 1.2),
			_rng.randf_range(0.4, 0.9),
			_rng.randf_range(0.5, 1.2)))
	_batch.add("rock", _m_rock, Transform3D(b, pos + Vector3(0, 0.2, 0)))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	col.position = pos + Vector3(0, 0.4, 0)
	collision_body.add_child(col)

func _place_bush(pos: Vector3, _collision_body: StaticBody3D) -> void:
	# Bushes have no collision (walk through).
	var r := _rng.randf_range(0.4, 0.7)
	_batch.add("bush", _m_bush, Transform3D(
		Basis.from_scale(Vector3(r, r * 0.7, r)), pos + Vector3(0, 0.3, 0)))

func _add_trunk_collision(pos: Vector3, collision_body: StaticBody3D) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 2.0
	col.shape = shape
	col.position = pos + Vector3(0, 1.0, 0)
	collision_body.add_child(col)
