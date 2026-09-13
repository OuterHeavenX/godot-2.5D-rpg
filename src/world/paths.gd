extends Node3D
## Cobblestone paths connecting the village buildings, plus a circular
## stone plaza around the well. Uses a tileable cobble texture.
## Layout comes from VillageLayout (shared with grass clearing).

## Stone sits proud of the grass: level with it, the two surfaces fight
## for the same depth and the square blinks. Two paths that run into each
## other need the same treatment, so a path that would lie on top of one
## already laid is stepped up a little. Most get the base height.
const PATH_Y := 0.05
const PATH_STEP := 0.025
const PLAZA_TOP := 0.03
const PLAZA_THICK := 0.3

const COBBLE_TEX := preload("res://src/world/cobble.png")
const EDGE_SHADER := preload("res://src/world/path_edge.gdshader")
const TILE_METERS := 3.0      # texture repeats every 3m

func _ready() -> void:
	_build_plaza()
	for seg in VillageLayout.path_segments():
		_build_path(seg[0], seg[1])

func _path_material(w_tiles: float, l_tiles: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = EDGE_SHADER
	mat.set_shader_parameter("cobble", COBBLE_TEX)
	mat.set_shader_parameter("tiles", Vector2(w_tiles, l_tiles))
	return mat

func _build_plaza() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = VillageLayout.PLAZA_RADIUS
	disc.bottom_radius = VillageLayout.PLAZA_RADIUS
	disc.height = PLAZA_THICK  # thick enough to meet the ground, not hover
	disc.radial_segments = 40
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.position = VillageLayout.WELL_POS + Vector3(0, PLAZA_TOP - PLAZA_THICK * 0.5, 0)
	var tiles := (VillageLayout.PLAZA_RADIUS * 2.0) / TILE_METERS
	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = COBBLE_TEX
	pmat.uv1_scale = Vector3(tiles, tiles, 1.0)
	pmat.roughness = 0.95
	mi.material_override = pmat
	add_child(mi)

# Centre lines of the paths laid so far, with the height each was given.
var _laid: Array = []

## The height for a new path: the base one, unless it would lie on a path
## already laid outside the plaza, in which case step up until it is clear.
func _height_for(start: Vector3, end: Vector3, width: float) -> float:
	var y := PATH_Y
	for tries in 4:
		var clear := true
		for other in _laid:
			if absf(float(other["y"]) - y) > 0.001:
				continue
			if _paths_meet(start, end, other["a"], other["b"], width):
				clear = false
				break
		if clear:
			return y
		y += PATH_STEP
	return y

## True when two path centre lines come within a path's width of each
## other somewhere outside the plaza, where the plaza would not hide it.
func _paths_meet(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, width: float) -> bool:
	var well := VillageLayout.WELL_POS
	var keep := VillageLayout.PLAZA_RADIUS + 0.4
	for i in 21:
		var pa: Vector3 = a0.lerp(a1, float(i) / 20.0)
		if Vector2(pa.x - well.x, pa.z - well.z).length() < keep:
			continue
		for j in 21:
			var pb: Vector3 = b0.lerp(b1, float(j) / 20.0)
			if Vector2(pb.x - well.x, pb.z - well.z).length() < keep:
				continue
			if Vector2(pa.x - pb.x, pa.z - pb.z).length() < width:
				return true
	return false

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
	var y := _height_for(start, end, width)
	_laid.append({"a": start, "b": end, "y": y})
	mi.position = (start + end) * 0.5 + Vector3(0, y, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.material_override = _path_material(
		width / TILE_METERS, length / TILE_METERS)
	add_child(mi)
