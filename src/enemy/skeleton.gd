class_name Skeleton
extends CharacterBody3D
## KayKit Skeleton Warrior enemy. Wanders the wilderness, chases the player
## on sight, attacks in melee, and collapses when slain.

const HitEffects := preload("res://src/fx/hit_effects.gd")

signal died(skeleton: Skeleton)

var max_hp := 30.0
var walk_speed := 2.2
var chase_speed := 3.6
var turn_speed := 8.0
var aggro_range := 13.0
var attack_range := 2.1
var attack_damage := 12.0
var attack_cooldown := 1.6
var windup_time := 0.7
var xp_reward := 30

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_ATTACK := "1H_Melee_Attack_Slice_Horizontal"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_C_Skeletons"
const ANIM_WINDUP := "Idle_Combat"

# Bounds this skeleton roams (the manager leaves the default wilderness).
var roam_min := Vector2(-27, 34)
var roam_max := Vector2(27, 66)

var hp := 30.0
var dead := false
var avoid_lake := true # The wild dead cannot cross the black water.
var _slow_timer := 0.0

var _state := "wander"
var _target := Vector3.ZERO
var _idle_timer := 0.0
var _attack_cd := 0.0
var _windup_timer := 0.0
var _hit_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _warn_label: Label3D

@onready var rig: Node3D = $SkeletonRig
@onready var anim: AnimationPlayer = $SkeletonRig/AnimationPlayer
@onready var body_cs: CollisionShape3D = $BodyCollision

func _ready() -> void:
	_rng.randomize()
	_pick_wander_target()
	add_to_group("skeletons")
	hp = max_hp
	anim.play(ANIM_IDLE)
	# Red "!" warning that flashes during the attack wind-up (enemy ATB).
	_warn_label = Label3D.new()
	_warn_label.text = "!"
	_warn_label.font_size = 96
	_warn_label.modulate = Color(1, 0.15, 0.1)
	_warn_label.outline_size = 12
	_warn_label.position = Vector3(0, 2.3, 0)
	_warn_label.visible = false
	add_child(_warn_label)

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
			if dist < aggro_range:
				_state = "chase"
			else:
				_wander(delta)
		"chase":
			if dist > aggro_range * 1.6:
				_state = "wander"
				_pick_wander_target()
			elif dist < attack_range:
				_state = "windup"
				_windup_timer = windup_time
				_warn_label.visible = true
			else:
				_move_toward(to_player.normalized(), chase_speed, delta)
				_play(ANIM_WALK)
		"windup":
			# Enemy ATB: telegraphed wind-up. Dodge now!
			_face(to_player, delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_play(ANIM_WINDUP)
			# Pulse the warning.
			_warn_label.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
			_windup_timer -= delta
			if _hit_timer > 0.0:
				# Getting hit interrupts the wind-up.
				_state = "chase"
				_warn_label.visible = false
			elif _windup_timer <= 0.0:
				_state = "attack"
				_attack_cd = attack_cooldown
				_warn_label.visible = false
				_play(ANIM_ATTACK)
				var tw := create_tween()
				tw.tween_interval(0.35)
				tw.tween_callback(_deal_hit.bind(player))
		"attack":
			_face(to_player, delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			# Recover when the swing is done, then re-engage.
			if anim.current_animation != ANIM_ATTACK:
				_play(ANIM_IDLE)
			if _attack_cd <= 0.0:
				_state = "chase"

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Stay inside the wilderness.
	global_position.x = clampf(global_position.x, roam_min.x, roam_max.x)
	global_position.z = clampf(global_position.z, roam_min.y, roam_max.y)
	if avoid_lake:
		# The black water bars the wild dead (see IslandLake).
		var flat := Vector2(global_position.x, global_position.z)
		var to_lake := flat - Vector2(17.0, 57.0)
		var lake_dist := to_lake.length()
		if lake_dist < 9.6 and lake_dist > 0.01:
			var out := to_lake / lake_dist * 9.6
			global_position.x = 17.0 + out.x
			global_position.z = 57.0 + out.y

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
	_move_toward(to.normalized(), walk_speed, delta)
	_play(ANIM_WALK)

func _pick_wander_target() -> void:
	_target = Vector3(
		_rng.randf_range(roam_min.x, roam_max.x), 0,
		_rng.randf_range(roam_min.y, roam_max.y))

func _move_toward(dir: Vector3, spd: float, delta: float) -> void:
	if _slow_timer > 0.0:
		spd *= 0.45  # Chilled: half speed.
		_slow_timer -= delta
	velocity.x = move_toward(velocity.x, dir.x * spd, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 20.0 * delta)
	_face(dir, delta)

## Frost Bolt chill: slows movement for a duration.
func apply_slow(duration: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var yaw := atan2(dir.x, dir.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, minf(1.0, turn_speed * delta))

func _deal_hit(player: Node3D) -> void:
	if dead or player == null or not is_instance_valid(player):
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() < attack_range * 1.4 and player.has_method("take_damage"):
		player.take_damage(attack_damage, global_position)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead:
		return
	hp -= amount
	# Combat feedback: hit particles and damage number.
	var hit_pos := global_position + Vector3(0, 1.2, 0)
	HitEffects.burst(get_tree().current_scene, hit_pos)
	HitEffects.damage_number(get_tree().current_scene, hit_pos, "-%d" % int(amount), Color(1.0, 0.25, 0.2))
	# Face the attacker and flinch.
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		rig.rotation.y = atan2(away.x, away.z)
	if hp <= 0.0:
		_die()
	else:
		AudioMan.play("bone_hit", 1.0, -3.0)
		_hit_timer = 0.45
		_play(ANIM_HIT)

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	body_cs.set_deferred("disabled", true)
	_play(ANIM_DEATH)
	AudioMan.play("bone_die", 0.8, -2.0)
	# Award XP and gold to the player.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_reward)
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 1.5, 0), "+%d XP" % xp_reward, Color(1.0, 0.85, 0.3))
	if player != null and player.has_method("add_gold"):
		var gold_amount := randi_range(5, 15)
		player.add_gold(gold_amount)
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), "+%d G" % gold_amount, Color(1.0, 0.75, 0.2))
	# 40% chance to drop a potion.
	if randf() < 0.40:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
		get_parent().add_child(drop)
	died.emit(self)
	# Sink into the ground, then free.
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "position:y", position.y - 1.2, 0.8)
	tw.tween_callback(queue_free)

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		anim.play(clip)
