extends Node3D
## Spawns and maintains the enemy population in the wilderness:
## skeletons, drowned husks, shadow bandits, slimes, wisps, and
## jack-o'-lanterns. Tracks kills for the HUD.

signal kills_changed(count: int)

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const BANDIT_SCENE := preload("res://src/enemy/shadow_bandit.tscn")
const RESPAWN_DELAY := 8.0

const SLIME_SCRIPT := preload("res://src/enemy/slime.gd")
const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")
const PUMPKIN_SCRIPT := preload("res://src/enemy/jackolantern.gd")

# Each entry: [kind, count, x_min, x_max, z_min, z_max].
# kind "scene" = PackedScene, kind "script" = Monster script (built in code).
const POPULATIONS := [
	["scene", SKELETON_SCENE, 4, -27.0, 27.0, 34.0, 66.0],
	["scene", HUSK_SCENE, 2, 6.0, 22.0, 40.0, 70.0],
	["scene", BANDIT_SCENE, 2, -27.0, -8.0, 34.0, 66.0],
	["script", SLIME_SCRIPT, 3, -20.0, 20.0, 44.0, 66.0],
	["script", WISP_SCRIPT, 2, 20.0, 50.0, 38.0, 72.0],
	["script", PUMPKIN_SCRIPT, 2, -24.0, 10.0, 40.0, 66.0],
]

var kills := 0

var _rng := RandomNumberGenerator.new()
var _pending: Array = []

func _ready() -> void:
	add_to_group("skeleton_manager")
	_rng.randomize()
	for spec in POPULATIONS:
		for i in range(int(spec[2])):
			_spawn(spec)

func _spawn(spec: Array) -> void:
	var foe: CharacterBody3D
	if String(spec[0]) == "scene":
		var scene: PackedScene = spec[1]
		foe = scene.instantiate() as CharacterBody3D
	else:
		var script: Script = spec[1]
		foe = script.new() as CharacterBody3D
	foe.position = Vector3(
		_rng.randf_range(float(spec[3]), float(spec[4])), 0.1,
		_rng.randf_range(float(spec[5]), float(spec[6])))
	foe.connect("died", _on_foe_died.bind(spec))
	add_child(foe)

func _on_foe_died(_foe: Variant, spec: Array) -> void:
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
