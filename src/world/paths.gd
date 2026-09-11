extends Node3D
## Cobblestone paths connecting the village buildings, plus a circular
## stone plaza around the well. Uses a tileable cobble texture.
## Layout comes from VillageLayout (shared with grass clearing).

const COBBLE_TEX := preload("res://src/world/cobble.png")
const TILE_METERS := 3.0      # texture repeats every 3m

func _ready() -> void:
	_build_plaza()
	for seg in VillageLayout.path_segments():
		_build_path(seg[0], seg[1])

func _cobble_material(w_tiles: float, l_tiles: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = COBBLE_TEX
	mat.uv1_scale = Vector3(w_tiles, l_tiles, 1.0)
	mat.roughness = 0.95
	return mat

func _build_plaza() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = VillageLayout.PLAZA_RADIUS
	disc.bottom_radius = VillageLayout.PLAZA_RADIUS
	disc.height = 0.05
	disc.radial_segments = 40
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.position = VillageLayout.WELL_POS + Vector3(0, 0.025, 0)
	var tiles := (VillageLayout.PLAZA_RADIUS * 2.0) / TILE_METERS
	mi.material_override = _cobble_material(tiles, tiles)
	add_child(mi)

func _build_path(start: Vector3, end: Vector3) -> void:
	var dir := end - start
	dir.y = 0.0
	var length := dir.length()
	if length < 1.0:
		return
	dir = dir.normalized()
	var width := VillageLayout.PATH_WIDTH
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = (start + end) * 0.5 + Vector3(0, 0.02, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.material_override = _cobble_material(
		width / TILE_METERS, length / TILE_METERS)
	add_child(mi)
