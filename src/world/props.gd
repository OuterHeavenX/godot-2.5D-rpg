extends Node3D
## Village props and clutter: KayKit barrels, crates, sacks, fences,
## wheelbarrow, work-yard resources, plus procedural lamp posts.
## Layout data (buildings/paths) comes from VillageLayout.

const PROP_SCALE := 5.0
const FENCE_SCALE := 3.0
const BARROW_SCALE := 4.0

# model, position, rot_y_deg, scale, solid (collision)
const PROPS := [
	# Market trading goods
	["res://src/world/props/crate_A_big.gltf", Vector3(14.8, 0, -5.0), 15.0, PROP_SCALE, true],
	["res://src/world/props/crate_A_small.gltf", Vector3(14.8, 0, -6.4), -10.0, PROP_SCALE, true],
	["res://src/world/props/barrel.gltf", Vector3(4.2, 0, -13.2), 0.0, PROP_SCALE, true],
	["res://src/world/props/barrel.gltf", Vector3(5.3, 0, -12.9), 0.0, PROP_SCALE, true],
	["res://src/world/props/sack.gltf", Vector3(13.8, 0, -12.8), 30.0, PROP_SCALE, false],
	["res://src/world/props/wheelbarrow.gltf", Vector3(3.0, 0, -6.5), 70.0, BARROW_SCALE, true],
	# Tavern barrels
	["res://src/world/props/barrel.gltf", Vector3(-6.5, 0, -5.5), 0.0, PROP_SCALE, true],
	["res://src/world/props/barrel.gltf", Vector3(-6.0, 0, -4.3), 0.0, PROP_SCALE, true],
	["res://src/world/props/crate_A_small.gltf", Vector3(-14.8, 0, -3.2), 20.0, PROP_SCALE, true],
	# Blacksmith work yard
	["res://src/world/props/resource_lumber.gltf", Vector3(21.5, 0, 6.8), 10.0, PROP_SCALE, true],
	["res://src/world/props/resource_stone.gltf", Vector3(13.2, 0, 7.2), -15.0, PROP_SCALE, true],
	["res://src/world/props/weaponrack.gltf", Vector3(20.8, 0, -0.8), -30.0, PROP_SCALE, true],
	["res://src/world/props/pallet.gltf", Vector3(14.5, 0, -2.5), 5.0, PROP_SCALE, true],
	["res://src/world/props/crate_B_big.gltf", Vector3(14.5, 0.42, -2.5), 5.0, PROP_SCALE, false],
	# Fences (paddock near house B, run south of house A)
	["res://src/world/props/fence_wood_straight.gltf", Vector3(-2, 0, 13), 0.0, FENCE_SCALE, true],
	["res://src/world/props/fence_wood_straight.gltf", Vector3(-2, 0, 16.5), 0.0, FENCE_SCALE, true],
	["res://src/world/props/fence_wood_straight.gltf", Vector3(-2, 0, 20), 0.0, FENCE_SCALE, true],
	["res://src/world/props/fence_wood_straight.gltf", Vector3(-17, 0, 12.5), 90.0, FENCE_SCALE, true],
	["res://src/world/props/fence_wood_straight.gltf", Vector3(-13.5, 0, 12.5), 90.0, FENCE_SCALE, true],
]

const LAMP_PLAZA := [Vector3(5.0, 0, 3.0), Vector3(-5.0, 0, 11.0)]

var _wood_mat: StandardMaterial3D
var _stone_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D
var _metal_mat: StandardMaterial3D

func _ready() -> void:
	_make_lamp_materials()
	var collision_body := StaticBody3D.new()
	collision_body.name = "PropCollision"
	add_child(collision_body)
	for spec in PROPS:
		_place_prop(spec, collision_body)
	# Lamp posts: offset to the side of each path, alternating sides.
	var side := 1.0
	for seg in VillageLayout.path_segments():
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var perp := Vector3(-dir.z, 0, dir.x) * side
		side = -side
		_build_lamp(mid + perp * 2.6, collision_body)
	for pos in LAMP_PLAZA:
		_build_lamp(pos, collision_body)

func _place_prop(spec: Array, collision_body: StaticBody3D) -> void:
	var path: String = spec[0]
	var pos: Vector3 = spec[1]
	# Safety: never drop a prop on stone or inside a building.
	if VillageLayout.is_stone(pos):
		push_warning("props: skipping %s on stone at %s" % [path, pos])
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("props: failed to load " + path)
		return
	var inst := packed.instantiate() as Node3D
	inst.position = pos
	inst.rotation.y = deg_to_rad(float(spec[2]))
	var s: float = spec[3]
	inst.scale = Vector3.ONE * s
	add_child(inst)
	if bool(spec[4]):
		# Collision from the real mesh bounds (some KayKit models have
		# offset origins, e.g. fences snap to hex edges).
		var waabb := _world_aabb(inst)
		# Fences are thin; pad slightly so they're reliably solid.
		var pad := Vector3(0.15, 0.0, 0.15) if "fence" in path else Vector3.ZERO
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = waabb.size + pad
		cs.shape = box
		cs.position = waabb.get_center()
		collision_body.add_child(cs)

## Axis-aligned world bounds of every mesh under the instance.
func _world_aabb(inst: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var inv: Transform3D = inst.global_transform.affine_inverse()
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local_xf: Transform3D = inv * mi.global_transform
		var maabb: AABB = local_xf * mi.mesh.get_aabb()
		if first:
			aabb = maabb
			first = false
		else:
			aabb = aabb.merge(maabb)
	return inst.global_transform * aabb

func _make_lamp_materials() -> void:
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.30, 0.19, 0.10)
	_wood_mat.roughness = 0.9
	_stone_mat = StandardMaterial3D.new()
	_stone_mat.albedo_color = Color(0.52, 0.52, 0.55)
	_stone_mat.roughness = 0.95
	_metal_mat = StandardMaterial3D.new()
	_metal_mat.albedo_color = Color(0.16, 0.16, 0.18)
	_metal_mat.roughness = 0.6
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(1.0, 0.82, 0.45)
	_glass_mat.emission_enabled = true
	_glass_mat.emission = Color(1.0, 0.72, 0.30)
	_glass_mat.emission_energy_multiplier = 1.5

## A chunky low-poly lamp post matching the KayKit look.
func _build_lamp(pos: Vector3, collision_body: StaticBody3D) -> void:
	if VillageLayout.is_stone(pos):
		return
	var lamp := Node3D.new()
	lamp.position = pos
	lamp.rotation.y = randf() * TAU
	add_child(lamp)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.34
	base_mesh.height = 0.25
	base.mesh = base_mesh
	base.position.y = 0.125
	base.material_override = _stone_mat
	lamp.add_child(base)

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.09
	post_mesh.bottom_radius = 0.11
	post_mesh.height = 2.3
	post.mesh = post_mesh
	post.position.y = 0.25 + 1.15
	post.material_override = _wood_mat
	lamp.add_child(post)

	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.7, 0.09, 0.09)
	arm.mesh = arm_mesh
	arm.position = Vector3(0.28, 2.45, 0)
	arm.material_override = _wood_mat
	lamp.add_child(arm)

	var cage := MeshInstance3D.new()
	var cage_mesh := BoxMesh.new()
	cage_mesh.size = Vector3(0.34, 0.42, 0.34)
	cage.mesh = cage_mesh
	cage.position = Vector3(0.55, 2.18, 0)
	cage.material_override = _glass_mat
	lamp.add_child(cage)

	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.02
	cap_mesh.bottom_radius = 0.30
	cap_mesh.height = 0.22
	cap.mesh = cap_mesh
	cap.position = Vector3(0.55, 2.50, 0)
	cap.material_override = _metal_mat
	lamp.add_child(cap)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2.6, 0.5)
	cs.shape = box
	cs.position = pos + Vector3(0, 1.3, 0)
	collision_body.add_child(cs)
