extends Node3D
## Spawns and maintains the enemy population in the northern wilds.
## Tougher than the southern foes — the north does not forgive the weak.

signal kills_changed(count: int)

const SKELETON_SCENE := preload("res://src/enemy/skeleton.tscn")
const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const BANDIT_SCENE := preload("res://src/enemy/shadow_bandit.tscn")
const RESPAWN_DELAY := 8.0

const SLIME_SCRIPT := preload("res://src/enemy/slime.gd")
const WISP_SCRIPT := preload("res://src/enemy/wisp.gd")
const PUMPKIN_SCRIPT := preload("res://src/enemy/jackolantern.gd")

# [kind, scene/script, count, x_min, x_max, z_min, z_max, hp_mult, dmg_mult]
const POPULATIONS := [
	["scene", SKELETON_SCENE, 4, -26.0, 26.0, -95.0, -35.0, 1.5, 1.4],
	["scene", HUSK_SCENE, 2, -20.0, 20.0, -90.0, -40.0, 1.5, 1.4],
	["scene", BANDIT_SCENE, 2, -26.0, -5.0, -90.0, -40.0, 1.5, 1.4],
	["script", SLIME_SCRIPT, 2, -24.0, 24.0, -90.0, -40.0, 1.5, 1.4],
	["script", WISP_SCRIPT, 2, -20.0, 20.0, -95.0, -50.0, 1.5, 1.4],
	["script", PUMPKIN_SCRIPT, 2, -24.0, 10.0, -90.0, -40.0, 1.5, 1.4],
]

var kills := 0

var _rng := RandomNumberGenerator.new()
var _pending: Array = []

func _ready() -> void:
	add_to_group("north_manager")
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
	# Northern foes are tougher.
	var hp_mult := float(spec[7])
	var dmg_mult := float(spec[8])
	foe.set("max_hp", float(foe.get("max_hp")) * hp_mult)
	foe.set("attack_damage", float(foe.get("attack_damage")) * dmg_mult)
	# Confine to the northern wilds.
	foe.set("roam_min", Vector2(-28.0, -98.0))
	foe.set("roam_max", Vector2(28.0, -32.0))
	# Keep clear of Grimholt itself (the town is safe).
	var pos := Vector3(
		_rng.randf_range(float(spec[3]), float(spec[4])), 0.1,
		_rng.randf_range(float(spec[5]), float(spec[6])))
	if Grimholt.is_in_town(pos.x, pos.z, 4.0):
		pos = Vector3(20, 0, -60)
	foe.position = pos
	if foe.has_method("scale_to_level"):
		var player := get_tree().get_first_node_in_group("player")
		foe.scale_to_level(int(player.get("level")) if player != null else 1)
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
