extends RegionSpawner
## The Mirefen: bog wights on the old causeway, husks under the water, and
## the lights that lead you off it. Sealed until Kael falls.

const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const WIGHT_SCENE := preload("res://src/enemy/bog_wight.tscn")
const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")

const SLIME_SCRIPT := preload("res://src/enemy/slime.gd")
const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")

# [kind, scene/script, count, x_min, x_max, z_min, z_max, hp_mult, dmg_mult]
const POPULATIONS := [
	["scene", WIGHT_SCENE, 7, 44.0, 262.0, -26.0, 26.0, 1.0, 1.0],
	["scene", HUSK_SCENE, 7, 44.0, 262.0, -26.0, 26.0, 2.4, 2.1],
	["scene", SKELETON_SCENE, 4, 44.0, 262.0, -26.0, 26.0, 2.4, 2.1],
	["script", SLIME_SCRIPT, 4, 48.0, 258.0, -24.0, 24.0, 2.4, 2.1],
	["script", WISP_SCRIPT, 5, 48.0, 258.0, -24.0, 24.0, 2.4, 2.1],
]

func _ready() -> void:
	region = Regions.EAST
	populations = POPULATIONS
	roam_min = Vector2(34.0, -28.0)
	roam_max = Vector2(266.0, 28.0)
	# The chapel island is the one place in the fen the dead keep off.
	safe_center = Mirefen.CHAPEL_CENTER
	safe_radius = Mirefen.CHAPEL_RADIUS
	avoid_lake = false
	super._ready()
	add_to_group("east_manager")

func _spawn(spec: Array) -> void:
	super._spawn(spec)
	# Husks out here have no shoreline to crawl back to: they sink where
	# they stand and wait for the causeway to carry someone past.
	if _live.is_empty():
		return
	var foe: Node = _live[_live.size() - 1]
	if foe is DrownedHusk:
		foe.set("lurk_in_place", true)

func _pick_spawn_pos(spec: Array) -> Vector3:
	for attempt in 8:
		var pos := super._pick_spawn_pos(spec)
		if Mirefen.is_at_chapel(pos.x, pos.z, 4.0):
			continue
		if Mirefen.is_in_pool(pos.x, pos.z, 4.0):
			continue
		return pos
	return Vector3(120.0, 0.1, 18.0)
