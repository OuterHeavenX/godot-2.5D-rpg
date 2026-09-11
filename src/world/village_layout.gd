class_name VillageLayout
extends RefCounted
## Shared village layout data: building positions, well plaza, and paths.
## Used by village.gd (buildings), paths.gd (cobblestone), and
## grass_field.gd (to keep grass off the stone).

const WELL_POS := Vector3(0, 0, 7)
const PLAZA_RADIUS := 4.5
const PATH_WIDTH := 2.4
const BUILDING_SCALE := 5.0

# model path, position, collision footprint (x, z) at 1x
const BUILDINGS := [
	["res://src/world/buildings/tavern.gltf", Vector3(-11, 0, -7), Vector2(1.17, 1.33)],
	["res://src/world/buildings/market.gltf", Vector3(9, 0, -9), Vector2(1.80, 1.32)],
	["res://src/world/buildings/blacksmith.gltf", Vector3(17, 0, 3), Vector2(1.29, 1.25)],
	["res://src/world/buildings/house_a.gltf", Vector3(-15, 0, 7), Vector2(0.80, 0.86)],
	["res://src/world/buildings/house_b.gltf", Vector3(-7, 0, 17), Vector2(0.87, 1.10)],
	["res://src/world/buildings/house_a.gltf", Vector3(13, 0, 15), Vector2(0.80, 0.86)],
	["res://src/world/buildings/well.gltf", WELL_POS, Vector2(0.65, 0.75)],
]

## Path segments as (start, end) Vector3 pairs, at ground level.
## Paths run from the plaza edge to each building's center (the end
## hides under the building so no hard edge shows).
static func path_segments() -> Array:
	var segs := []
	for b in BUILDINGS:
		var dest: Vector3 = b[1]
		if dest == WELL_POS:
			continue
		var dir := dest - WELL_POS
		dir.y = 0.0
		dir = dir.normalized()
		var start := WELL_POS + dir * (PLAZA_RADIUS - 0.3)
		segs.append([start, dest])
	return segs

## True if a ground position should have no grass (on plaza or a path).
static func is_stone(pos: Vector3) -> bool:
	var flat := Vector2(pos.x, pos.z)
	if flat.distance_to(Vector2(WELL_POS.x, WELL_POS.z)) < PLAZA_RADIUS + 0.6:
		return true
	var margin := PATH_WIDTH * 0.5 + 0.5
	for seg in path_segments():
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		if _dist_to_segment(flat, Vector2(a.x, a.z), Vector2(b.x, b.z)) < margin:
			return true
	return false

static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
