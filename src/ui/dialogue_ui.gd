extends CanvasLayer
## Simple dialogue UI: shows NPC name and dialogue text with a NEXT/CLOSE button.

var _panel: Control
var _name_label: Label
var _text_label: Label
var _next_btn: Button
var _talk_btn: Button
var _talk_panel: Control
var _pending_name := ""
var _pending_lines: Array = []
var _lines: Array = []
var _idx := 0

func _ready() -> void:
	add_to_group("dialogue_ui")
	layer = 11
	_build()
	visible = true

func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -200
	_panel.offset_bottom = -20
	_panel.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.10, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)
	# Border.
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_width = 3.0
	border.border_color = Color(0.75, 0.65, 0.45)
	_panel.add_child(border)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_left = 24
	_name_label.offset_top = 12
	_name_label.offset_right = -24
	_name_label.offset_bottom = 48
	_panel.add_child(_name_label)
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.offset_left = 24
	_text_label.offset_top = 52
	_text_label.offset_right = -24
	_text_label.offset_bottom = -60
	_panel.add_child(_text_label)
	_next_btn = Button.new()
	_next_btn.text = "NEXT"
	_next_btn.custom_minimum_size = Vector2(140, 44)
	_next_btn.add_theme_font_size_override("font_size", 24)
	_next_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_btn.offset_left = -164
	_next_btn.offset_top = -56
	_next_btn.offset_right = -24
	_next_btn.offset_bottom = -12
	_next_btn.pressed.connect(_on_next)
	_panel.add_child(_next_btn)
	add_child(_panel)
	_build_talk_button()

## Small TALK button shown on proximity (does NOT pause the game).
## Tapping it opens the full dialogue.
func _build_talk_button() -> void:
	_talk_panel = Control.new()
	_talk_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_talk_panel.offset_top = -180
	_talk_panel.offset_bottom = -120
	_talk_panel.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_panel.add_child(bg)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -40
	label.name = "TalkLabel"
	_talk_panel.add_child(label)
	_talk_btn = Button.new()
	_talk_btn.text = "TALK"
	_talk_btn.custom_minimum_size = Vector2(160, 50)
	_talk_btn.add_theme_font_size_override("font_size", 28)
	_talk_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_talk_btn.offset_left = -80
	_talk_btn.offset_right = 80
	_talk_btn.offset_top = -55
	_talk_btn.offset_bottom = -5
	_talk_btn.pressed.connect(_on_talk_pressed)
	_talk_panel.add_child(_talk_btn)
	add_child(_talk_panel)

func show_talk_button(npc_name: String, lines: Array) -> void:
	_pending_name = npc_name
	_pending_lines = lines
	var label := _talk_panel.get_node("TalkLabel") as Label
	label.text = "%s wants to talk" % npc_name
	_talk_panel.visible = true

func hide_talk_button() -> void:
	_talk_panel.visible = false
	_pending_name = ""
	_pending_lines = []

func _on_talk_pressed() -> void:
	_talk_panel.visible = false
	if _pending_name != "":
		show_dialogue(_pending_name, _pending_lines)

func show_dialogue(npc_name: String, lines: Array) -> void:
	_name_label.text = npc_name
	_lines = lines
	_idx = 0
	_update_text()
	_panel.visible = true
	get_tree().paused = true

func hide_dialogue() -> void:
	_panel.visible = false
	get_tree().paused = false

func _update_text() -> void:
	if _idx < _lines.size():
		_text_label.text = _lines[_idx]
		_next_btn.text = "CLOSE" if _idx == _lines.size() - 1 else "NEXT"

func _on_next() -> void:
	_idx += 1
	if _idx >= _lines.size():
		hide_dialogue()
	else:
		_update_text()
