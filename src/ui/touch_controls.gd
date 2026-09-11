extends CanvasLayer
## On-screen touch controls layer.
## Visible when a touchscreen is available (mobile browsers), or appears
## automatically on the first touch event. Hidden on desktop.

var _attack_btn: Button
var _sprint_btn: Button
var _sprint_style_off: StyleBoxFlat
var _sprint_style_on: StyleBoxFlat
var _atb_ready := true

func _ready() -> void:
	layer = 10
	visible = DisplayServer.is_touchscreen_available()
	_build_attack_button()
	_build_dodge_button()
	_build_sprint_button()
	# Track ATB so the attack button shows when it's ready.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_signal("atb_changed"):
			player.atb_changed.connect(_on_atb_changed)
		if player.has_signal("sprint_changed"):
			player.sprint_changed.connect(_on_sprint_changed)

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

## Stylized circular sprint toggle. Glows cyan while running.
func _build_sprint_button() -> void:
	_sprint_style_off = StyleBoxFlat.new()
	_sprint_style_off.bg_color = Color(0.07, 0.10, 0.16, 0.88)
	_sprint_style_off.set_border_width_all(3)
	_sprint_style_off.border_color = Color(0.25, 0.55, 0.75, 0.9)
	_sprint_style_off.set_corner_radius_all(42)
	_sprint_style_off.content_margin_left = 8
	_sprint_style_on = StyleBoxFlat.new()
	_sprint_style_on.bg_color = Color(0.10, 0.22, 0.32, 0.95)
	_sprint_style_on.set_border_width_all(4)
	_sprint_style_on.border_color = Color(0.35, 0.95, 1.0)
	_sprint_style_on.set_corner_radius_all(42)
	_sprint_style_on.shadow_color = Color(0.2, 0.8, 1.0, 0.55)
	_sprint_style_on.shadow_size = 12

	_sprint_btn = Button.new()
	_sprint_btn.text = "🏃"
	_sprint_btn.add_theme_font_size_override("font_size", 38)
	_sprint_btn.add_theme_stylebox_override("normal", _sprint_style_off)
	_sprint_btn.add_theme_stylebox_override("hover", _sprint_style_off)
	_sprint_btn.add_theme_stylebox_override("pressed", _sprint_style_on)
	_sprint_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Above the dodge button, same column.
	_sprint_btn.anchor_left = 1.0
	_sprint_btn.anchor_top = 1.0
	_sprint_btn.anchor_right = 1.0
	_sprint_btn.anchor_bottom = 1.0
	_sprint_btn.offset_left = -248
	_sprint_btn.offset_top = -228
	_sprint_btn.offset_right = -164
	_sprint_btn.offset_bottom = -144
	_sprint_btn.pressed.connect(_on_sprint_pressed)
	add_child(_sprint_btn)

func _on_sprint_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("toggle_sprint"):
		player.toggle_sprint()

func _on_sprint_changed(sprinting: bool) -> void:
	var style := _sprint_style_on if sprinting else _sprint_style_off
	_sprint_btn.add_theme_stylebox_override("normal", style)
	_sprint_btn.add_theme_stylebox_override("hover", style)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not visible:
		visible = true
