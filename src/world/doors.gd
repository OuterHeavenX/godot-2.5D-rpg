extends Node3D
## Door interaction system: Area3D triggers in front of buildings that
## teleport the player to interior rooms and back, plus the two ends of
## the well shaft — down into the Sunken Vault, and back up again.
## Shows an "ENTER" prompt when the player is near; the interact action
## (E / Enter / gamepad A) or the button confirms.
## Door positions and footprints come from VillageLayout (Emberfell) and
## Grimholt, so the door table can never drift from the buildings.

# building model file name -> [interior room name, label]
const INTERIORS := {
	"market.gltf": ["market", "Market"],
	"tavern.gltf": ["tavern", "Tavern"],
	"blacksmith.gltf": ["blacksmith", "Blacksmith"],
	"house_a.gltf": ["house_a", "House"],
	"house_b.gltf": ["house_a", "House"],
}
# Grimholt reuses the models; its rooms are the "grimholt_" set in interiors.gd
# (there is no northern forge, so a blacksmith model up there would be a house).
const GRIMHOLT_ROOMS := {
	"market": "grimholt_market",
	"tavern": "grimholt_tavern",
	"house_a": "grimholt_house",
	"blacksmith": "grimholt_house",
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
var _exit_spot := Vector3.ZERO   # where the player stood on entering (the doorway)
var _exit_armed := false          # true once the player has stepped away from it
var _near_portal: Dictionary = {} # the well shaft, when the player is at one end
var _portals: Array[Area3D] = []

func _ready() -> void:
	add_to_group("doors")
	_player = get_tree().get_first_node_in_group("player")
	_interiors = get_tree().current_scene.get_node("Interiors")
	_build_doors()
	_build_portals()
	_build_prompt()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_update_portals()
	var px: float = _player.global_position.x
	if _in_interior:
		# Walking back into the doorway leaves the building, no button needed
		# (arm it first so the entry teleport itself doesn't bounce you out).
		var d := Vector2(_player.global_position.x - _exit_spot.x,
			_player.global_position.z - _exit_spot.z).length()
		if not _exit_armed:
			if d > 2.0:
				_exit_armed = true
		elif d < 0.8:
			exit_interior()
			return
		# Safety: if something moved the player outside (respawn, a load,
		# a teleport) while we still think they're inside, resync.
		if px < 400.0:
			_in_interior = false
			_current_interior = ""
			_hide_prompt()
			_prompt_button.text = _button_text("ENTER")
	elif px > 400.0:
		# Inside a room without the door state (an old save, a bad load):
		# put the player back at the well rather than leave them trapped.
		_player.global_position = Vector3(0, 0.1, 0)
		PartyMan.teleport_with(Vector3(0, 0.1, 0))
		_snap_camera()

func _build_doors() -> void:
	for spec in VillageLayout.BUILDINGS:
		_build_door(spec, Vector3.ZERO, false, VillageLayout.BUILDING_SCALE)
	for spec in Grimholt.BUILDINGS:
		_build_door(spec, Grimholt.CENTER, true, Grimholt.BUILDING_SCALE)

func _build_door(spec: Array, origin: Vector3, northern: bool, scale_f: float) -> void:
	var path: String = str(spec[0])
	var file := path.get_file()
	if not INTERIORS.has(file):
		return
	var bpos: Vector3 = origin + spec[1]
	var footprint: Vector2 = spec[2] * scale_f
	var interior: String = INTERIORS[file][0]
	if northern:
		interior = GRIMHOLT_ROOMS[interior]
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

## The well shaft. Unlike a door it does not lead to an interior: the
## vault is a region of the world like any other, so this is a plain
## teleport at each end.
func _build_portals() -> void:
	_build_portal(VillageLayout.WELL_POS + Vector3(0, 0, 2.2),
		"Climb down into the well?", SunkenVault.ENTRY, Regions.DEEP)
	_build_portal(SunkenVault.ENTRY + Vector3(0, 0, -3.2),
		"Climb back up to Emberfell?",
		VillageLayout.WELL_POS + Vector3(0, 0.1, 3.6), "")

func _build_portal(at: Vector3, label: String, target: Vector3, needs: String) -> void:
	var area := Area3D.new()
	area.position = at + Vector3(0, 1.0, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 2.5, 3.4)
	col.shape = shape
	area.add_child(col)
	area.set_meta("label", label)
	area.set_meta("target", target)
	area.set_meta("needs", needs)
	add_child(area)
	_portals.append(area)

## Polled rather than driven by body_entered: the well can be uncapped
## while the hero is standing on it, and they should not have to step off
## and back on to be offered the way down.
func _update_portals() -> void:
	var found := {}
	if not _in_interior and _near_door.is_empty() and _player != null:
		for area in _portals:
			var needs := String(area.get_meta("needs", ""))
			if needs != "" and not QuestMan.region_unlocked(needs):
				continue  # Still capped: the gate script explains why.
			if not area.overlaps_body(_player):
				continue
			found = {
				"label": String(area.get_meta("label")),
				"target": area.get_meta("target"),
			}
			break
	if found.is_empty():
		if not _near_portal.is_empty():
			_near_portal = {}
			_prompt_button.text = _button_text("ENTER")
			_hide_prompt()
		return
	if _near_portal.is_empty() or String(_near_portal["label"]) != String(found["label"]):
		_near_portal = found
		_show_prompt(String(found["label"]))
		_prompt_button.text = _button_text("CLIMB")

## Down the shaft, or back up it. The party comes along.
func _use_portal() -> void:
	var target: Vector3 = _near_portal["target"]
	_near_portal = {}
	_hide_prompt()
	_prompt_button.text = _button_text("ENTER")
	AudioMan.play("click")
	_player.global_position = target
	PartyMan.teleport_with(target + Vector3(1.2, 0.0, 0.0))
	_snap_camera()
	# Wake the far end before the hero lands in it: a sleeping region has
	# no floor to stand on.
	var regions := get_tree().get_first_node_in_group("region_runtime")
	if regions != null and regions.has_method("sync_now"):
		regions.sync_now()

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
	# Open conversations and shops take priority over doors. A mere TALK
	# prompt does too when outside; inside a building it does not, so E
	# always gets you out (the TALK button stays tappable).
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue != null:
		if dialogue.is_dialogue_open():
			return
		if not _in_interior and dialogue.wants_interact():
			return
	var shop := get_tree().get_first_node_in_group("shop_ui")
	if shop != null:
		if shop.is_shop_open():
			return
		if not _in_interior and shop.wants_interact():
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
	elif not _near_portal.is_empty():
		_use_portal()
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
	# Teleport player (and party) to the room entrance.
	var entry: Vector3 = room["exit_pos"]
	_player.global_position = entry + Vector3(0, 0.1, 0)
	_exit_spot = entry
	_exit_armed = false
	# Party lands just inside the door, never behind the south wall.
	PartyMan.teleport_with(entry + Vector3(0, 0.1, -1.5))
	# Don't touch player rotation — the model's rig faces movement direction
	# on its own; rotating the body makes it walk backwards.
	_snap_camera()
	# Show exit prompt (reusing the same UI).
	var return_word := "town" if interior_name.begins_with("grimholt_") else "village"
	_show_prompt("Exit to %s? (or walk back through the door)" % return_word)
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
	PartyMan.teleport_with(_return_pos)
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
