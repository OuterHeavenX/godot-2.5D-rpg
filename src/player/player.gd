extends CharacterBody3D
## Classic JRPG-style movement for 2.5D RPG, with ATB combat.
## Camera is angled like old-school Final Fantasy; movement is on the XZ plane.
## Supports keyboard (WASD/arrows) and the on-screen virtual joystick.
## The player is a real 3D animated character (KayKit "Adventurers" Hooded
## Rogue, CC0).
##
## ATB: the gauge fills in real time (~1.4s). Attacks and dodges spend it.
## Skeletons telegraph their swings, so a well-timed dodge avoids damage.

@export var speed: float = 5.0
@export var accel: float = 12.0
@export var turn_speed: float = 12.0

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_ATTACK := "1H_Melee_Attack_Slice_Horizontal"
const ANIM_DODGE := "Dodge_Forward"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"

const MAX_HP := 100.0
const ATTACK_RANGE := 2.6
const ATTACK_DAMAGE := 14.0
const ATB_FILL_TIME := 1.4
const DODGE_IFRAMES := 0.4
const DODGE_DISTANCE := 3.5
const DODGE_TIME := 0.28
const REGEN_DELAY := 5.0
const REGEN_RATE := 4.0

signal hp_changed(hp: float, max_hp: float)
signal atb_changed(atb: float)
signal died

var hp := MAX_HP
var atb := 1.0
var dead := false

const HOOD_SHADER := preload("res://src/player/hood_two_tone.gdshader")
const CAPE_SHADER := preload("res://src/player/cape_two_tone.gdshader")
const ROGUE_TEXTURE := preload("res://src/player/rogue_hooded_rogue_texture.png")

# Weapon/prop meshes that ship with the KayKit rig; we keep only the dagger.
const HIDDEN_PROPS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var _attack_timer := 0.0
var _attack_dir := Vector3.ZERO
var _hit_timer := 0.0
var _dodge_timer := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _iframes := 0.0
var _since_damage := 99.0
var _slash: MeshInstance3D

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
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_since_damage += delta

	# ATB gauge fills in real time; full bar = ready to act.
	if atb < 1.0 and _attack_timer <= 0.0 and _dodge_timer <= 0.0:
		atb = minf(1.0, atb + delta / ATB_FILL_TIME)
		atb_changed.emit(atb)

	# Slowly recover health when out of danger.
	if _since_damage > REGEN_DELAY and hp < MAX_HP:
		hp = minf(MAX_HP, hp + REGEN_RATE * delta)
		hp_changed.emit(hp, MAX_HP)

	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("dodge"):
		try_dodge()

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
	var busy := _attack_timer > 0.0 or _dodge_timer > 0.0 or _hit_timer > 0.0

	if _dodge_timer > 0.0:
		# Dodge dash: committed movement in the dodge direction.
		var t := 1.0 - _dodge_timer / DODGE_TIME
		var dash_speed := DODGE_DISTANCE / DODGE_TIME * (1.0 - t * 0.5)
		velocity.x = _dodge_dir.x * dash_speed
		velocity.z = _dodge_dir.z * dash_speed
	elif _attack_timer > 0.0:
		# Attack lunge: drive forward through the swing.
		velocity.x = _attack_dir.x * 7.0
		velocity.z = _attack_dir.z * 7.0
	elif direction != Vector3.ZERO and not busy:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
		# Smoothly turn the 3D model to face the movement direction.
		var target_yaw := atan2(direction.x, direction.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
		_play(ANIM_WALK)
	else:
		if not busy:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta)
			velocity.z = move_toward(velocity.z, 0.0, accel * delta)
			_play(ANIM_IDLE)

	# Simple gravity for 2.5D grounding.
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

## ATB attack: needs a full gauge. Heavy horizontal slash with a lunge,
## a white slash arc, and a hit-stop kick on connect.
func try_attack() -> void:
	if dead or atb < 1.0 or _attack_timer > 0.0 or _dodge_timer > 0.0 or _hit_timer > 0.0:
		return
	atb = 0.0
	atb_changed.emit(atb)
	_attack_timer = 0.38
	_attack_dir = Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	_play(ANIM_ATTACK)
	_spawn_slash()
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_callback(_deal_attack_hit)

func _deal_attack_hit() -> void:
	if dead:
		return
	var facing := Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	var hit_any := false
	for node in get_tree().get_nodes_in_group("skeletons"):
		var skel := node as Skeleton
		if skel == null or skel.dead:
			continue
		var to: Vector3 = skel.global_position - global_position
		to.y = 0.0
		if to.length() > ATTACK_RANGE:
			continue
		if to.normalized().dot(facing) < 0.2:
			continue
		skel.take_damage(ATTACK_DAMAGE, global_position)
		hit_any = true
	if hit_any:
		_hit_stop()

## Brief freeze on connect — the classic fighting-game impact feel.
func _hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.06, true, false, true).timeout
	Engine.time_scale = 1.0

## White crescent slash arc that sweeps and fades.
func _spawn_slash() -> void:
	if _slash != null and is_instance_valid(_slash):
		_slash.queue_free()
	_slash = MeshInstance3D.new()
	_slash.mesh = _build_slash_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash.material_override = mat
	add_child(_slash)
	_slash.position = Vector3(0, 1.1, 0)
	_slash.rotation.y = rig.rotation.y - PI * 0.35
	var tw := _slash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_slash, "rotation:y", _slash.rotation.y + PI * 0.7, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(_slash.queue_free)

## A flat 100-degree crescent fan, 1.6m radius.
static func _build_slash_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var steps := 10
	var radius := 1.6
	var inner := 0.7
	var arc := deg_to_rad(100.0)
	for i in range(steps + 1):
		var a := -arc * 0.5 + arc * float(i) / float(steps)
		var dir := Vector3(sin(a), 0, cos(a))
		verts.append(dir * inner)
		verts.append(dir * radius)
		if i < steps:
			var b := i * 2
			indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## ATB dodge: quick dash with i-frames. Direction of movement, else facing.
func try_dodge() -> void:
	if dead or _dodge_cd > 0.0 or _dodge_timer > 0.0 or _attack_timer > 0.0 or _hit_timer > 0.0:
		return
	if atb < 1.0:
		return
	atb = 0.0
	atb_changed.emit(atb)
	_dodge_cd = 0.9
	_dodge_timer = DODGE_TIME
	_iframes = DODGE_IFRAMES
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	var joystick := get_tree().get_first_node_in_group("virtual_joystick")
	if joystick != null:
		input_dir += joystick.output
	if input_dir.length() > 0.2:
		_dodge_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		_dodge_dir = Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	rig.rotation.y = atan2(_dodge_dir.x, _dodge_dir.z)
	_play(ANIM_DODGE)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead or _iframes > 0.0:
		return
	hp -= amount
	_since_damage = 0.0
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		_die()
	else:
		_hit_timer = 0.35
		_play(ANIM_HIT)
		var away: Vector3 = global_position - from_pos
		away.y = 0.0
		if away.length() > 0.01:
			velocity = away.normalized() * 6.0

func _die() -> void:
	dead = true
	hp = 0.0
	atb = 0.0
	velocity = Vector3.ZERO
	_play(ANIM_DEATH)
	died.emit()
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(_respawn)

func _respawn() -> void:
	global_position = Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO
	hp = MAX_HP
	atb = 1.0
	dead = false
	_since_damage = 99.0
	hp_changed.emit(hp, MAX_HP)
	atb_changed.emit(atb)
	_play(ANIM_IDLE)

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		anim.play(clip)
