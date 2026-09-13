class_name Grimholt
extends Node3D
## Grimholt: a hardy northern town at the end of the long road.
## Smaller and grimmer than Emberfell — stone houses huddled against
## the cold, lamps burning against the dark. Built from the same
## KayKit models, scaled 5x like the village.

const BUILDING_SCALE := 5.0
const CENTER := Vector3(0, 0, -85)
# The town proper: no wild props, and monsters are kept out of it.
const TOWN_MIN := Vector2(-16.0, -99.0)
const TOWN_MAX := Vector2(16.0, -73.0)

# model path, offset from CENTER, collision footprint (x, z) at 1x
const BUILDINGS := [
	["res://src/world/buildings/tavern.gltf", Vector3(-9, 0, 0), Vector2(1.17, 1.33)],
	["res://src/world/buildings/market.gltf", Vector3(9, 0, -2), Vector2(1.80, 1.32)],
	["res://src/world/buildings/house_a.gltf", Vector3(-7, 0, 8), Vector2(0.80, 0.86)],
	["res://src/world/buildings/house_b.gltf", Vector3(7, 0, 7), Vector2(0.87, 1.10)],
	["res://src/world/buildings/house_a.gltf", Vector3(-11, 0, -9), Vector2(0.80, 0.86)],
	["res://src/world/buildings/well.gltf", Vector3(0, 0, 0), Vector2(0.65, 0.75)],
]

static func is_in_town(x: float, z: float, margin := 0.0) -> bool:
	return x > TOWN_MIN.x - margin and x < TOWN_MAX.x + margin \
		and z > TOWN_MIN.y - margin and z < TOWN_MAX.y + margin

## True under one of the town's buildings (grass and props stay out).
static func is_under_building(x: float, z: float, margin := 0.5) -> bool:
	for b in BUILDINGS:
		var p: Vector3 = CENTER + b[1]
		var fp: Vector2 = b[2]
		var hx: float = fp.x * BUILDING_SCALE * 0.5 + margin
		var hz: float = fp.y * BUILDING_SCALE * 0.5 + margin
		if absf(x - p.x) < hx and absf(z - p.z) < hz:
			return true
	return false

## Push a monster position out of the town to the nearest edge.
static func keep_out_of_town(p: Vector3) -> Vector3:
	if not is_in_town(p.x, p.z, 0.5):
		return p
	var d_w: float = p.x - (TOWN_MIN.x - 0.5)
	var d_e: float = (TOWN_MAX.x + 0.5) - p.x
	var d_n: float = p.z - (TOWN_MIN.y - 0.5)
	var d_s: float = (TOWN_MAX.y + 0.5) - p.z
	var m: float = min(d_w, d_e, d_n, d_s)
	if m == d_s:
		p.z = TOWN_MAX.y + 0.5
	elif m == d_n:
		p.z = TOWN_MIN.y - 0.5
	elif m == d_w:
		p.x = TOWN_MIN.x - 0.5
	else:
		p.x = TOWN_MAX.x + 0.5
	return p

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
	_add_lamp(Vector3(-4, 0, -83))
	_add_lamp(Vector3(4, 0, -87))

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
