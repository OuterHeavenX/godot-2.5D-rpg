extends MultiMeshInstance3D
## Scatters low-poly grass tufts across the ground using a MultiMesh,
## with per-instance wind phase for natural sway.

const WIND_SHADER := preload("res://src/world/grass_wind.gdshader")
const ISLAND_LAKE := preload("res://src/world/island_lake.gd")
const TUFT_COUNT := 9000
const GROUND_HALF_X := 30.0
const GROUND_Z_MIN := -270.0
const GROUND_Z_MAX := 70.0
# Keep tufts out of these spots (x, z, radius): houses, trees, player spawn.
const CLEARINGS := [
	[-5.0, -5.0, 2.8], [5.0, -4.0, 2.8],
	[-3.0, 3.0, 1.6], [4.0, 4.0, 1.6],
	[0.0, 0.0, 1.6],
]

func _ready() -> void:
	var tuft := _build_tuft_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = tuft
	mm.instance_count = TUFT_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var placed := 0
	var guard := 0
	while placed < TUFT_COUNT and guard < TUFT_COUNT * 20:
		guard += 1
		var x := rng.randf_range(-GROUND_HALF_X, GROUND_HALF_X)
		var z := rng.randf_range(GROUND_Z_MIN, GROUND_Z_MAX)
		if _in_clearing(x, z):
			continue
		var rot := rng.randf_range(0.0, TAU)
		var scl := rng.randf_range(0.75, 1.35)
		var t := Transform3D(
			Basis(Vector3.UP, rot).scaled(Vector3(scl, scl * rng.randf_range(0.85, 1.2), scl)),
			Vector3(x, 0.0, z))
		mm.set_instance_transform(placed, t)
		mm.set_instance_custom_data(placed, Color(rng.randf(), 0.0, 0.0, 1.0))
		placed += 1
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = WIND_SHADER
	material_override = mat

func _in_clearing(x: float, z: float) -> bool:
	# No grass in the black water or on the bridge.
	if ISLAND_LAKE.is_in_water(x, z, 1.5):
		return true
	if ISLAND_LAKE.is_on_bridge_path(x, z):
		return true
	for c in CLEARINGS:
		var dx: float = x - float(c[0])
		var dz: float = z - float(c[1])
		var r: float = float(c[2])
		if dx * dx + dz * dz < r * r:
			return true
	# Keep grass off the cobblestone plaza and paths.
	if VillageLayout.is_stone(Vector3(x, 0, z)):
		return true
	if Grimholt.is_under_building(x, z):
		return true
	# Keep grass out from under the buildings.
	for b in VillageLayout.BUILDINGS:
		var bp: Vector3 = b[1]
		var fp: Vector2 = b[2]
		var hx := fp.x * VillageLayout.BUILDING_SCALE * 0.5
		var hz := fp.y * VillageLayout.BUILDING_SCALE * 0.5
		if absf(x - bp.x) < hx and absf(z - bp.z) < hz:
			return true
	return false

## A tuft of tapered blades fanning out from the base. UV.y is 0 at the
## base and 1 at the tip so the shader can gradient-color and sway it.
static func _build_tuft_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var blades := 8
	for b in range(blades):
		var ang := TAU * float(b) / float(blades) + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var height := rng.randf_range(0.30, 0.52)
		var lean := rng.randf_range(0.05, 0.22)
		var half_w := rng.randf_range(0.030, 0.045)
		var side := Vector3(-dir.z, 0.0, dir.x)
		var base := dir * rng.randf_range(0.0, 0.05)
		var tip := base + dir * lean + Vector3.UP * height
		var v0 := base - side * half_w
		var v1 := base + side * half_w
		var v2 := tip
		var start := verts.size()
		verts.append_array([v0, v1, v2])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
		uvs.append_array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0)])
		indices.append_array([start, start + 1, start + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
