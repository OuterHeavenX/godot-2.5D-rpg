extends Node3D
## Gray stone perimeter wall around the village and the southern wilderness,
## built from authentic KayKit medieval wall segments. The south village wall
## has a gate gap so the player can reach the skeletons outside.
## Adds collision so the player stays inside the grounds.

const WALL_SCENE_PATH := "res://src/world/walls/wall_straight.gltf"
const HALF := 30.0          # village is 60x60, walls sit on the edge
const WILD_Z := 70.0        # wilderness extends south to z=+70
const NORTH_Z := -100.0     # northern wilds extend north to z=-100
const GATE_HALF := 2.0      # gate opening is 4m wide
const SEG_LEN := 2.0        # KayKit wall_straight is 2m long
const HEIGHT_SCALE := 2.0   # stretch walls to twice their height
const WALL_H := 1.1 * HEIGHT_SCALE

func _ready() -> void:
	var wall_mesh := _extract_wall_mesh()
	if wall_mesh == null:
		push_error("stone_walls: could not extract mesh from wall_straight.gltf")
		return
	_build_walls(wall_mesh)
	_build_pillars()
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

## One wall run from `a` to `b` (axis-aligned). Appends transforms to the list.
func _run(xforms: Array, a: Vector3, b: Vector3, along_z: bool) -> void:
	var length := a.distance_to(b)
	var count := int(round(length / SEG_LEN))
	var tall := Basis.from_scale(Vector3(1.0, HEIGHT_SCALE, 1.0))
	if along_z:
		tall = Basis(Vector3.UP, PI * 0.5) * tall
	for s in range(count):
		var t := (float(s) + 0.5) / float(count)
		var p := a.lerp(b, t)
		xforms.append(Transform3D(tall, p))

func _build_walls(wall_mesh: Mesh) -> void:
	var xforms: Array = []
	# North village wall.
	# North wall (z=-HALF) with a gate gap leading to the northern wilds.
	_run(xforms, Vector3(-HALF, 0, -HALF), Vector3(-GATE_HALF, 0, -HALF), false)
	_run(xforms, Vector3(GATE_HALF, 0, -HALF), Vector3(HALF, 0, -HALF), false)
	# South village wall, split by the gate gap.
	_run(xforms, Vector3(-HALF, 0, HALF), Vector3(-GATE_HALF, 0, HALF), false)
	_run(xforms, Vector3(GATE_HALF, 0, HALF), Vector3(HALF, 0, HALF), false)
	# East wall runs the full length but leaves a gap where the bridge
	# crosses to the island; west wall runs unbroken.
	_run(xforms, Vector3(HALF, 0, -HALF), Vector3(HALF, 0, 54.5), true)
	_run(xforms, Vector3(HALF, 0, 59.5), Vector3(HALF, 0, WILD_Z), true)
	_run(xforms, Vector3(-HALF, 0, -HALF), Vector3(-HALF, 0, WILD_Z), true)
	# South wilderness wall.
	_run(xforms, Vector3(-HALF, 0, WILD_Z), Vector3(HALF, 0, WILD_Z), false)
	# Northern wilds perimeter: north wall (gate gap at x=-3..3 leads to
	# the frozen arena), plus east/west extensions.
	_run(xforms, Vector3(-HALF, 0, NORTH_Z), Vector3(-3, 0, NORTH_Z), false)
	_run(xforms, Vector3(3, 0, NORTH_Z), Vector3(HALF, 0, NORTH_Z), false)
	_run(xforms, Vector3(-HALF, 0, NORTH_Z), Vector3(-HALF, 0, -HALF), true)
	_run(xforms, Vector3(HALF, 0, NORTH_Z), Vector3(HALF, 0, -HALF), true)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = wall_mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "WallRing"
	add_child(mmi)

func _build_pillars() -> void:
	var spots: Array = [
		Vector3(-HALF, 0, -HALF), Vector3(HALF, 0, -HALF),
		Vector3(-HALF, 0, HALF), Vector3(HALF, 0, HALF),
		Vector3(-HALF, 0, WILD_Z), Vector3(HALF, 0, WILD_Z),
		Vector3(-HALF, 0, NORTH_Z), Vector3(HALF, 0, NORTH_Z),
	]
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.52, 0.53, 0.56)
	stone_mat.roughness = 0.9
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(1.3, WALL_H + 0.7, 1.3)
	pillar_mesh.material = stone_mat
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(1.6, 0.25, 1.6)
	cap_mesh.material = stone_mat
	# Taller gate pillars flanking the opening.
	var gate_mesh := BoxMesh.new()
	gate_mesh.size = Vector3(1.6, WALL_H + 1.6, 1.6)
	gate_mesh.material = stone_mat
	var gate_cap := BoxMesh.new()
	gate_cap.size = Vector3(2.0, 0.3, 2.0)
	gate_cap.material = stone_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pillar_mesh
	mm.instance_count = spots.size()
	var cap_mm := MultiMesh.new()
	cap_mm.transform_format = MultiMesh.TRANSFORM_3D
	cap_mm.mesh = cap_mesh
	cap_mm.instance_count = spots.size()
	for k in range(spots.size()):
		var base: Vector3 = spots[k]
		mm.set_instance_transform(k, Transform3D(Basis(), base + Vector3(0, (WALL_H + 0.7) * 0.5, 0)))
		cap_mm.set_instance_transform(k, Transform3D(Basis(), base + Vector3(0, WALL_H + 0.7 + 0.125, 0)))
	var pillars := MultiMeshInstance3D.new()
	pillars.multimesh = mm
	pillars.name = "CornerPillars"
	add_child(pillars)
	var caps := MultiMeshInstance3D.new()
	caps.multimesh = cap_mm
	caps.name = "PillarCaps"
	add_child(caps)

	# Gate pillars as individual nodes (south gate + north gate).
	for gz in [HALF, -HALF]:
		for gx in [-GATE_HALF, GATE_HALF]:
			var gp := MeshInstance3D.new()
			gp.mesh = gate_mesh
			gp.position = Vector3(gx, (WALL_H + 1.6) * 0.5, gz)
			add_child(gp)
			var gc := MeshInstance3D.new()
			gc.mesh = gate_cap
			gc.position = Vector3(gx, WALL_H + 1.6 + 0.15, gz)
			add_child(gc)

func _box(parent: Node, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	parent.add_child(cs)

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WallCollision"
	# North village wall, two segments leaving the north gate open.
	_box(body, Vector3(-(HALF + GATE_HALF) * 0.5, 3, -HALF),
		Vector3(HALF - GATE_HALF, 6, 1.2))
	_box(body, Vector3((HALF + GATE_HALF) * 0.5, 3, -HALF),
		Vector3(HALF - GATE_HALF, 6, 1.2))
	# North gate pillars are solid.
	_box(body, Vector3(-GATE_HALF, 3, -HALF), Vector3(1.6, 6, 1.6))
	_box(body, Vector3(GATE_HALF, 3, -HALF), Vector3(1.6, 6, 1.6))
	# South village wall, two segments leaving the gate open.
	_box(body, Vector3(-(HALF + GATE_HALF) * 0.5, 3, HALF),
		Vector3(HALF - GATE_HALF, 6, 1.2))
	_box(body, Vector3((HALF + GATE_HALF) * 0.5, 3, HALF),
		Vector3(HALF - GATE_HALF, 6, 1.2))
	# Gate pillars are solid.
	_box(body, Vector3(-GATE_HALF, 3, HALF), Vector3(1.6, 6, 1.6))
	_box(body, Vector3(GATE_HALF, 3, HALF), Vector3(1.6, 6, 1.6))
	# East wall, split by the bridge gap (z 54.5-59.5).
	_box(body, Vector3(HALF, 3, 11.75), Vector3(1.2, 6, 85.5))
	_box(body, Vector3(HALF, 3, 65.25), Vector3(1.2, 6, 11.5))
	# West full-length wall.
	_box(body, Vector3(-HALF, 3, (WILD_Z - HALF) * 0.5),
		Vector3(1.2, 6, WILD_Z + HALF + 2))
	# South wilderness wall.
	_box(body, Vector3(0, 3, WILD_Z), Vector3(HALF * 2 + 2, 6, 1.2))
	# Northern wilds perimeter (gate gap at x=-3..3 for the arena road).
	_box(body, Vector3((-HALF - 3) * 0.5, 3, NORTH_Z), Vector3(HALF - 3, 6, 1.2))
	_box(body, Vector3((HALF + 3) * 0.5, 3, NORTH_Z), Vector3(HALF - 3, 6, 1.2))
	_box(body, Vector3(-HALF, 3, (NORTH_Z - HALF) * 0.5),
		Vector3(1.2, 6, HALF - NORTH_Z + 2))
	_box(body, Vector3(HALF, 3, (NORTH_Z - HALF) * 0.5),
		Vector3(1.2, 6, HALF - NORTH_Z + 2))
	add_child(body)
