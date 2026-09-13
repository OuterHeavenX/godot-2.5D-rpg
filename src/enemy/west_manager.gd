extends RegionSpawner
## The Ashen Highlands: Kael's reavers hold the high ground, and what the
## fires left behind walks the ash with them. Sealed until Morvain falls.

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const BANDIT_SCENE := preload("res://src/enemy/shadow_bandit.tscn")
const REAVER_SCENE := preload("res://src/enemy/ash_reaver.tscn")

const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")
const PUMPKIN_SCRIPT := preload("res://src/enemy/jackolantern.gd")

# [kind, scene/script, count, x_min, x_max, z_min, z_max, hp_mult, dmg_mult]
const POPULATIONS := [
	["scene", REAVER_SCENE, 9, -262.0, -40.0, -26.0, 26.0, 1.0, 1.0],
	["scene", BANDIT_SCENE, 4, -240.0, -40.0, -26.0, 26.0, 2.0, 1.8],
	["scene", SKELETON_SCENE, 4, -262.0, -40.0, -26.0, 26.0, 2.0, 1.8],
	["script", PUMPKIN_SCRIPT, 4, -250.0, -45.0, -24.0, 24.0, 2.0, 1.8],
	["script", WISP_SCRIPT, 3, -250.0, -45.0, -24.0, 24.0, 2.0, 1.8],
]

func _ready() -> void:
	region = Regions.WEST
	populations = POPULATIONS
	roam_min = Vector2(-266.0, -28.0)
	roam_max = Vector2(-32.0, 28.0)
	# Ashfall Watch is the one safe spot out here.
	safe_center = AshenHighlands.CAMP_CENTER
	safe_radius = AshenHighlands.CAMP_RADIUS
	avoid_lake = false
	super._ready()
	add_to_group("west_manager")

func _pick_spawn_pos(spec: Array) -> Vector3:
	for attempt in 8:
		var pos := super._pick_spawn_pos(spec)
		if AshenHighlands.is_in_camp(pos.x, pos.z, 4.0):
			continue
		if AshenHighlands.is_in_arena(pos.x, pos.z, 4.0):
			continue
		return pos
	return Vector3(-120.0, 0.1, 18.0)
