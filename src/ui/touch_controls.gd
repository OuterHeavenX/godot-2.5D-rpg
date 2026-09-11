extends CanvasLayer
## On-screen touch controls layer.
## Visible when a touchscreen is available (mobile browsers), or appears
## automatically on the first touch event. Hidden on desktop.

func _ready() -> void:
	layer = 10
	visible = DisplayServer.is_touchscreen_available()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not visible:
		visible = true
