extends Node3D
## Classic Final Fantasy-style camera rig
## Low-angle 2.5D view inspired by old-school FF7/FF9 field screens.
## The 25-degree pitch is half the original 50-degree look-down angle.

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var camera_offset: Vector3 = Vector3(0, 4.663, 10)

var target: Node3D

func _ready() -> void:
	if target_path != NodePath(""):
		target = get_node(target_path) as Node3D
	# Low 2.5D angle: looking down 25 degrees.
	# Camera3D child should have rotation_degrees = (-25, 0, 0).

func _process(delta: float) -> void:
	if target:
		var desired := target.global_position + camera_offset
		# Keep Y from target's offset only, smooth XZ follow
		global_position.x = lerp(global_position.x, desired.x, follow_speed * delta)
		global_position.z = lerp(global_position.z, desired.z, follow_speed * delta)
		global_position.y = desired.y
