extends CharacterBody3D
## Classic JRPG-style movement for 2.5D RPG.
## Camera is angled like old-school Final Fantasy; movement is on the XZ plane.
## Supports keyboard (WASD/arrows) and the on-screen virtual joystick.

@export var speed: float = 5.0
@export var accel: float = 12.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

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
		_update_facing(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta)

	# Simple gravity for 2.5D grounding.
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

func _update_facing(dir: Vector3) -> void:
	# Face movement direction like classic 2.5D JRPGs (Y rotation only).
	if dir.length() > 0.1:
		var target_angle := atan2(dir.x, dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, 0.2)
