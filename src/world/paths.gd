extends Node3D
## Cobblestone paths connecting the village buildings, plus a circular
## stone plaza around the well. Uses a tileable cobble texture.

const COBBLE_TEX := preload("res://src/world/cobble.png")
const TILE_METERS := 3.0      # texture repeats every 3m
const PATH_WIDTH := 2.4
const PLAZA_RADIUS := 4.5
const WELL_POS := Vector3(0, 0, 7)

# Building door-side positions (x, z). Paths run from the plaza to these.
const DESTINATIONS := [
	Vector3(-11, 0, -7),   # tavern
	Vector3(9, 0, -9),     # market
	Vector3(17, 0, 3),     # blacksmith
	Vector3(-15, 0, 7),    # house A
	Vector3(-7, 0, 17),    # house B
	Vector3(13, 0, 15),    # house A2
]

func _ready() -> void:
	_build_plaza()
	for dest in DESTINATIONS:
		_build_path(dest)

func _cobble_material(w_tiles: float, l_tiles: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = COBBLE_TEX
	mat.uv1_scale = Vector3(w_tiles, l_tiles, 1.0)
	mat.roughness = 0.95
	return mat

func _build_plaza() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_RADIUS
	disc.bottom_radius = PLAZA_RADIUS
	disc.height = 0.05
	disc.radial_segments = 40
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.position = WELL_POS + Vector3(0, 0.025, 0)
	var tiles := (PLAZA_RADIUS * 2.0) / TILE_METERS
	mi.material_override = _cobble_material(tiles, tiles)
	add_child(mi)

func _build_path(dest: Vector3) -> void:
	var dir := (dest - WELL_POS)
	dir.y = 0.0
	var full_len := dir.length()
	dir = dir.normalized()
	var start := WELL_POS + dir * (PLAZA_RADIUS - 0.3)
	var end := dest - dir * 3.2
	var length := start.distance_to(end)
	if length < 1.0:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(PATH_WIDTH, length)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = (start + end) * 0.5 + Vector3(0, 0.02, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.material_override = _cobble_material(
		PATH_WIDTH / TILE_METERS, length / TILE_METERS)
	add_child(mi)
