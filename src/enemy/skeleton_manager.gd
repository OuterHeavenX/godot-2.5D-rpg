extends RegionSpawner
## The southern wilds: skeletons, drowned husks, shadow bandits, slimes,
## wisps and jack-o'-lanterns. The first spoke of the world, open from
## the moment the hero walks out of Emberfell's south gate.

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const BANDIT_SCENE := preload("res://src/enemy/shadow_bandit.tscn")

const SLIME_SCRIPT := preload("res://src/enemy/slime.gd")
const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")
const PUMPKIN_SCRIPT := preload("res://src/enemy/jackolantern.gd")

# [kind, scene/script, count, x_min, x_max, z_min, z_max, hp_mult, dmg_mult]
const POPULATIONS := [
	["scene", SKELETON_SCENE, 4, -27.0, 27.0, 34.0, 66.0, 1.0, 1.0],
	["scene", HUSK_SCENE, 2, 6.0, 22.0, 40.0, 70.0, 1.0, 1.0],
	["scene", BANDIT_SCENE, 2, -27.0, -8.0, 34.0, 66.0, 1.0, 1.0],
	["script", SLIME_SCRIPT, 3, -20.0, 20.0, 44.0, 66.0, 1.0, 1.0],
	["script", WISP_SCRIPT, 2, 20.0, 50.0, 38.0, 72.0, 1.0, 1.0],
	["script", PUMPKIN_SCRIPT, 2, -24.0, 10.0, 40.0, 66.0, 1.0, 1.0],
]

const HUSK_SCRIPT := preload("res://src/enemy/drowned_husk.gd")

func _ready() -> void:
	region = Regions.SOUTH
	populations = POPULATIONS
	roam_min = Vector2(-27, 34)
	roam_max = Vector2(27, 72)
	super._ready()
	add_to_group("skeleton_manager")

## Husks here have the black water's shore to lurk along; the ones in
## other regions sink where they stand.
func _spawn(spec: Array) -> void:
	super._spawn(spec)
	if _live.is_empty():
		return
	var foe: Node = _live[_live.size() - 1]
	if foe is DrownedHusk:
		foe.set("lurk_in_place", false)
		foe.call("_start_lurking")
