extends CharacterBody3D
## Classic JRPG-style movement for 2.5D RPG.
## Camera is angled like old-school Final Fantasy; movement is on the XZ plane.
## Supports keyboard (WASD/arrows) and the on-screen virtual joystick.
## The player is a billboarded pixel-art sprite with a 3-frame walk cycle.

@export var speed: float = 5.0
@export var accel: float = 12.0
@export var anim_fps: float = 6.0

@onready var sprite: Sprite3D = $Sprite3D

const WALK_CYCLE := [0, 1, 0, 2]
var _anim_time := 0.0
var _cycle_index := 0

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
		_update_facing(input_dir)
		_animate_walk(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta)
		_reset_pose()

	# Simple gravity for 2.5D grounding.
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

func _update_facing(input_dir: Vector2) -> void:
	# Flip the billboarded sprite for left/right movement.
	if input_dir.x < -0.1:
		sprite.flip_h = true
	elif input_dir.x > 0.1:
		sprite.flip_h = false

func _animate_walk(delta: float) -> void:
	_anim_time += delta
	if _anim_time >= 1.0 / anim_fps:
		_anim_time = 0.0
		_cycle_index = (_cycle_index + 1) % WALK_CYCLE.size()
		sprite.frame = WALK_CYCLE[_cycle_index]

func _reset_pose() -> void:
	sprite.frame = 0
	_cycle_index = 0
	_anim_time = 0.0
