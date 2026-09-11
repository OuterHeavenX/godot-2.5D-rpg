extends Control
## Virtual joystick for touch controls.
## Works with touch (InputEventScreenTouch/Drag) and mouse (for testing).
## Read the current input via `output` (Vector2 in [-1, 1] range).

@export var base_radius: float = 110.0
@export var knob_radius: float = 48.0
@export var base_color: Color = Color(1, 1, 1, 0.22)
@export var ring_color: Color = Color(1, 1, 1, 0.45)
@export var knob_color: Color = Color(1, 1, 1, 0.55)

var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _mouse_active: bool = false
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("virtual_joystick")
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and not _mouse_active:
			_touch_index = event.index
			_update_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_knob(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _touch_index == -1 and not _mouse_active:
				_mouse_active = true
				_update_knob(event.position)
			elif not event.pressed and _mouse_active:
				_release()
	elif event is InputEventMouseMotion:
		if _mouse_active:
			_update_knob(event.position)

func _update_knob(local_pos: Vector2) -> void:
	var center := size * 0.5
	var delta := local_pos - center
	if delta.length() > base_radius:
		delta = delta.normalized() * base_radius
	_knob_offset = delta
	output = delta / base_radius
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_mouse_active = false
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, base_radius, base_color)
	draw_arc(center, base_radius, 0.0, TAU, 64, ring_color, 4.0)
	draw_circle(center + _knob_offset, knob_radius, knob_color)
