extends Node3D
## Door interaction system: Area3D triggers in front of buildings that
## teleport the player to interior rooms and back.
## Shows an "ENTER" prompt when the player is near; the interact action
## (E / Enter / gamepad A) or the button confirms.
## Door positions and footprints come from VillageLayout so the two never
## drift apart.

# building model file name -> [interior room name, label]
const INTERIORS := {
	"market.gltf": ["market", "Market"],
	"tavern.gltf": ["tavern", "Tavern"],
	"blacksmith.gltf": ["blacksmith", "Blacksmith"],
	"house_a.gltf": ["house_a", "House"],
	"house_b.gltf": ["house_a", "House"],
}

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

func _build_doors() -> void:
	for spec in VillageLayout.BUILDINGS:
		var path: String = str(spec[0])
		var file := path.get_file()
		if not INTERIORS.has(file):
			continue
		var bpos: Vector3 = spec[1]
		var footprint: Vector2 = spec[2] * VillageLayout.BUILDING_SCALE
		var interior: String = INTERIORS[file][0]
		var label: String = INTERIORS[file][1]
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
		area.set_meta("label", label)
		area.set_meta("return_pos", trigger_pos + Vector3(0, 0, 1.5))
		area.body_entered.connect(_on_door_enter.bind(area))
		area.body_exited.connect(_on_door_exit.bind(area))
		add_child(area)

func _build_prompt() -> void:
	# Own canvas layer: above the vignette (5), below dialogue/shop (10+).
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
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
	_prompt_button.text = _button_text("ENTER")
	_prompt_button.custom_minimum_size = Vector2(200, 60)
	_prompt_button.add_theme_font_size_override("font_size", 32)
	_prompt_button.focus_mode = Control.FOCUS_NONE
	_prompt_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_button.offset_left = -100
	_prompt_button.offset_right = 100
	_prompt_button.offset_top = -70
	_prompt_button.offset_bottom = -10
	_prompt_button.pressed.connect(_on_enter_pressed)
	_prompt.add_child(_prompt_button)
	layer.add_child(_prompt)

func _button_text(verb: String) -> String:
	if DisplayServer.is_touchscreen_available():
		return verb
	return "%s  (E)" % verb

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _prompt.visible:
		return
	# Conversations and shops take priority over doors.
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue != null and dialogue.has_method("wants_interact") and dialogue.wants_interact():
		return
	var shop := get_tree().get_first_node_in_group("shop_ui")
	if shop != null and shop.has_method("wants_interact") and shop.wants_interact():
		return
	_on_enter_pressed()
	get_viewport().set_input_as_handled()

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
	AudioMan.play("click")
	# Teleport player to room entrance.
	var entry: Vector3 = room["exit_pos"]
	_player.global_position = entry + Vector3(0, 0.1, 0)
	# Don't touch player rotation — the model's rig faces movement direction
	# on its own; rotating the body makes it walk backwards.
	_snap_camera()
	# Show exit prompt (reusing the same UI).
	_show_prompt("Exit to village?")
	_prompt_button.text = _button_text("EXIT")

func exit_interior() -> void:
	if not _in_interior:
		return
	_in_interior = false
	_current_interior = ""
	_hide_prompt()
	_prompt_button.text = _button_text("ENTER")
	AudioMan.play("click")
	_player.global_position = _return_pos
	_snap_camera()

func _snap_camera() -> void:
	# Snap the follow camera to the player instantly so it doesn't
	# lerp across the void between the village and the interiors.
	var rig := get_tree().current_scene.get_node_or_null("CameraRig")
	if rig != null:
		var offset: Vector3 = rig.get("camera_offset")
		rig.global_position = _player.global_position + offset

func is_in_interior() -> bool:
	return _in_interior

func get_current_interior() -> String:
	return _current_interior

## Where the player would stand outside if they left the building now.
## Used by the save system so a save never lands inside a room.
func get_return_pos() -> Vector3:
	return _return_pos
