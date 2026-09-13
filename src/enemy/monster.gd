class_name Monster
extends CharacterBody3D
## Base class for procedurally-animated enemies (no skeletal animations).
## Subclasses build their visual under Body and override _animate().

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
var gold_min := 5
var gold_max := 15
# Sound played when this foe notices the party ("" for silent).
var voice := ""
var voice_pitch := 1.0
# Drop table: [item_id, chance, min, max]. See ItemDB.
var drops := [["potion", 0.40, 1, 1]]

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
var _flash_on := false
var _saved_emission := {} # material -> [enabled, color, energy]
var _slow_timer := 0.0
var _base_stats := {}

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
	_slow_timer = maxf(0.0, _slow_timer - delta)
	_anim_time += delta

	var player := _nearest_victim()
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
				if voice != "":
					AudioMan.play(voice, voice_pitch, -6.0)
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


## Roll this foe's drop table and scatter the results on the ground.
## Entries: [item_id, chance, min, max]. Potions use the potion pickup.
func _spawn_drops() -> void:
	for entry in drops:
		if randf() >= float(entry[1]):
			continue
		var n := randi_range(int(entry[2]), int(entry[3]))
		if n <= 0:
			continue
		var drop: Node3D
		if String(entry[0]) == "potion":
			drop = preload("res://src/item/potion_drop.gd").new()
		else:
			drop = preload("res://src/item/item_drop.gd").new()
			drop.set("item_id", String(entry[0]))
			drop.set("count", n)
		drop.position = position + Vector3(randf_range(-0.8, 0.8), 0.1, randf_range(-0.8, 0.8))
		get_parent().add_child(drop)

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
	if _slow_timer > 0.0:
		spd *= 0.45  # Chilled: half speed.
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

## Red damage flash on all body meshes. Only touches materials on the
## frames the flash turns on or off, and restores their own emission
## afterwards (wisp cores and Morvain's heart glow on their own).
func _update_flash() -> void:
	if body == null:
		return
	var flash := _flash_timer > 0.0
	if flash == _flash_on:
		return
	_flash_on = flash
	if flash:
		_saved_emission.clear()
		for mi in _collect_meshes(body):
			for si in range(mi.get_surface_override_material_count()):
				var mat := mi.get_surface_override_material(si) as StandardMaterial3D
				if mat == null or _saved_emission.has(mat):
					continue
				_saved_emission[mat] = [mat.emission_enabled, mat.emission, mat.emission_energy_multiplier]
				mat.emission_enabled = true
				mat.emission = Color(1, 0.2, 0.15)
				mat.emission_energy_multiplier = 2.0
	else:
		for mat in _saved_emission:
			if is_instance_valid(mat):
				var saved: Array = _saved_emission[mat]
				mat.emission_enabled = saved[0]
				mat.emission = saved[1]
				mat.emission_energy_multiplier = saved[2]
		_saved_emission.clear()

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
		var gold_amount := randi_range(gold_min, gold_max)
		player.add_gold(gold_amount)
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), "+%d G" % gold_amount, Color(1.0, 0.75, 0.2))
	_spawn_drops()
	died.emit(self)
	# Death: squash flat, then sink.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(body, "scale", Vector3(1.4, 0.1, 1.4), 0.4)
	tw.tween_property(self, "position:y", position.y - 1.2, 1.2).set_delay(0.5)
	tw.chain().tween_callback(queue_free)

## Frost Bolt chill: slows movement for a duration.
func apply_slow(duration: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)

## Scale this foe's stats to the hero's level (relative to its own base).
func scale_to_level(player_level: int) -> void:
	if _base_stats.is_empty():
		_base_stats = {"hp": max_hp, "dmg": attack_damage, "xp": xp_reward,
			"gmin": gold_min, "gmax": gold_max, "speed": chase_speed}
	var t := float(maxi(0, player_level - 1))
	max_hp = float(_base_stats["hp"]) * (1.0 + 0.2 * t)
	hp = max_hp
	attack_damage = float(_base_stats["dmg"]) * (1.0 + 0.11 * t)
	xp_reward = int(round(float(_base_stats["xp"]) * (1.0 + 0.16 * t)))
	gold_min = int(_base_stats["gmin"]) + int(2 * t)
	gold_max = int(_base_stats["gmax"]) + int(3 * t)
	chase_speed = minf(float(_base_stats["speed"]) + 1.0, float(_base_stats["speed"]) + 0.05 * t)

## Nearest living thing worth hitting: the hero, or a companion that is
## still on their feet. Enemies fight the whole party, not just the player.
func _nearest_victim() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and not bool(player.get("dead")):
		best = player
		best_d = Vector2(player.global_position.x - global_position.x,
			player.global_position.z - global_position.z).length()
	for c in get_tree().get_nodes_in_group("companions"):
		var comp := c as Node3D
		if comp == null or bool(comp.get("knocked_out")):
			continue
		var d := Vector2(comp.global_position.x - global_position.x,
			comp.global_position.z - global_position.z).length()
		if d < best_d:
			best = comp
			best_d = d
	return best

