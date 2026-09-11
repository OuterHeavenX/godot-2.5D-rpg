extends Node3D
## Gray stone perimeter wall around the grounds, built from authentic
## KayKit medieval wall segments. Adds collision so the player stays inside.

const WALL_SCENE_PATH := "res://src/world/walls/wall_straight.gltf"
const HALF := 30.0          # ground is 60x60, walls sit on the edge
const SEG_LEN := 2.0        # KayKit wall_straight is 2m long
const HEIGHT_SCALE := 2.0   # stretch walls to twice their height
const WALL_H := 1.1 * HEIGHT_SCALE

func _ready() -> void:
	var wall_mesh := _extract_wall_mesh()
	if wall_mesh == null:
		push_error("stone_walls: could not extract mesh from wall_straight.gltf")
		return
	_build_wall_ring(wall_mesh)
	_build_corner_pillars()
	_build_collision()

func _extract_wall_mesh() -> Mesh:
	var packed := load(WALL_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	var mi := _find_mesh_instance(inst)
	if mi == null:
		inst.queue_free()
		return null
	var mesh := mi.mesh
	# keep the node alive via the mesh reference; free the temp instance
	inst.queue_free()
	return mesh

func _find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n as MeshInstance3D
	for ch in n.get_children():
		var found := _find_mesh_instance(ch)
		if found != null:
			return found
	return null

func _build_wall_ring(wall_mesh: Mesh) -> void:
	var per_side := int(HALF * 2.0 / SEG_LEN)  # 30
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = wall_mesh
	mm.instance_count = per_side * 4
	var i := 0
	var tall := Basis.from_scale(Vector3(1.0, HEIGHT_SCALE, 1.0))
	for s in range(per_side):
		var d := -HALF + SEG_LEN * 0.5 + float(s) * SEG_LEN
		# north (z=-HALF) and south (z=+HALF): walls run along X
		mm.set_instance_transform(i, Transform3D(tall, Vector3(d, 0, -HALF)))
		i += 1
		mm.set_instance_transform(i, Transform3D(tall, Vector3(d, 0, HALF)))
		i += 1
		# east (x=+HALF) and west (x=-HALF): walls run along Z
		var rot := Basis(Vector3.UP, PI * 0.5) * tall
		mm.set_instance_transform(i, Transform3D(rot, Vector3(HALF, 0, d)))
		i += 1
		mm.set_instance_transform(i, Transform3D(rot, Vector3(-HALF, 0, d)))
		i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "WallRing"
	add_child(mmi)

func _build_corner_pillars() -> void:
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(1.3, WALL_H + 0.7, 1.3)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.52, 0.53, 0.56)
	stone_mat.roughness = 0.9
	pillar_mesh.material = stone_mat
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(1.6, 0.25, 1.6)
	cap_mesh.material = stone_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pillar_mesh
	mm.instance_count = 4
	var cap_mm := MultiMesh.new()
	cap_mm.transform_format = MultiMesh.TRANSFORM_3D
	cap_mm.mesh = cap_mesh
	cap_mm.instance_count = 4
	var k := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(sx * HALF, 0, sz * HALF)
			mm.set_instance_transform(k, Transform3D(Basis(), base + Vector3(0, (WALL_H + 0.7) * 0.5, 0)))
			cap_mm.set_instance_transform(k, Transform3D(Basis(), base + Vector3(0, WALL_H + 0.7 + 0.125, 0)))
			k += 1
	var pillars := MultiMeshInstance3D.new()
	pillars.multimesh = mm
	pillars.name = "CornerPillars"
	add_child(pillars)
	var caps := MultiMeshInstance3D.new()
	caps.multimesh = cap_mm
	caps.name = "PillarCaps"
	add_child(caps)

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WallCollision"
	for side in range(4):
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		if side < 2:
			var z := -HALF if side == 0 else HALF
			box.size = Vector3(HALF * 2.0 + 2.0, 6.0, 1.2)
			cs.position = Vector3(0, 3.0, z)
		else:
			var x := -HALF if side == 2 else HALF
			box.size = Vector3(1.2, 6.0, HALF * 2.0 + 2.0)
			cs.position = Vector3(x, 3.0, 0)
		cs.shape = box
		body.add_child(cs)
	add_child(body)
