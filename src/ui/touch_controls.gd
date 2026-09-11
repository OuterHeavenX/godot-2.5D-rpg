extends CanvasLayer
## On-screen touch controls layer.
## Visible when a touchscreen is available (mobile browsers), or appears
## automatically on the first touch event. Hidden on desktop.

var _attack_btn: Button
var _atb_ready := true

func _ready() -> void:
	layer = 10
	visible = DisplayServer.is_touchscreen_available()
	_build_attack_button()
	_build_dodge_button()
	# Track ATB so the attack button shows when it's ready.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("atb_changed"):
		player.atb_changed.connect(_on_atb_changed)

func _build_attack_button() -> void:
	_attack_btn = Button.new()
	_attack_btn.text = "⚔️"
	_attack_btn.add_theme_font_size_override("font_size", 44)
	# Big button, bottom-right.
	_attack_btn.anchor_left = 1.0
	_attack_btn.anchor_top = 1.0
	_attack_btn.anchor_right = 1.0
	_attack_btn.anchor_bottom = 1.0
	_attack_btn.offset_left = -152
	_attack_btn.offset_top = -152
	_attack_btn.offset_right = -48
	_attack_btn.offset_bottom = -48
	_attack_btn.pressed.connect(_on_attack_pressed)
	add_child(_attack_btn)

func _build_dodge_button() -> void:
	var btn := Button.new()
	btn.text = "💨"
	btn.add_theme_font_size_override("font_size", 36)
	# Smaller button, left of the attack button.
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -248
	btn.offset_top = -132
	btn.offset_right = -164
	btn.offset_bottom = -48
	btn.pressed.connect(_on_dodge_pressed)
	add_child(btn)

func _on_atb_changed(atb: float) -> void:
	_atb_ready = atb >= 1.0
	# Dim the attack button while the ATB gauge is filling.
	_attack_btn.modulate = Color(1, 1, 1, 1) if _atb_ready else Color(1, 1, 1, 0.45)

func _on_attack_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("try_attack"):
		player.try_attack()

func _on_dodge_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("try_dodge"):
		player.try_dodge()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not visible:
		visible = true
