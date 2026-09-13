class_name RegionSpawner
extends Node3D
## Keeps one region's foes alive while the hero is there, and clears them
## out once they leave. Only the region the hero stands in pays for its
## monsters, so the world can be large without the browser paying for all
## of it at once.
##
## Subclasses set `region` and `populations` before calling super._ready().
## Kill counts survive sleeping, so quests accepted in one region can be
## finished in another.

signal kills_changed(count: int)

const RESPAWN_DELAY := 8.0
## How far outside a region the hero can be with its monsters still
## awake. Generous enough that nothing pops in at a gate, tight enough
## that standing in the village square does not wake all four spokes:
## the regions start barely thirty metres from the hub.
const WAKE_MARGIN := 14.0

## Which region this spawner belongs to (see Regions).
var region := ""
## Each entry: [kind, scene/script, count, x_min, x_max, z_min, z_max,
## hp_mult, dmg_mult]. kind "scene" = PackedScene, "script" = Monster script.
var populations: Array = []
## Bounds a foe of this region may roam within.
var roam_min := Vector2(-27, 34)
var roam_max := Vector2(27, 66)
## A town the foes are pushed out of (radius 0 = none).
var safe_center := Vector3.ZERO
var safe_radius := 0.0
## Whether foes here should steer around the black water.
var avoid_lake := true

var kills := 0
var awake := false

var _rng := RandomNumberGenerator.new()
var _pending: Array = []
var _live: Array[Node] = []

func _ready() -> void:
	add_to_group("foe_spawner")
	_rng.randomize()

## Populate the region. Safe to call when already awake.
func wake() -> void:
	if awake:
		return
	awake = true
	_pending.clear()
	for spec in populations:
		for i in range(int(spec[2])):
			_spawn(spec)

## Clear the region out. Kills and quest progress are untouched.
func sleep() -> void:
	if not awake:
		return
	awake = false
	_pending.clear()
	for foe in _live:
		if is_instance_valid(foe):
			foe.queue_free()
	_live.clear()

## Foes only belong to a region the hero can actually reach.
func can_wake() -> bool:
	if region == "":
		return true
	var qm := get_node_or_null("/root/QuestMan")
	if qm == null:
		return true
	return bool(qm.call("region_unlocked", region))

func _player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	return int(player.get("level")) if player != null else 1

## Where a foe of this spec starts. Subclasses override to dodge
## landmarks (a town square, a lake, a boss arena).
func _pick_spawn_pos(spec: Array) -> Vector3:
	return Vector3(
		_rng.randf_range(float(spec[3]), float(spec[4])), 0.1,
		_rng.randf_range(float(spec[5]), float(spec[6])))

func _spawn(spec: Array) -> void:
	var foe: CharacterBody3D
	if String(spec[0]) == "scene":
		var scene: PackedScene = spec[1]
		foe = scene.instantiate() as CharacterBody3D
	else:
		var script: Script = spec[1]
		foe = script.new() as CharacterBody3D
	if foe == null:
		return
	if spec.size() > 8:
		foe.set("max_hp", float(foe.get("max_hp")) * float(spec[7]))
		foe.set("attack_damage", float(foe.get("attack_damage")) * float(spec[8]))
	foe.set("roam_min", roam_min)
	foe.set("roam_max", roam_max)
	foe.set("avoid_lake", avoid_lake)
	if safe_radius > 0.0:
		foe.set("safe_center", safe_center)
		foe.set("safe_radius", safe_radius)
	foe.position = _pick_spawn_pos(spec)
	if foe.has_method("scale_to_level"):
		foe.scale_to_level(_player_level())
	foe.connect("died", _on_foe_died.bind(spec))
	add_child(foe)
	_live.append(foe)

func _on_foe_died(foe: Variant, spec: Array) -> void:
	if foe is Node:
		_live.erase(foe)
	kills += 1
	kills_changed.emit(kills)
	if not awake:
		return
	_pending.append(spec)
	var tw := create_tween()
	tw.tween_interval(RESPAWN_DELAY)
	tw.tween_callback(_respawn_one)

func _respawn_one() -> void:
	if not awake or _pending.is_empty():
		return
	var spec: Array = _pending.pop_front()
	_spawn(spec)

## Re-tune every living foe to a level (after loading a save).
func rescale_all(player_level: int) -> void:
	for node in get_tree().get_nodes_in_group("skeletons"):
		if node.is_in_group("boss") or bool(node.get("dead")):
			continue
		if node.has_method("scale_to_level"):
			node.scale_to_level(player_level)
