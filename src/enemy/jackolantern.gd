class_name JackOLantern
extends Monster
## A haunted KayKit jack-o'-lantern that hops through the wilds at night.
## Heavy slam, but telegraphs it with a brightening grin.

const PUMPKIN_SCENE := preload("res://src/enemy/models/jackolantern.gltf")

var _pumpkin: Node3D
var _hop_phase := 0.0
var _mouth_light: OmniLight3D

func _init() -> void:
	max_hp = 40.0
	walk_speed = 1.8
	chase_speed = 3.0
	aggro_range = 11.0
	attack_range = 2.0
	attack_damage = 14.0
	attack_cooldown = 1.8
	windup_time = 0.8
	xp_reward = 38
	roam_min = Vector2(-24.0, 40.0)
	roam_max = Vector2(10.0, 66.0)

func _build_body() -> void:
	super._build_body()
	_pumpkin = PUMPKIN_SCENE.instantiate() as Node3D
	_pumpkin.position = Vector3(0, 0.35, 0)
	body.add_child(_pumpkin)
	# Eerie grin-light.
	_mouth_light = OmniLight3D.new()
	_mouth_light.light_color = Color(1.0, 0.55, 0.15)
	_mouth_light.light_energy = 0.6
	_mouth_light.omni_range = 3.5
	_mouth_light.position = Vector3(0, 0.8, 0.3)
	body.add_child(_mouth_light)
	body_cs.shape.radius = 0.5
	body_cs.shape.height = 1.0
	body_cs.position = Vector3(0, 0.5, 0)

func _animate(delta: float) -> void:
	_hop_phase += delta * (7.0 if _state == "chase" else 3.5)
	var moving := _state == "chase" or _state == "wander"
	if _state == "windup":
		# Crouch, grin brightens.
		var k := 1.0 - _windup_timer / windup_time
		_pumpkin.scale = _pumpkin.scale.lerp(Vector3(1.25, 0.7, 1.25), 10.0 * delta)
		_mouth_light.light_energy = 0.6 + k * 2.0
	elif _state == "attack":
		# Slam stretch.
		_pumpkin.scale = _pumpkin.scale.lerp(Vector3(0.85, 1.35, 0.85), 12.0 * delta)
		_mouth_light.light_energy = 2.5
	elif moving:
		var hop: float = abs(sin(_hop_phase))
		_pumpkin.position.y = 0.35 + hop * 0.35
		_pumpkin.scale = Vector3(1.0 - hop * 0.1, 1.0 + hop * 0.15, 1.0 - hop * 0.1)
		_mouth_light.light_energy = 0.6
	else:
		# Idle: gentle rock.
		_pumpkin.rotation.z = sin(_anim_time * 1.5) * 0.08
		_mouth_light.light_energy = 0.6 + sin(_anim_time * 2.0) * 0.15

func _on_attack_start() -> void:
	# Hop-slam.
	var tw := create_tween()
	tw.tween_property(_pumpkin, "position:y", 1.1, 0.15)
	tw.tween_property(_pumpkin, "position:y", 0.35, 0.2)

func _on_hit() -> void:
	# Wobble.
	var tw := create_tween()
	tw.tween_property(_pumpkin, "rotation:z", 0.3, 0.08)
	tw.tween_property(_pumpkin, "rotation:z", -0.2, 0.1)
	tw.tween_property(_pumpkin, "rotation:z", 0.0, 0.12)
