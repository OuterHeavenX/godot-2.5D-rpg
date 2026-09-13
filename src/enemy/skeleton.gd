class_name Skeleton
extends CharacterBody3D
## KayKit Skeleton Warrior enemy. Wanders the wilderness, chases the player
## on sight, attacks in melee, and collapses when slain.

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
var gold_min := 5
var gold_max := 15
# How far past attack_range a swing still connects (the swing has reach).
var hit_reach := 1.25
# Sound played when this foe notices the party ("" for silent).
var voice := "bone_hit"
var voice_pitch := 0.7
# Drop table: [item_id, chance, min, max]. See ItemDB.
var drops := [["potion", 0.40, 1, 1], ["bone_shard", 0.55, 1, 2]]

var anim_idle := "Idle"
var anim_walk := "Walking_A"
var anim_attack := "1H_Melee_Attack_Slice_Horizontal"
var anim_hit := "Hit_A"
var anim_death := "Death_C_Skeletons"
var anim_windup := "Idle_Combat"

# Bounds this skeleton roams (the manager leaves the default wilderness).
var roam_min := Vector2(-27, 34)
var roam_max := Vector2(27, 66)
# A round arena instead of a box: set a radius and the foe is kept inside
# that circle, so it can follow its prey to any edge of a disc.
var roam_center := Vector2.ZERO
var roam_radius := 0.0
# Towns are safe: enemies are pushed out of this circle (manager sets it).
var safe_center := Vector3.ZERO
var safe_radius := 0.0

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
# Foes far from the party think a few times a second instead of sixty:
# the world is big enough now that the difference matters in a browser.
var _far := false
var _far_check := 0.0
var _far_accum := 0.0
var _player_cache: Node3D

@onready var rig: Node3D = $SkeletonRig
@onready var anim: AnimationPlayer = $SkeletonRig/AnimationPlayer
@onready var body_cs: CollisionShape3D = $BodyCollision

func _ready() -> void:
	_rng.randomize()
	_pick_wander_target()
	add_to_group("skeletons")
	hp = max_hp
	anim.play(anim_idle)
	# Red "!" warning that flashes during the attack wind-up (enemy ATB).
	_warn_label = Label3D.new()
	_warn_label.text = "!"
	_warn_label.font_size = 96
	_warn_label.modulate = Color(1, 0.15, 0.1)
	_warn_label.outline_size = 12
	_warn_label.position = Vector3(0, 2.3, 0)
	_warn_label.visible = false
	add_child(_warn_label)

## How far from the party a foe has to be before it starts thinking in
## slow motion, and how long a slow tick is.
const FAR_RANGE := 55.0
const FAR_TICK := 0.4

## True while this foe is far enough away to run on the cheap clock.
## Rechecked a couple of times a second.
func _is_far(delta: float) -> bool:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var p := _player()
		if p == null:
			_far = true
		else:
			var dx := p.global_position.x - global_position.x
			var dz := p.global_position.z - global_position.z
			_far = dx * dx + dz * dz > FAR_RANGE * FAR_RANGE
	return _far

func _player() -> Node3D:
	if _player_cache != null and is_instance_valid(_player_cache):
		return _player_cache
	_player_cache = get_tree().get_first_node_in_group("player") as Node3D
	return _player_cache

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _is_far(delta):
		# Nobody can see it: fold several frames into one cheap tick.
		_far_accum += delta
		if _far_accum < FAR_TICK:
			return
		delta = _far_accum
		_far_accum = 0.0
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_slow_timer = maxf(0.0, _slow_timer - delta)

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
				_on_aggro()
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
				_play(anim_walk)
		"windup":
			# Enemy ATB: telegraphed wind-up. Dodge now!
			_face(to_player, delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			_play(anim_windup)
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
				_play(anim_attack)
				var tw := create_tween()
				tw.tween_interval(0.35)
				tw.tween_callback(_deal_hit.bind(player))
		"attack":
			_face(to_player, delta)
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			# Recover when the swing is done, then re-engage.
			if anim.current_animation != anim_attack:
				_play(anim_idle)
			if _attack_cd <= 0.0:
				_state = "chase"

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_clamp_to_roam()
	if safe_radius > 0.0:
		# Towns are safe: shove back out of the protected circle.
		var flat := Vector2(global_position.x - safe_center.x,
			global_position.z - safe_center.z)
		if flat.length() < safe_radius:
			var out := flat.normalized() if flat.length() > 0.01 else Vector2(1, 0)
			global_position.x = safe_center.x + out.x * safe_radius
			global_position.z = safe_center.z + out.y * safe_radius
	if avoid_lake:
		# The black water bars the wild dead (see IslandLake).
		global_position = IslandLake.keep_out_of_water(global_position)


## Roll this foe's drop table and scatter the results on the ground.
## Entries: [item_id, chance, min, max]. Potions use the potion pickup.
## Keep the foe inside its ground: a circle when one is set, the box
## otherwise.
func _clamp_to_roam() -> void:
	if roam_radius > 0.0:
		var from_centre := Vector2(global_position.x - roam_center.x,
			global_position.z - roam_center.y)
		if from_centre.length() > roam_radius:
			var edge := from_centre.normalized() * roam_radius
			global_position.x = roam_center.x + edge.x
			global_position.z = roam_center.y + edge.y
		return
	global_position.x = clampf(global_position.x, roam_min.x, roam_max.x)
	global_position.z = clampf(global_position.z, roam_min.y, roam_max.y)

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

## The foe has spotted the party: a voice line, if it has one.
func _on_aggro() -> void:
	if voice != "":
		AudioMan.play(voice, voice_pitch, -6.0)

func _wander(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_play(anim_idle)
		return
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 1.0:
		_idle_timer = _rng.randf_range(1.0, 3.5)
		return
	_move_toward(to.normalized(), walk_speed, delta)
	_play(anim_walk)

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
	if to.length() < attack_range * hit_reach and player.has_method("take_damage"):
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
		_play(anim_hit)

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	body_cs.set_deferred("disabled", true)
	_play(anim_death)
	AudioMan.play("bone_die", 0.8, -2.0)
	# Award XP and gold to the player.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_reward)
		if player.has_method("on_foe_slain"):
			player.on_foe_slain()
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 1.5, 0), "+%d XP" % xp_reward, Color(1.0, 0.85, 0.3))
	if player != null and player.has_method("add_gold"):
		var gold_amount := randi_range(gold_min, gold_max)
		player.add_gold(gold_amount)
		HitEffects.damage_number(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), "+%d G" % gold_amount, Color(1.0, 0.75, 0.2))
	_spawn_drops()
	died.emit(self)
	# Sink into the ground, then free.
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "position:y", position.y - 1.2, 0.8)
	tw.tween_callback(queue_free)

var _base_stats := {}

## Scale this foe's stats to the hero's level so the wilds keep up with
## the player instead of turning into free XP. Relative to the foe's own
## base values, so husks and bandits keep their character.
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
	var player := _player()
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

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		if anim.has_animation(clip):
			anim.play(clip)
		elif anim.has_animation(anim_idle):
			anim.play(anim_idle)

## Recolor the whole rig by multiplying every material's albedo. Used by
## the breeds that share a KayKit model but not its colours.
func _tint_rig(tint: Color) -> void:
	for mi in _collect_meshes(rig):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var mat: Material = mi.get_surface_override_material(si)
			if mat == null:
				mat = mesh.surface_get_material(si)
			if mat is StandardMaterial3D:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = dup.albedo_color * tint
				mi.set_surface_override_material(si, dup)

func _collect_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_collect_meshes(ch))
	return out

## Everyone the foe could reasonably hit: the hero plus any companion
## still on their feet. Used by the attacks that sweep an area.
func _victims() -> Array:
	var out: Array = []
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not bool(player.get("dead")):
		out.append(player)
	for c in get_tree().get_nodes_in_group("companions"):
		if not bool(c.get("knocked_out")):
			out.append(c)
	return out
