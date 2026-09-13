extends RegionSpawner
## The Sunken Vault: shades in the gallery, wights the crown buried with
## itself, and the dead of four hundred years of burials. Sealed until
## Gholl falls.

const SHADE_SCENE := preload("res://src/enemy/crypt_shade.tscn")
const WIGHT_SCENE := preload("res://src/enemy/bog_wight.tscn")
const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")

# [kind, scene/script, count, x_min, x_max, z_min, z_max, hp_mult, dmg_mult]
const POPULATIONS := [
	["scene", SHADE_SCENE, 8, -7.0, 7.0, 206.0, 336.0, 1.0, 1.0],
	["scene", SKELETON_SCENE, 8, -7.0, 7.0, 206.0, 336.0, 2.6, 1.8],
	["scene", WIGHT_SCENE, 5, -7.0, 7.0, 210.0, 332.0, 1.2, 1.1],
	["script", WISP_SCRIPT, 4, -7.0, 7.0, 210.0, 332.0, 2.6, 1.8],
]

func _ready() -> void:
	region = Regions.DEEP
	populations = POPULATIONS
	roam_min = Vector2(-30.0, 195.0)
	roam_max = Vector2(30.0, 372.0)
	# The entry hall, where the stair comes down, stays clear.
	safe_center = SunkenVault.ENTRY
	safe_radius = 9.0
	avoid_lake = false
	super._ready()
	add_to_group("deep_manager")

func _pick_spawn_pos(spec: Array) -> Vector3:
	# Half the vault's dead are laid out in the burial chambers rather
	# than standing in the gallery.
	if _rng.randf() < 0.45:
		var c := SunkenVault.chamber_center(_rng.randi() % SunkenVault.CHAMBERS.size())
		return c + Vector3(_rng.randf_range(-7.0, 7.0), 0.1, _rng.randf_range(-7.0, 7.0))
	return super._pick_spawn_pos(spec)
