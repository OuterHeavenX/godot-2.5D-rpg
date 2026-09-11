extends CanvasLayer
## Character progression menu: level, XP, and lifetime stats.
## Toggle with C / ESC, the floating menu button, or by tapping the dim.
## Pauses the game while open. Built in code for a cohesive look.

const GOLD := Color(0.95, 0.78, 0.38)
const GOLD_DIM := Color(0.72, 0.62, 0.42)
const INK := Color(0.93, 0.94, 1.0)

var _panel_root: Control
var _menu_btn: ActionButton
var _open := false
var _stat_values := {}
var _xp_fill: ColorRect
var _xp_label: Label
var _level_big: Label

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_button()
	_build_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if not _open:
		# Don't open over the title screen.
		var mm := get_tree().get_first_node_in_group("main_menu")
		if mm != null and mm.has_method("is_open") and mm.is_open():
			return
	_open = not _open
	AudioMan.play("click")
	if _open:
		_refresh()
		_panel_root.visible = true
		get_tree().paused = true
		# Gentle entrance: fade + rise.
		_panel_root.modulate.a = 0.0
		var panel := _panel_root.get_node("Center/Panel")
		panel.scale = Vector2(0.94, 0.94)
		panel.pivot_offset = panel.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel_root, "modulate:a", 1.0, 0.22)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.28)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		get_tree().paused = false
		_panel_root.visible = false

func _build_button() -> void:
	_menu_btn = ActionButton.new()
	_menu_btn.icon = "menu"
	_menu_btn.ring_color = GOLD
	_menu_btn.anchor_left = 1.0
	_menu_btn.anchor_top = 0.0
	_menu_btn.anchor_right = 1.0
	_menu_btn.anchor_bottom = 0.0
	_menu_btn.offset_left = -68
	_menu_btn.offset_top = 12
	_menu_btn.offset_right = -12
	_menu_btn.offset_bottom = 68
	_menu_btn.triggered.connect(toggle)
	add_child(_menu_btn)

func _build_panel() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.visible = false
	add_child(_panel_root)

	# Dim; tapping it closes the menu.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			toggle()
		elif event is InputEventScreenTouch and event.pressed:
			toggle())
	_panel_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.97)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_corner_radius_all(18)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 26
	style.shadow_color = Color(0.95, 0.78, 0.38, 0.18)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title.
	var title := _label("CHARACTER", 40, GOLD)
	vbox.add_child(title)
	var sub := _label("Hooded Rogue", 22, GOLD_DIM)
	vbox.add_child(sub)
	vbox.add_child(_divider())

	# Level + XP.
	_level_big = _label("Lv 1", 56, INK)
	_level_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_level_big)

	# XP bar: wrapped so the fill overlays the background.
	var xp_wrap := Control.new()
	xp_wrap.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(xp_wrap)
	var xp_bg := ColorRect.new()
	xp_bg.color = Color(0.10, 0.06, 0.18, 0.9)
	xp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_wrap.add_child(xp_bg)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.65, 0.4, 1.0)
	_xp_fill.anchor_right = 0.0
	_xp_fill.anchor_bottom = 1.0
	xp_wrap.add_child(_xp_fill)
	_xp_label = _label("", 18, GOLD_DIM)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_xp_label)
	vbox.add_child(_divider())

	# Stat rows.
	for key in ["HEALTH", "ATTACK", "KILLS", "DEATHS", "TIME"]:
		vbox.add_child(_stat_row(key))

	vbox.add_child(_divider())
	var hint := _label("C / ESC or tap outside to close", 16, Color(1, 1, 1, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func _label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.22)
	d.custom_minimum_size = Vector2(0, 2)
	return d

func _stat_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_lbl := Label.new()
	name_lbl.text = key
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", GOLD_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.name = "Value"
	val_lbl.text = "—"
	val_lbl.add_theme_font_size_override("font_size", 24)
	val_lbl.add_theme_color_override("font_color", INK)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)
	_stat_values[key] = val_lbl
	return row

func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var lvl: int = player.get("level")
	var xp: int = player.get("xp")
	var xp_next: int = player.xp_for_next()
	var hp: float = player.get("hp")
	var max_hp: float = player.get("max_hp")
	var atk: float = player.get("attack_damage")
	var deaths: int = player.get("deaths")
	var play_time: float = player.get("play_time")
	_level_big.text = "Lv %d" % lvl
	var frac := clampf(float(xp) / float(maxi(xp_next, 1)), 0.0, 1.0)
	_xp_fill.anchor_right = frac
	_xp_label.text = "%d / %d XP" % [xp, xp_next]
	_stat_values["HEALTH"].text = "%d / %d" % [int(hp), int(max_hp)]
	_stat_values["ATTACK"].text = "%d" % int(atk)
	var mgr := get_tree().get_first_node_in_group("skeleton_manager")
	var kills := int(mgr.get("kills")) if mgr != null else 0
	_stat_values["KILLS"].text = "%d" % kills
	_stat_values["DEATHS"].text = "%d" % deaths
	_stat_values["TIME"].text = _fmt_time(play_time)

func _fmt_time(s: float) -> String:
	var total := int(s)
	var h := total / 3600
	var m := (total % 3600) / 60
	var sec := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]
