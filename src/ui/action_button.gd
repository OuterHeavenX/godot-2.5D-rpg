class_name ActionButton
extends Control
## Stylized circular touch button with a vector-drawn icon.
## No emoji, no external assets — everything is drawn in _draw().
## icon: "sword" (attack), "roll" (dodge), "fast" (sprint).

signal triggered

@export var icon: String = "sword"
@export var ring_color: Color = Color(0.35, 0.9, 1.0)
@export var icon_color: Color = Color(0.92, 0.96, 1.0)

var ready_dim := false   # dimmed while ATB is filling (attack button)
var active_glow := false # bright toggle state (sprint button)

var _pressed := false
var _press_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_press_time = 0.12
			triggered.emit()
			queue_redraw()
			accept_event()
		else:
			_pressed = false
			queue_redraw()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_time = 0.12
			triggered.emit()
			queue_redraw()
			accept_event()
		else:
			_pressed = false
			queue_redraw()
			accept_event()

func _process(delta: float) -> void:
	if _press_time > 0.0:
		_press_time -= delta
		if _press_time <= 0.0:
			_pressed = false
			queue_redraw()

func set_ready_dim(dim: bool) -> void:
	ready_dim = dim
	queue_redraw()

func set_active_glow(on: bool) -> void:
	active_glow = on
	queue_redraw()

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var scale_f := 0.92 if _pressed else 1.0
	r *= scale_f

	# Soft outer glow when active.
	if active_glow:
		draw_circle(c, r + 10.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.22))
		draw_circle(c, r + 5.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.30))

	# Button body: dark glass disc.
	draw_circle(c, r, Color(0.06, 0.09, 0.14, 0.88))
	draw_circle(c, r * 0.82, Color(0.10, 0.15, 0.22, 0.55))

	# Ring.
	var ring_w := 4.0 if active_glow else 3.0
	var ring_c := ring_color
	if ready_dim:
		ring_c = ring_c.darkened(0.45)
	draw_arc(c, r - 2.0, 0.0, TAU, 48, ring_c, ring_w, true)

	# Icon.
	var ic := icon_color
	if ready_dim:
		ic = ic.darkened(0.5)
	var s := r * 0.52  # icon half-size
	match icon:
		"sword":
			_draw_sword(c, s, ic)
		"roll":
			_draw_roll(c, s, ic)
		"fast":
			_draw_fast(c, s, ic)
		"menu":
			_draw_menu(c, s, ic)
		"spark":
			_draw_spark(c, s, ic)

## Diagonal sword: blade, guard, grip, pommel.
func _draw_sword(c: Vector2, s: float, col: Color) -> void:
	var dir := Vector2(0.7, -0.7).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := c + dir * s
	var base := c - dir * s * 0.25
	var guard_c := c - dir * s * 0.45
	# Blade (tapered).
	draw_colored_polygon([
		tip,
		base + perp * s * 0.16,
		base - perp * s * 0.16,
	], col)
	# Guard.
	var gw := s * 0.42
	draw_line(guard_c + perp * gw, guard_c - perp * gw, col, s * 0.16, true)
	# Grip.
	var grip_end := c - dir * s * 0.85
	draw_line(guard_c, grip_end, col.darkened(0.15), s * 0.14, true)
	# Pommel.
	draw_circle(grip_end, s * 0.11, col)

## Circular arrow: dodge roll.
func _draw_roll(c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.18
	# Almost-full circle with a gap at top-right.
	draw_arc(c, s * 0.72, deg_to_rad(50.0), deg_to_rad(360.0), 32, col, w, true)
	# Arrowhead at the gap.
	var a0 := deg_to_rad(50.0)
	var tip := c + Vector2(cos(a0), sin(a0)) * s * 0.72
	var tangent := Vector2(-sin(a0), cos(a0))
	var back := tip - tangent * s * 0.42
	var p1 := back + tangent.rotated(deg_to_rad(150.0)) * s * 0.30
	var p2 := back + tangent.rotated(deg_to_rad(-150.0)) * s * 0.30
	draw_colored_polygon([tip, p1, p2], col)

## Double chevron: sprint / fast.
func _draw_fast(c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.22
	var offsets: Array[float] = [-s * 0.38, s * 0.12]
	for off: float in offsets:
		var cx: float = c.x + off
		var pts := PackedVector2Array([
			Vector2(cx - s * 0.18, c.y - s * 0.52),
			Vector2(cx + s * 0.30, c.y),
			Vector2(cx - s * 0.18, c.y + s * 0.52),
		])
		draw_polyline(pts, col, w, true)

## Hamburger: menu.
func _draw_menu(c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.20
	for i in 3:
		var y := c.y + (float(i) - 1.0) * s * 0.42
		draw_line(Vector2(c.x - s * 0.5, y), Vector2(c.x + s * 0.5, y), col, w, true)

## Four-pointed magic spark.
func _draw_spark(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := PI / 4.0 * float(i) - PI / 2.0
		var r := s if i % 2 == 0 else s * 0.32
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, col)
