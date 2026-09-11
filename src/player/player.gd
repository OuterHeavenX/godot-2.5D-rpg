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

# Weapon/prop meshes that ship with the KayKit rig; we keep only the dagger.
const HIDDEN_PROPS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

@onready var rig: Node3D = $HeroRig
@onready var anim: AnimationPlayer = $HeroRig/AnimationPlayer

func _ready() -> void:
	for prop_name in HIDDEN_PROPS:
		var prop := rig.find_child(prop_name) as MeshInstance3D
		if prop != null:
			prop.visible = false
	anim.play(ANIM_IDLE)

func _physics_process(delta: float) -> void:
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

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, accel * delta)
		# Smoothly turn the 3D model to face the movement direction.
		var target_yaw := atan2(direction.x, direction.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, target_yaw, minf(1.0, turn_speed * delta))
		_play(ANIM_WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta)
		_play(ANIM_IDLE)

	# Simple gravity for 2.5D grounding.
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

func _play(clip: StringName) -> void:
	if anim.current_animation != clip:
		anim.play(clip)
