extends RegionSpawner
## The northern wilds beyond Emberfell's north gate: the same breeds as
## the south, but the cold preserves them — tougher, and far more of
## them. Sealed until Vorgath falls.

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const BANDIT_SCENE := preload("res://src/enemy/shadow_bandit.tscn")

const SLIME_SCRIPT := preload("res://src/enemy/slime.gd")
const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")
const PUMPKIN_SCRIPT := preload("res://src/enemy/jackolantern.gd")

# [kind, scene/script, count, x_min, x_max, z_min, z_max, hp_mult, dmg_mult]
const POPULATIONS := [
	["scene", SKELETON_SCENE, 10, -26.0, 26.0, -260.0, -35.0, 1.5, 1.4],
	["scene", HUSK_SCENE, 5, -20.0, 20.0, -255.0, -40.0, 1.5, 1.4],
	["scene", BANDIT_SCENE, 5, -26.0, -5.0, -255.0, -40.0, 1.5, 1.4],
	["script", SLIME_SCRIPT, 5, -24.0, 24.0, -255.0, -40.0, 1.5, 1.4],
	["script", WISP_SCRIPT, 5, -20.0, 20.0, -260.0, -50.0, 1.5, 1.4],
	["script", PUMPKIN_SCRIPT, 5, -24.0, 10.0, -255.0, -40.0, 1.5, 1.4],
]

func _ready() -> void:
	region = Regions.NORTH
	populations = POPULATIONS
	roam_min = Vector2(-28, -268)
	roam_max = Vector2(28, -32)
	# Grimholt is a safe town: foes are pushed out of this circle.
	safe_center = Grimholt.CENTER
	safe_radius = 14.0
	super._ready()
	add_to_group("north_manager")

func _pick_spawn_pos(spec: Array) -> Vector3:
	var pos := super._pick_spawn_pos(spec)
	if Grimholt.is_in_town(pos.x, pos.z, 4.0):
		return Vector3(20, 0.1, -60)
	return pos
