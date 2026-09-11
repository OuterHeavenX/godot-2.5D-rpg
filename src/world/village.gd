extends Node3D
## A small medieval village built from authentic KayKit building models.
## All models are board-game scale, so they're scaled 5x to fit the rogue.
## Each building gets a collision box so the player can't walk through it.

const BUILDING_SCALE := 5.0

# path, position, rotation_y (deg), collision footprint (x, z) at 1x
# All buildings face south (+Z), toward the camera.
const BUILDINGS := [
	["res://src/world/buildings/tavern.gltf", Vector3(-11, 0, -7), 0.0, Vector2(1.17, 1.33)],
	["res://src/world/buildings/market.gltf", Vector3(9, 0, -9), 0.0, Vector2(1.80, 1.32)],
	["res://src/world/buildings/blacksmith.gltf", Vector3(17, 0, 3), 0.0, Vector2(1.29, 1.25)],
	["res://src/world/buildings/house_a.gltf", Vector3(-15, 0, 7), 0.0, Vector2(0.80, 0.86)],
	["res://src/world/buildings/house_b.gltf", Vector3(-7, 0, 17), 0.0, Vector2(0.87, 1.10)],
	["res://src/world/buildings/house_a.gltf", Vector3(13, 0, 15), 0.0, Vector2(0.80, 0.86)],
	["res://src/world/buildings/well.gltf", Vector3(0, 0, 7), 0.0, Vector2(0.65, 0.75)],
]

func _ready() -> void:
	var collision_body := StaticBody3D.new()
	collision_body.name = "VillageCollision"
	add_child(collision_body)
	for spec in BUILDINGS:
		var path: String = str(spec[0])
		var pos: Vector3 = spec[1]
		var rot_y: float = deg_to_rad(float(spec[2]))
		var footprint: Vector2 = spec[3]
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("village: failed to load " + path)
			continue
		var inst := packed.instantiate() as Node3D
		inst.position = pos
		inst.rotation.y = rot_y
		inst.scale = Vector3.ONE * BUILDING_SCALE
		add_child(inst)
		# Collision box, slightly inset from the visual footprint.
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var sx := footprint.x * BUILDING_SCALE * 0.92
		var sz := footprint.y * BUILDING_SCALE * 0.92
		# Rotate the footprint with the building (only 90-degree-ish aware via abs).
		var c: float = abs(cos(rot_y))
		var s: float = abs(sin(rot_y))
		box.size = Vector3(sx * c + sz * s, 4.0, sx * s + sz * c)
		cs.shape = box
		cs.position = pos + Vector3(0, 2.0, 0)
		collision_body.add_child(cs)
