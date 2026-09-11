extends CanvasLayer
## On-screen touch controls layer.
## Visible when a touchscreen is available (mobile browsers), or appears
## automatically on the first touch event. Hidden on desktop.
## Uses stylized vector-drawn ActionButtons (no emoji — web fonts lack them).

var _attack_btn: ActionButton
var _sprint_btn: ActionButton

func _ready() -> void:
	layer = 10
	visible = DisplayServer.is_touchscreen_available()
	_build_buttons()
	# Track ATB and sprint state.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_signal("atb_changed"):
			player.atb_changed.connect(_on_atb_changed)
		if player.has_signal("sprint_changed"):
			player.sprint_changed.connect(_on_sprint_changed)

func _make_button(icon: String, ring: Color, rect: Rect2) -> ActionButton:
	var btn := ActionButton.new()
	btn.icon = icon
	btn.ring_color = ring
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = rect.position.x
	btn.offset_top = rect.position.y
	btn.offset_right = rect.end.x
	btn.offset_bottom = rect.end.y
	add_child(btn)
	return btn

func _build_buttons() -> void:
	# Attack: big, bottom-right. Orange-red ring.
	_attack_btn = _make_button("sword", Color(1.0, 0.45, 0.2),
		Rect2(-156, -156, 108, 108))
	_attack_btn.triggered.connect(_on_attack_pressed)
	# Dodge: left of attack. Violet ring.
	var dodge_btn := _make_button("roll", Color(0.7, 0.5, 1.0),
		Rect2(-256, -136, 88, 88))
	dodge_btn.triggered.connect(_on_dodge_pressed)
	# Sprint: above dodge. Cyan ring, glows when active.
	_sprint_btn = _make_button("fast", Color(0.35, 0.9, 1.0),
		Rect2(-256, -236, 88, 88))
	_sprint_btn.triggered.connect(_on_sprint_pressed)

func _on_atb_changed(atb: float) -> void:
	# Dim the attack button while the ATB gauge is filling.
	_attack_btn.set_ready_dim(atb < 1.0)

func _on_sprint_changed(sprinting: bool) -> void:
	_sprint_btn.set_active_glow(sprinting)

func _on_attack_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("try_attack"):
		player.try_attack()

func _on_dodge_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("try_dodge"):
		player.try_dodge()

func _on_sprint_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("toggle_sprint"):
		player.toggle_sprint()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not visible:
		visible = true
