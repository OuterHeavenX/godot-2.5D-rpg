extends CanvasLayer
## On-screen touch controls layer.
## Visible when a touchscreen is available (mobile browsers), or appears
## automatically on the first touch event. Hidden on desktop.

func _ready() -> void:
	layer = 10
	visible = DisplayServer.is_touchscreen_available()
	_build_attack_button()

func _build_attack_button() -> void:
	var btn := Button.new()
	btn.text = "⚔️"
	btn.add_theme_font_size_override("font_size", 44)
	# Big circular-ish button, bottom-right.
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -152
	btn.offset_top = -152
	btn.offset_right = -48
	btn.offset_bottom = -48
	btn.pressed.connect(_on_attack_pressed)
	add_child(btn)

func _on_attack_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("try_attack"):
		player.try_attack()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not visible:
		visible = true
