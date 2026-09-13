extends Node3D
## Northern wilderness: a harsher, colder wilds stretching from the north
## village gate (z=-30) to the far north wall (z=-270). Denser dead trees,
## jagged rocks, and fewer living pines — the land itself feels wrong here.
## Built from primitives in the KayKit low-poly style, and drawn through
## MultiMesh batches: the north holds four hundred trees, and one draw
## call each is a price a browser cannot pay.

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

# Unit meshes, scaled per instance by the batch transforms.
var _batch: PropBatch
var _m_pine_trunk: BoxMesh
var _m_pine_cone: CylinderMesh
var _m_snow_cap: CylinderMesh
var _m_dead_trunk: BoxMesh
var _m_branch: BoxMesh
var _m_rock: BoxMesh
var _m_bush: SphereMesh

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.NORTH)
	_rng.seed = 98765  # Consistent layout.
	_make_materials()
	_make_meshes()
	_batch = PropBatch.new()
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
	_batch.build(self)

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

## One mesh per kind of part, shared by every copy of it.
func _make_meshes() -> void:
	_m_pine_trunk = BoxMesh.new()
	_m_pine_trunk.size = Vector3(1, 1, 1)
	_m_pine_trunk.material = _trunk_mat
	_m_pine_cone = CylinderMesh.new()
	_m_pine_cone.top_radius = 0.0
	_m_pine_cone.bottom_radius = 1.0
	_m_pine_cone.height = 1.0
	_m_pine_cone.radial_segments = 7
	_m_pine_cone.material = _pine_mat
	_m_snow_cap = CylinderMesh.new()
	_m_snow_cap.top_radius = 0.0
	_m_snow_cap.bottom_radius = 1.0
	_m_snow_cap.height = 1.0
	_m_snow_cap.radial_segments = 6
	_m_snow_cap.material = _snow_mat
	_m_dead_trunk = BoxMesh.new()
	_m_dead_trunk.size = Vector3(1, 1, 1)
	_m_dead_trunk.material = _dead_mat
	_m_branch = BoxMesh.new()
	_m_branch.size = Vector3(1, 1, 1)
	_m_branch.material = _dead_mat
	_m_rock = BoxMesh.new()
	_m_rock.size = Vector3(1, 1, 1)
	_m_rock.material = _rock_mat
	_m_bush = SphereMesh.new()
	_m_bush.radius = 1.0
	_m_bush.height = 2.0
	_m_bush.radial_segments = 7
	_m_bush.rings = 4
	_m_bush.material = _snow_mat

func _place_pine(pos: Vector3, collision_body: StaticBody3D) -> void:
	var s := _rng.randf_range(0.9, 1.5)
	_batch.add("pine_trunk", _m_pine_trunk, Transform3D(
		Basis.from_scale(Vector3(0.35 * s, 1.2 * s, 0.35 * s)),
		pos + Vector3(0, 0.6 * s, 0)))
	for i in 3:
		var r := (1.1 - i * 0.25) * s
		_batch.add("pine_cone", _m_pine_cone, Transform3D(
			Basis.from_scale(Vector3(r, 1.0 * s, r)),
			pos + Vector3(0, (1.5 + i * 0.7) * s, 0)))
	_batch.add("snow_cap", _m_snow_cap, Transform3D(
		Basis.from_scale(Vector3(0.45 * s, 0.35 * s, 0.45 * s)),
		pos + Vector3(0, 3.6 * s, 0)))
	_add_trunk_collision(pos, collision_body)

func _place_dead_tree(pos: Vector3, collision_body: StaticBody3D) -> void:
	var s := _rng.randf_range(0.8, 1.4)
	_batch.add("dead_trunk", _m_dead_trunk, Transform3D(
		Basis.from_scale(Vector3(0.3 * s, 2.2 * s, 0.3 * s)),
		pos + Vector3(0, 1.1 * s, 0)))
	for i in 4:
		var ang := _rng.randf_range(0.0, TAU)
		var b := Basis.from_euler(Vector3(
			_rng.randf_range(-0.6, 0.6), ang, _rng.randf_range(-0.6, 0.6))) \
			* Basis.from_scale(Vector3(0.15 * s, 1.0 * s, 0.15 * s))
		_batch.add("branch", _m_branch, Transform3D(b, pos + Vector3(
			cos(ang) * 0.4 * s, (1.8 + i * 0.25) * s, sin(ang) * 0.4 * s)))
	_add_trunk_collision(pos, collision_body)

func _place_rock(pos: Vector3, collision_body: StaticBody3D) -> void:
	var b := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) \
		* Basis(Vector3.FORWARD, _rng.randf_range(-0.15, 0.15)) \
		* Basis.from_scale(Vector3(
			_rng.randf_range(0.6, 1.6),
			_rng.randf_range(0.5, 1.4),
			_rng.randf_range(0.6, 1.6)))
	_batch.add("rock", _m_rock, Transform3D(b, pos + Vector3(0, 0.3, 0)))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	col.position = pos + Vector3(0, 0.4, 0)
	collision_body.add_child(col)

func _place_bush(pos: Vector3, _collision_body: StaticBody3D) -> void:
	_batch.add("bush", _m_bush, Transform3D(
		Basis.from_scale(Vector3(0.5, 0.28, 0.5)), pos + Vector3(0, 0.3, 0)))

func _add_trunk_collision(pos: Vector3, collision_body: StaticBody3D) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 2.0
	col.shape = shape
	col.position = pos + Vector3(0, 1.0, 0)
	collision_body.add_child(col)
