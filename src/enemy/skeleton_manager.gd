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
		_rng.randf_range(-27.0, 27.0), 0.1,
		_rng.randf_range(34.0, 66.0))
	skel.died.connect(_on_skeleton_died)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		skel.scale_to_level(int(player.get("level")))
	add_child(skel)

func _on_skeleton_died(_skel: Skeleton) -> void:
	kills += 1
	kills_changed.emit(kills)
	_pending_respawns += 1
	var tw := create_tween()
	tw.tween_interval(RESPAWN_DELAY)
	tw.tween_callback(_respawn_one)

## Re-tune every living skeleton to a level (after loading a save).
func rescale_all(player_level: int) -> void:
	for node in get_tree().get_nodes_in_group("skeletons"):
		var skel := node as Skeleton
		if skel != null and not skel.dead and not skel.is_in_group("boss"):
			skel.scale_to_level(player_level)

func _respawn_one() -> void:
	_pending_respawns = maxi(0, _pending_respawns - 1)
	_spawn()
