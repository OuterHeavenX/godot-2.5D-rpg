class_name Companion
extends CharacterBody3D
## A recruited party companion. Follows the player in formation,
## auto-attacks nearby enemies, and can be knocked out (revives after combat).

var companion_id := ""
var info := {}
var hp := 70.0
var max_hp := 70.0
var damage := 12.0
var knocked_out := false

var _role := "melee"
var _move_speed := 4.0
var _attack_range := 2.2
var _attack_cd := 0.0
var _heal_cd := 0.0
var _ko_timer := 0.0
var _target: Node3D = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _nameplate: Label3D = null

func setup(cid: String, data: Dictionary) -> void:
	companion_id = cid
	info = data
	_role = String(data.get("role", "melee"))
	max_hp = float(data.get("hp", 70.0))
	hp = max_hp
	damage = float(data.get("damage", 12.0))
	_move_speed = float(data.get("move_speed", 4.0))
	_attack_range = float(data.get("attack_range", 2.2))

func _ready() -> void:
	add_to_group("companions")
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	_build_model()
	_build_nameplate()

func _build_model() -> void:
	var path := "res://src/npc/%s.glb" % String(info.get("kaykit", "Rogue"))
	var packed: PackedScene = load(path)
	if packed == null:
		return
	_model = packed.instantiate() as Node3D
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("Idle")

func _build_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.text = String(info.get("name", "Ally"))
	_nameplate.font_size = 32
	_nameplate.pixel_size = 0.004
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = true
	_nameplate.modulate = Color(0.6, 1.0, 0.7)
	_nameplate.outline_size = 8
	_nameplate.outline_modulate = Color(0, 0, 0, 0.9)
	_nameplate.position = Vector3(0, 2.2, 0)
	add_child(_nameplate)

# KayKit Adventurers clip names, in order of preference.
const WALK_CLIPS := ["Walking_A", "Walk"]
const MELEE_CLIPS := ["1H_Melee_Attack_Slice_Horizontal", "2H_Melee_Attack_Chop", "Attack"]
const CAST_CLIPS := ["Spellcast_Shoot", "Spellcasting", "1H_Melee_Attack_Slice_Horizontal"]
const CATCH_UP_DISTANCE := 16.0

var _stuck_timer := 0.0
var _flash_timer := 0.0

func _play(clip: StringName) -> void:
	if _anim != null and _anim.has_animation(clip):
		if _anim.current_animation != clip:
			_anim.play(clip)

## Play the first clip the rig actually has.
func _play_first(clips: Array) -> void:
	if _anim == null:
		return
	for c in clips:
		if _anim.has_animation(c):
			_play(c)
			return
	_play("Idle")

func _physics_process(delta: float) -> void:
	if knocked_out:
		_ko_timer -= delta
		if _ko_timer <= 0.0:
			_revive()
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_heal_cd = maxf(0.0, _heal_cd - delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	if _nameplate != null and _flash_timer <= 0.0 and not knocked_out:
		_nameplate.modulate = Color(0.6, 1.0, 0.7)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	_update_target()
	if _target != null and is_instance_valid(_target):
		_combat(delta)
	else:
		_follow(delta)
	move_and_slide()

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _update_target() -> void:
	# Keep current target if still valid and in range.
	if _target != null and is_instance_valid(_target):
		if bool(_target.get("dead")):
			_target = null
		elif global_position.distance_to(_target.global_position) < 16.0:
			return
		else:
			_target = null
	# Find nearest living enemy.
	var best: Node3D = null
	var best_d := 13.0
	for e in get_tree().get_nodes_in_group("skeletons"):
		if e == self or not (e is Node3D):
			continue
		if bool(e.get("dead")):
			continue
		var d := global_position.distance_to((e as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = e
	_target = best

func _formation_offset() -> Vector3:
	var player := _player()
	if player == null:
		return Vector3(-1.5, 0, 1.5)
	# Slot based on PartyMan order; trail behind the player's facing.
	var idx := 0
	if PartyMan.active.has(companion_id):
		idx = PartyMan.active.find(companion_id)
	var yaw := 0.0
	var rig := player.get_node_or_null("HeroRig")
	if rig != null:
		yaw = rig.rotation.y
	var local := Vector3(-1.4 - idx * 0.9, 0, 1.6)
	return local.rotated(Vector3.UP, yaw)

func _follow(delta: float) -> void:
	var player := _player()
	if player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")
		return
	var want: Vector3 = player.global_position + _formation_offset()
	var to: Vector3 = want - global_position
	to.y = 0.0
	# Left far behind (walls, the bridge, a gate) or wedged on a corner:
	# catch up instantly rather than pathfind.
	if to.length() > CATCH_UP_DISTANCE or _stuck_timer > 1.5:
		global_position = want + Vector3(0, 0.1, 0)
		velocity = Vector3.ZERO
		_stuck_timer = 0.0
		return
	if to.length() > 0.6:
		var dir := to.normalized()
		velocity.x = dir.x * _move_speed
		velocity.z = dir.z * _move_speed
		_model.rotation.y = atan2(dir.x, dir.z)
		_play_first(WALK_CLIPS)
		if to.length() > 3.0 and get_real_velocity().length() < 0.3:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_stuck_timer = 0.0
		_play("Idle")
	# Mira mends the hero when they're hurting.
	if _role == "ranged" and _heal_cd <= 0.0:
		var ph := float(player.get("hp"))
		var pm := float(player.get("max_hp"))
		if ph < pm * 0.5 and player.has_method("heal"):
			player.heal(pm * 0.2)
			_heal_cd = 18.0
			if _nameplate != null:
				_nameplate.modulate = Color(0.7, 1.0, 0.8)

func _anim_has(clip: StringName) -> bool:
	return _anim != null and _anim.has_animation(clip)

func _combat(delta: float) -> void:
	var to: Vector3 = _target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	_model.rotation.y = atan2(dir.x, dir.z)
	if _role == "ranged":
		# Keep at mid range, strafe, and hurl frost bolts.
		if dist > _attack_range:
			velocity.x = dir.x * _move_speed
			velocity.z = dir.z * _move_speed
			_play_first(WALK_CLIPS)
		elif dist < _attack_range * 0.5:
			velocity.x = -dir.x * _move_speed * 0.7
			velocity.z = -dir.z * _move_speed * 0.7
			_play_first(WALK_CLIPS)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_play("Idle")
		if dist < _attack_range + 3.0 and _attack_cd <= 0.0:
			_fire_bolt(dir)
			_attack_cd = 2.2
	else:
		# Melee: close in and strike.
		if dist > _attack_range:
			velocity.x = dir.x * _move_speed
			velocity.z = dir.z * _move_speed
			_play_first(WALK_CLIPS)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _attack_cd <= 0.0:
				_melee_strike()
				_attack_cd = 1.6
			elif _attack_cd < 1.0:
				_play("Idle")

func _fire_bolt(dir: Vector3) -> void:
	var proj := MagicProjectile.create("frost_bolt",
		global_position + Vector3(0, 1.4, 0), dir, damage)
	get_parent().add_child(proj)
	AudioMan.play("cast", 0.8, 1.0)
	_play_first(CAST_CLIPS)

func _melee_strike() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _target.has_method("take_damage"):
		_target.take_damage(damage, global_position)
	AudioMan.play("swing", 0.8, -2.0)
	_play_first(MELEE_CLIPS)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if knocked_out:
		return
	hp -= amount
	HitEffects.damage_number(get_tree().current_scene,
		global_position + Vector3(0, 1.8, 0), "-%d" % int(amount), Color(1.0, 0.6, 0.4))
	AudioMan.play("hit", 0.9, -6.0)
	_flash_timer = 0.25
	if _nameplate != null:
		_nameplate.modulate = Color(1.0, 0.4, 0.3)
	# Shoved back a step.
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		velocity.x = away.normalized().x * 4.0
		velocity.z = away.normalized().z * 4.0
	if hp <= 0.0:
		hp = 0.0
		knocked_out = true
		_ko_timer = 25.0
		velocity = Vector3.ZERO
		if _model != null:
			_model.rotation.z = 1.35 # toppled over
		if _nameplate != null:
			_nameplate.text = "%s (KO)" % String(info.get("name", "Ally"))
			_nameplate.modulate = Color(1.0, 0.5, 0.5)

func _revive() -> void:
	knocked_out = false
	hp = max_hp * 0.5
	if _model != null:
		_model.rotation.z = 0.0
	if _nameplate != null:
		_nameplate.text = String(info.get("name", "Ally"))
		_nameplate.modulate = Color(0.6, 1.0, 0.7)

func full_revive() -> void:
	_revive()
	hp = max_hp

func heal(amount: float) -> void:
	if knocked_out:
		return
	hp = minf(max_hp, hp + amount)
