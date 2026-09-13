extends Node3D
## Grimholt: a hardy northern town at the end of the long road.
## Smaller and grimmer than Emberfell — stone houses huddled against
## the cold, lamps burning against the dark. Built from the same
## KayKit models, scaled 5x like the village.

const BUILDING_SCALE := 5.0
const CENTER := Vector3(0, 0, -250)

# model path, offset from CENTER, collision footprint (x, z) at 1x
const BUILDINGS := [
	["res://src/world/buildings/tavern.gltf", Vector3(-9, 0, 0), Vector2(1.17, 1.33)],
	["res://src/world/buildings/market.gltf", Vector3(9, 0, -2), Vector2(1.80, 1.32)],
	["res://src/world/buildings/house_a.gltf", Vector3(-7, 0, 8), Vector2(0.80, 0.86)],
	["res://src/world/buildings/house_b.gltf", Vector3(7, 0, 7), Vector2(0.87, 1.10)],
	["res://src/world/buildings/house_a.gltf", Vector3(0, 0, -10), Vector2(0.80, 0.86)],
	["res://src/world/buildings/well.gltf", Vector3(0, 0, 0), Vector2(0.65, 0.75)],
]

func _ready() -> void:
	var collision_body := StaticBody3D.new()
	collision_body.name = "GrimholtCollision"
	add_child(collision_body)
	for spec in BUILDINGS:
		var path: String = str(spec[0])
		var offset: Vector3 = spec[1]
		var footprint: Vector2 = spec[2]
		var pos := CENTER + offset
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("grimholt: failed to load " + path)
			continue
		var inst := packed.instantiate() as Node3D
		inst.position = pos
		inst.rotation.y = 0.0  # face south (+Z), toward the road
		inst.scale = Vector3.ONE * BUILDING_SCALE
		add_child(inst)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(
			footprint.x * BUILDING_SCALE * 0.92, 4.0,
			footprint.y * BUILDING_SCALE * 0.92)
		cs.shape = box
		cs.position = pos + Vector3(0, 2.0, 0)
		collision_body.add_child(cs)
	# Warm lamps against the cold dark.
	_add_lamp(CENTER + Vector3(-4, 0, 2))
	_add_lamp(CENTER + Vector3(4, 0, -2))

func _add_lamp(pos: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.65, 0.35)  # Warm.
	lamp.light_energy = 1.2
	lamp.omni_range = 8.0
	lamp.position = pos + Vector3(0, 3.0, 0)
	add_child(lamp)
	# Lamp post (simple).
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.12
	pm.height = 3.0
	post.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.18, 0.16)
	post.material_override = mat
	post.position = pos + Vector3(0, 1.5, 0)
	add_child(post)
