extends Node3D
## Door interaction system: Area3D triggers in front of buildings that
## teleport the player to interior rooms and back.
## Shows an "ENTER" prompt when the player is near.

const DOORS := [
	# [building_pos, footprint (scaled), interior_name, label]
	[Vector3(9, 0, -9), Vector2(9.0, 6.6), "market", "Market"],
	[Vector3(-11, 0, -7), Vector2(5.85, 6.65), "tavern", "Tavern"],
	[Vector3(-15, 0, 7), Vector2(4.0, 4.3), "house_a", "House"],
	[Vector3(-7, 0, 17), Vector2(4.35, 5.5), "house_a", "House"],
	[Vector3(13, 0, 15), Vector2(4.0, 4.3), "house_a", "House"],
	[Vector3(17, 0, 3), Vector2(6.45, 6.25), "blacksmith", "Blacksmith"],
]

var _player: Node3D
var _interiors: Node3D
var _prompt: Control
var _prompt_label: Label
var _prompt_button: Button
var _near_door: Dictionary = {}  # Door data when player is near
var _return_pos := Vector3.ZERO  # Where to return when exiting
var _in_interior := false
var _current_interior := ""

func _ready() -> void:
	add_to_group("doors")
	_player = get_tree().get_first_node_in_group("player")
	_interiors = get_tree().current_scene.get_node("Interiors")
	_build_doors()
	_build_prompt()
	set_process(true)

func _build_doors() -> void:
	for door in DOORS:
		var bpos: Vector3 = door[0]
		var footprint: Vector2 = door[1]
		var interior: String = door[2]
		# Door trigger on the south (+Z) face, 1m out from the wall.
		var trigger_pos := bpos + Vector3(0, 1.0, footprint.y / 2 + 1.0)
		var area := Area3D.new()
		area.position = trigger_pos
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.0, 2.0, 2.0)
		col.shape = shape
		area.add_child(col)
		# Store door data on the area.
		area.set_meta("interior", interior)
		area.set_meta("label", door[3])
		area.set_meta("return_pos", trigger_pos + Vector3(0, 0, 1.5))
		area.body_entered.connect(_on_door_enter.bind(area))
		area.body_exited.connect(_on_door_exit.bind(area))
		add_child(area)

func _build_prompt() -> void:
	_prompt = Control.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -120
	_prompt.offset_bottom = -20
	_prompt.visible = false
	# Dim background.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.add_child(bg)
	# Label.
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 28)
	_prompt_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt_label.offset_bottom = -50
	_prompt.add_child(_prompt_label)
	# Enter button.
	_prompt_button = Button.new()
	_prompt_button.text = "ENTER"
	_prompt_button.custom_minimum_size = Vector2(200, 60)
	_prompt_button.add_theme_font_size_override("font_size", 32)
	_prompt_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_button.offset_left = -100
	_prompt_button.offset_right = 100
	_prompt_button.offset_top = -70
	_prompt_button.offset_bottom = -10
	_prompt_button.pressed.connect(_on_enter_pressed)
	_prompt.add_child(_prompt_button)
	# Add to HUD canvas layer (deferred to avoid setup race).
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call_deferred("add_child", _prompt)
	else:
		get_tree().current_scene.call_deferred("add_child", _prompt)

func _on_door_enter(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if _in_interior:
		return
	_near_door = {
		"interior": area.get_meta("interior"),
		"label": area.get_meta("label"),
		"return_pos": area.get_meta("return_pos"),
	}
	_show_prompt("Enter the %s?" % _near_door["label"])

func _on_door_exit(body: Node3D, _area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	# Don't clear the exit prompt — body_exited fires after teleporting
	# into the room, which would hide the "EXIT" button and trap the player.
	if _in_interior:
		return
	_near_door = {}
	_hide_prompt()

func _show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt.visible = true

func _hide_prompt() -> void:
	_prompt.visible = false

func _on_enter_pressed() -> void:
	if _in_interior:
		exit_interior()
	elif not _near_door.is_empty():
		_enter_interior(_near_door["interior"], _near_door["return_pos"])

func _enter_interior(interior_name: String, return_pos: Vector3) -> void:
	var room: Dictionary = _interiors.get_room(interior_name)
	if room.is_empty():
		return
	_return_pos = return_pos
	_current_interior = interior_name
	_in_interior = true
	_hide_prompt()
	_near_door = {}
	# Teleport player to room entrance.
	var entry: Vector3 = room["exit_pos"]
	_player.global_position = entry + Vector3(0, 0.1, 0)
	# Don't touch player rotation — the model's rig faces movement direction
	# on its own; rotating the body makes it walk backwards.
	_snap_camera()
	# Show exit prompt (reusing the same UI).
	_show_prompt("Exit to village?")
	_prompt_button.text = "EXIT"

func exit_interior() -> void:
	if not _in_interior:
		return
	_in_interior = false
	_current_interior = ""
	_hide_prompt()
	_prompt_button.text = "ENTER"
	_player.global_position = _return_pos
	_snap_camera()

func _snap_camera() -> void:
	# Snap the follow camera to the player instantly so it doesn't
	# lerp across the void between the village and the interiors.
	var rig := get_tree().current_scene.get_node_or_null("CameraRig")
	if rig != null:
		var offset: Vector3 = rig.get("camera_offset")
		rig.global_position = _player.global_position + offset

func _process(_delta: float) -> void:
	# If in interior and player walks back through the door, exit.
	# (The exit is handled by the EXIT button for now.)
	pass

func is_in_interior() -> bool:
	return _in_interior

func get_current_interior() -> String:
	return _current_interior
