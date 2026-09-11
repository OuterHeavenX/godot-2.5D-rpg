class_name Skeleton
extends CharacterBody3D
## KayKit Skeleton Warrior enemy. Wanders the wilderness, chases the player
## on sight, attacks in melee, and collapses when slain.

signal died(skeleton: Skeleton)

const MAX_HP := 30.0
const WALK_SPEED := 2.2
const CHASE_SPEED := 3.6
const TURN_SPEED := 8.0
const AGGRO_RANGE := 13.0
const ATTACK_RANGE := 2.1
const ATTACK_DAMAGE := 12.0
const ATTACK_COOLDOWN := 1.4

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_ATTACK := "1H_Melee_Attack_Slice_Horizontal"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_C_Skeletons"

# Wilderness bounds the skeletons roam (set by the manager).
static var roam_min := Vector2(-27, 34)
static var roam_max := Vector2(27, 66)

var hp := MAX_HP
var dead := false

var _state := "wander"
var _target := Vector3.ZERO
var _idle_timer := 0.0
var _attack_cd := 0.0
var _hit_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var rig: Node3D = $SkeletonRig
@onready var anim: AnimationPlayer = $SkeletonRig/AnimationPlayer
@onready var body_cs: CollisionShape3D = $BodyCollision

func _ready() -> void:
	_rng.randomize()
	_pick_wander_target()
	add_to_group("skeletons")
	anim.play(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var to_player := Vector3.ZERO
	var dist := INF
	if player != null:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	match _state:
		"wander":
			if dist < AGGRO_RANGE:
				_state = "chase"
			else:
				_wander(delta)
		"chase":
			if dist > AGGRO_RANGE * 1.6:
				_state = "wander"
				_pick_wander_target()
			elif dist < ATTACK_RANGE:
				_state = "attack"
				_attack_cd = 0.0
			else:
				_move_toward(to_player.normalized(), CHASE_SPEED, delta)
				_play(ANIM_WALK)
		"attack":
			if dist > ATTACK_RANGE * 1.3:
				_state = "chase"
			else:
				_face(to_player, delta)
				velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
				if _attack_cd <= 0.0 and _hit_timer <= 0.0:
					_attack_cd = ATTACK_COOLDOWN
					_play(ANIM_ATTACK)
					# Damage lands mid-swing.
					var tw := create_tween()
					tw.tween_interval(0.35)
					tw.tween_callback(_deal_hit.bind(player))

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Stay inside the wilderness.
	global_position.x = clampf(global_position.x, roam_min.x, roam_max.x)
	global_position.z = clampf(global_position.z, roam_min.y, roam_max.y)

func _wander(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_play(ANIM_IDLE)
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 1.0:
		_idle_timer = _rng.randf_range(1.0, 3.5)
		return
	_move_toward(to.normalized(), WALK_SPEED, delta)
	_play(ANIM_WALK)

func _pick_wander_target() -> void:
	_target = Vector3(
		_rng.randf_range(roam_min.x, roam_max.x), 0,
		_rng.randf_range(roam_min.y, roam_max.y))

func _move_toward(dir: Vector3, spd: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * spd, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 20.0 * delta)
	_face(dir, delta)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var yaw := atan2(dir.x, dir.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, minf(1.0, TURN_SPEED * delta))

func _deal_hit(player: Node3D) -> void:
	if dead or player == null or not is_instance_valid(player):
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() < ATTACK_RANGE * 1.4 and player.has_method("take_damage"):
		player.take_damage(ATTACK_DAMAGE, global_position)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead:
		return
	hp -= amount
	# Face the attacker and flinch.
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		rig.rotation.y = atan2(away.x, away.z)
	if hp <= 0.0:
		_die()
	else:
		_hit_timer = 0.45
		_play(ANIM_HIT)

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	body_cs.set_deferred("disabled", true)
	_play(ANIM_DEATH)
	died.emit(self)
	# Sink into the ground, then free.
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "position:y", position.y - 1.2, 0.8)
	tw.tween_callback(queue_free)

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		anim.play(clip)
