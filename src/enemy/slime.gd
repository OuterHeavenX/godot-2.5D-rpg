class_name Slime
extends Monster
## A gelatinous blob that bounces through the southern wilds.
## Weak, but its lunge is surprisingly quick.

var _slime_mesh: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _hop_phase := 0.0

func _init() -> void:
	max_hp = 25.0
	walk_speed = 2.0
	chase_speed = 3.2
	aggro_range = 12.0
	attack_range = 1.8
	attack_damage = 9.0
	attack_cooldown = 1.4
	windup_time = 0.5
	xp_reward = 28
	roam_min = Vector2(-20.0, 44.0)
	roam_max = Vector2(20.0, 66.0)

func _build_body() -> void:
	super._build_body()
	# Blob: squashed sphere, toxic green.
	_slime_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	sphere.radial_segments = 12
	sphere.rings = 8
	_slime_mesh.mesh = sphere
	_slime_mesh.position = Vector3(0, 0.45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.85, 0.3)
	mat.roughness = 0.25
	_slime_mesh.set_surface_override_material(0, mat)
	body.add_child(_slime_mesh)
	# Angry eyes.
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.09
		es.height = 0.18
		eye.mesh = es
		eye.position = Vector3(side * 0.2, 0.62, 0.42)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.05, 0.05, 0.05)
		eye.set_surface_override_material(0, emat)
		body.add_child(eye)
		if side < 0.0:
			_eye_l = eye
		else:
			_eye_r = eye
	# Smaller collision for a blob.
	body_cs.shape.radius = 0.45
	body_cs.shape.height = 0.9
	body_cs.position = Vector3(0, 0.45, 0)

func _animate(delta: float) -> void:
	_hop_phase += delta * (6.0 if _state == "chase" else 3.0)
	var moving := _state == "chase" or _state == "wander"
	if _state == "windup":
		# Squash down, about to lunge.
		_slime_mesh.scale = _slime_mesh.scale.lerp(Vector3(1.3, 0.6, 1.3), 10.0 * delta)
	elif _state == "attack":
		# Stretch toward the victim.
		_slime_mesh.scale = _slime_mesh.scale.lerp(Vector3(0.8, 1.4, 0.8), 12.0 * delta)
	elif moving:
		# Bouncy hop.
		var hop: float = abs(sin(_hop_phase))
		_slime_mesh.scale = Vector3(1.0 - hop * 0.15, 1.0 + hop * 0.25, 1.0 - hop * 0.15)
		_slime_mesh.position.y = 0.45 + hop * 0.25
	else:
		# Idle wobble.
		var wob := sin(_anim_time * 2.0) * 0.05
		_slime_mesh.scale = Vector3(1.0 + wob, 1.0 - wob, 1.0 + wob)

func _on_attack_start() -> void:
	# Little hop forward on lunge.
	var tw := create_tween()
	tw.tween_property(body, "position:y", 0.35, 0.12)
	tw.tween_property(body, "position:y", 0.0, 0.18)

func _on_hit() -> void:
	# Splat flinch.
	var tw := create_tween()
	tw.tween_property(_slime_mesh, "scale", Vector3(1.4, 0.5, 1.4), 0.1)
	tw.tween_property(_slime_mesh, "scale", Vector3.ONE, 0.2)
