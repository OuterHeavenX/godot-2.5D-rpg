extends Node3D
## Spawns and maintains the enemy population in the wilderness:
## skeletons everywhere, drowned husks near the black water,
## and shadow bandits in the western wilds. Tracks kills for the HUD.

signal kills_changed(count: int)

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const BANDIT_SCENE := preload("res://src/enemy/shadow_bandit.tscn")
const RESPAWN_DELAY := 8.0

# Each entry: [scene, count, x_min, x_max, z_min, z_max].
const POPULATIONS := [
	[SKELETON_SCENE, 5, -27.0, 27.0, 34.0, 66.0],
	[HUSK_SCENE, 3, 6.0, 22.0, 40.0, 70.0],
	[BANDIT_SCENE, 3, -27.0, -8.0, 34.0, 66.0],
]

var kills := 0

var _rng := RandomNumberGenerator.new()
var _pending: Array = [] # respawn specs waiting on the timer

func _ready() -> void:
	add_to_group("skeleton_manager")
	_rng.randomize()
	for spec in POPULATIONS:
		for i in range(int(spec[1])):
			_spawn(spec)

func _spawn(spec: Array) -> void:
	var scene: PackedScene = spec[0]
	var foe := scene.instantiate() as Skeleton
	foe.position = Vector3(
		_rng.randf_range(float(spec[2]), float(spec[3])), 0.1,
		_rng.randf_range(float(spec[4]), float(spec[5])))
	foe.died.connect(_on_foe_died.bind(spec))
	add_child(foe)

func _on_foe_died(_foe: Skeleton, spec: Array) -> void:
	kills += 1
	kills_changed.emit(kills)
	_pending.append(spec)
	var tw := create_tween()
	tw.tween_interval(RESPAWN_DELAY)
	tw.tween_callback(_respawn_one)

func _respawn_one() -> void:
	if _pending.is_empty():
		return
	var spec: Array = _pending.pop_front()
	_spawn(spec)
