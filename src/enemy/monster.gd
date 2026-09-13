class_name Monster
extends CharacterBody3D
## Base class for procedurally-animated enemies (no skeletal animations).
## Subclasses build their visual under Body and override _animate().

const HitEffects := preload("res://src/fx/hit_effects.gd")

signal died(monster: Monster)

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

var roam_min := Vector2(-27, 34)
var roam_max := Vector2(27, 66)
# Towns are safe: enemies are pushed out of this circle (manager sets it).
var safe_center := Vector3.ZERO
var safe_radius := 0.0

var hp := 30.0
var dead := false
var avoid_lake := true
var hover := false # Wisps drift; gravity does not apply.

var _state := "wander"
var _target := Vector3.ZERO
var _idle_timer := 0.0
var _attack_cd := 0.0
var _windup_timer := 0.0
var _hit_timer := 0.0
var _anim_time := 0.0
var _rng := RandomNumberGenerator.new()
var _warn_label: Label3D
var _flash_timer := 0.0

var body: Node3D  # Subclass builds the visual here.
var body_cs: CollisionShape3D

func _ready() -> void:
	_rng.randomize()
	_pick_wander_target()
	add_to_group("skeletons")  # Counts for kill quests and the HUD.
	hp = max_hp
	_build_body()
	_warn_label = Label3D.new()
	_warn_label.text = "!"
	_warn_label.font_size = 96
	_warn_label.modulate = Color(1, 0.15, 0.1)
	_warn_label.outline_size = 12
	_warn_label.position = Vector3(0, 2.3, 0)
	_warn_label.visible = false
	add_child(_warn_label)

## Subclass override: construct the visual under `body`.
func _build_body() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	body_cs = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.2
	body_cs.shape = cap
	body_cs.position = Vector3(0, 0.6, 0)
	add_child(body_cs)

## Subclass override: procedural animation. Called every physics frame.
func _animate(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	_anim_time += delta

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
		"windup":
			_face(to_player, delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_warn_label.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
			_windup_timer -= delta
			if _hit_timer > 0.0:
				_state = "chase"
				_warn_label.visible = false
			elif _windup_timer <= 0.0:
				_state = "attack"
				_attack_cd = attack_cooldown
				_warn_label.visible = false
				_on_attack_start()
				var tw := create_tween()
				tw.tween_interval(0.35)
				tw.tween_callback(_deal_hit.bind(player))
		"attack":
			_face(to_player, delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			if _attack_cd <= 0.0:
				_state = "chase"

	_animate(delta)
	_update_flash()

	if not hover:
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = 0.0
	else:
		velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, roam_min.x, roam_max.x)
	global_position.z = clampf(global_position.z, roam_min.y, roam_max.y)
	if safe_radius > 0.0:
		# Towns are safe: shove back out of the protected circle.
		var flat := Vector2(global_position.x - safe_center.x,
			global_position.z - safe_center.z)
		if flat.length() < safe_radius:
			var out := flat.normalized() if flat.length() > 0.01 else Vector2(1, 0)
			global_position.x = safe_center.x + out.x * safe_radius
			global_position.z = safe_center.z + out.y * safe_radius
	if avoid_lake:
		global_position = IslandLake.keep_out_of_water(global_position)

## Subclass hook: fired when the attack swing starts.
func _on_attack_start() -> void:
	pass

func _wander(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 1.0:
		_idle_timer = _rng.randf_range(1.0, 3.5)
		return
	_move_toward(to.normalized(), walk_speed, delta)

func _pick_wander_target() -> void:
	_target = Vector3(
		_rng.randf_range(roam_min.x, roam_max.x), 0,
		_rng.randf_range(roam_min.y, roam_max.y))
	if safe_radius > 0.0:
		var flat := Vector2(_target.x - safe_center.x, _target.z - safe_center.z)
		if flat.length() < safe_radius:
			var out := flat.normalized() if flat.length() > 0.01 else Vector2(1, 0)
			_target.x = safe_center.x + out.x * (safe_radius + 2.0)
			_target.z = safe_center.z + out.y * (safe_radius + 2.0)

func _move_toward(dir: Vector3, spd: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * spd, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * spd, 20.0 * delta)
	_face(dir, delta)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01 or body == null:
		return
	var yaw := atan2(dir.x, dir.z)
	body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(1.0, turn_speed * delta))

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
	var hit_pos := global_position + Vector3(0, 1.2, 0)
	HitEffects.burst(get_tree().current_scene, hit_pos)
	HitEffects.damage_number(get_tree().current_scene, hit_pos, "-%d" % int(amount), Color(1.0, 0.25, 0.2))
	_flash_timer = 0.15
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01 and body != null:
		body.rotation.y = atan2(away.x, away.z)
	if hp <= 0.0:
		_die()
	else:
		AudioMan.play("bone_hit", 1.0, -3.0)
		_hit_timer = 0.45
		_on_hit()

## Subclass hook: fired on non-lethal hit (flinch animation).
func _on_hit() -> void:
	pass

## Red damage flash on all body meshes.
func _update_flash() -> void:
	if body == null:
		return
	var flash := _flash_timer > 0.0
	for mi in _collect_meshes(body):
		for si in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(si) as StandardMaterial3D
			if mat != null:
				mat.emission_enabled = flash
				if flash:
					mat.emission = Color(1, 0.2, 0.15)
					mat.emission_energy_multiplier = 2.0

func _collect_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_collect_meshes(ch))
	return out

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	if body_cs != null:
		body_cs.set_deferred("disabled", true)
	_warn_label.visible = false
	AudioMan.play("bone_die", 0.8, -2.0)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_reward)
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 1.5, 0), "+%d XP" % xp_reward, Color(1.0, 0.85, 0.3))
	if player != null and player.has_method("add_gold"):
		var gold_amount := randi_range(5, 15)
		player.add_gold(gold_amount)
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), "+%d G" % gold_amount, Color(1.0, 0.75, 0.2))
	if randf() < 0.40:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
		get_parent().add_child(drop)
	died.emit(self)
	# Death: squash flat, then sink.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(body, "scale", Vector3(1.4, 0.1, 1.4), 0.4)
	tw.tween_property(self, "position:y", position.y - 1.2, 1.2).set_delay(0.5)
	tw.chain().tween_callback(queue_free)

func apply_slow(duration: float) -> void:
	# Frost Bolt chill: reuse the hit-flinch to interrupt and slow.
	_hit_timer = maxf(_hit_timer, duration)
