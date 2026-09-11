extends CharacterBody3D
## Classic JRPG-style movement for 2.5D RPG.
## Camera is angled like old-school Final Fantasy; movement is on the XZ plane.
## Supports keyboard (WASD/arrows) and the on-screen virtual joystick.
## The player is a real 3D animated character (KayKit "Adventurers" Hooded
## Rogue, CC0) with Idle and Walking animation clips.

@export var speed: float = 5.0
@export var accel: float = 12.0
@export var turn_speed: float = 12.0

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_ATTACK := "1H_Melee_Attack_Stab"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"

const MAX_HP := 100.0
const ATTACK_RANGE := 2.4
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 0.45
const REGEN_DELAY := 5.0
const REGEN_RATE := 4.0

signal hp_changed(hp: float, max_hp: float)
signal died

var hp := MAX_HP
var dead := false

const HOOD_SHADER := preload("res://src/player/hood_two_tone.gdshader")
const CAPE_SHADER := preload("res://src/player/cape_two_tone.gdshader")
const ROGUE_TEXTURE := preload("res://src/player/rogue_hooded_rogue_texture.png")

# Weapon/prop meshes that ship with the KayKit rig; we keep only the dagger.
const HIDDEN_PROPS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var _attack_cd := 0.0
var _attack_timer := 0.0
var _hit_timer := 0.0
var _since_damage := 99.0

@onready var rig: Node3D = $HeroRig
@onready var anim: AnimationPlayer = $HeroRig/AnimationPlayer

func _ready() -> void:
	add_to_group("player")
	for prop_name in HIDDEN_PROPS:
		var prop := rig.find_child(prop_name) as MeshInstance3D
		if prop != null:
			prop.visible = false
	_apply_two_tone()
	anim.play(ANIM_IDLE)

## Black-outside / red-inside materials for the hood and the cape.
func _apply_two_tone() -> void:
	var head := rig.find_child("Rogue_Head_Hooded") as MeshInstance3D
	if head != null:
		var hood_mat := ShaderMaterial.new()
		hood_mat.shader = HOOD_SHADER
		hood_mat.set_shader_parameter("albedo_tex", ROGUE_TEXTURE)
		head.set_surface_override_material(0, hood_mat)
	var cape := rig.find_child("Rogue_Cape") as MeshInstance3D
	if cape != null:
		var cape_mat := ShaderMaterial.new()
		cape_mat.shader = CAPE_SHADER
		cape.set_surface_override_material(0, cape_mat)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_since_damage += delta

	# Slowly recover health when out of danger.
	if _since_damage > REGEN_DELAY and hp < MAX_HP:
		hp = minf(MAX_HP, hp + REGEN_RATE * delta)
		hp_changed.emit(hp, MAX_HP)

	# Attack on Space or the touch attack button.
	if Input.is_action_just_pressed("attack"):
		try_attack()

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	# Add virtual joystick input (touch controls) when present.
	var joystick := get_tree().get_first_node_in_group("virtual_joystick")
	if joystick != null:
		input_dir += joystick.output
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Camera is angled, but movement stays world-aligned like classic FF:
	# Up = north (-Z), Down = south (+Z), Left/Right = X.
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)

	# Attacking roots the player briefly for a punchy feel.
	var attacking := _attack_timer > 0.0
	if attacking:
		direction = Vector3.ZERO

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
		# Smoothly turn the 3D model to face the movement direction.
		var target_yaw := atan2(direction.x, direction.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
		if not attacking and _hit_timer <= 0.0:
			_play(ANIM_WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta)
		if not attacking and _hit_timer <= 0.0:
			_play(ANIM_IDLE)

	# Simple gravity for 2.5D grounding.
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

## Dagger stab. Hits skeletons in front of the player.
func try_attack() -> void:
	if dead or _attack_cd > 0.0 or _hit_timer > 0.0:
		return
	_attack_cd = ATTACK_COOLDOWN
	_attack_timer = 0.32
	_play(ANIM_ATTACK)
	# Damage lands mid-swing.
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(_deal_attack_hit)

func _deal_attack_hit() -> void:
	if dead:
		return
	var facing := Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	for node in get_tree().get_nodes_in_group("skeletons"):
		var skel := node as Node3D
		if skel == null or (skel as Skeleton).dead:
			continue
		var to: Vector3 = skel.global_position - global_position
		to.y = 0.0
		if to.length() > ATTACK_RANGE:
			continue
		# Must be roughly in front.
		if to.normalized().dot(facing) < 0.3:
			continue
		(skel as Skeleton).take_damage(ATTACK_DAMAGE, global_position)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead:
		return
	hp -= amount
	_since_damage = 0.0
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		_die()
	else:
		_hit_timer = 0.35
		_play(ANIM_HIT)
		# Small knockback away from the attacker.
		var away: Vector3 = global_position - from_pos
		away.y = 0.0
		if away.length() > 0.01:
			velocity = away.normalized() * 6.0

func _die() -> void:
	dead = true
	hp = 0.0
	velocity = Vector3.ZERO
	_play(ANIM_DEATH)
	died.emit()
	# Respawn at the village center after a beat.
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(_respawn)

func _respawn() -> void:
	global_position = Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO
	hp = MAX_HP
	dead = false
	_since_damage = 99.0
	hp_changed.emit(hp, MAX_HP)
	_play(ANIM_IDLE)

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		anim.play(clip)
