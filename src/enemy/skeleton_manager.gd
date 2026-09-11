extends Node3D
## Spawns and maintains the skeleton population in the wilderness.
## Tracks kills for the HUD.

signal kills_changed(count: int)

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const POPULATION := 6
const RESPAWN_DELAY := 8.0

var kills := 0

var _rng := RandomNumberGenerator.new()
var _pending_respawns := 0

func _ready() -> void:
	add_to_group("skeleton_manager")
	_rng.randomize()
	for i in range(POPULATION):
		_spawn()

func _spawn() -> void:
	var skel := SKELETON_SCENE.instantiate() as Skeleton
	skel.position = Vector3(
		_rng.randf_range(Skeleton.roam_min.x, Skeleton.roam_max.x), 0.1,
		_rng.randf_range(Skeleton.roam_min.y, Skeleton.roam_max.y))
	skel.died.connect(_on_skeleton_died)
	add_child(skel)

func _on_skeleton_died(_skel: Skeleton) -> void:
	kills += 1
	kills_changed.emit(kills)
	_pending_respawns += 1
	var tw := create_tween()
	tw.tween_interval(RESPAWN_DELAY)
	tw.tween_callback(_respawn_one)

func _respawn_one() -> void:
	_pending_respawns = maxi(0, _pending_respawns - 1)
	_spawn()
