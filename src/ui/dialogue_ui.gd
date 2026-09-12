extends CanvasLayer
## Simple dialogue UI: shows NPC name and dialogue text with a NEXT/CLOSE button.

var _panel: Control
var _name_label: Label
var _text_label: Label
var _next_btn: Button
var _next_indicator: Label
var _talk_btn: Button
var _talk_panel: Control
var _pending_name := ""
var _pending_lines: Array = []
var _pending_offer := ""
var _pending_turnin := ""
var _lines: Array = []
var _offer_id := ""
var _turnin_id := ""
var _accept_btn: Button
var _decline_btn: Button
var _complete_btn: Button
var _idx := 0
var _full_text := ""
var _char_timer := 0.0
var _bounce_time := 0.0
const CHARS_PER_SEC := 45.0

func _ready() -> void:
	add_to_group("dialogue_ui")
	layer = 11
	# Must process while paused, or the NEXT button freezes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = true

func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -230
	_panel.offset_bottom = -20
	_panel.visible = false
	# Main box: deep blue-black with subtle vertical gradient feel.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)
	# Outer gold border (thick).
	var outer := ReferenceRect.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.border_width = 4.0
	outer.border_color = Color(0.85, 0.70, 0.35)
	_panel.add_child(outer)
	# Inner thin border (inset).
	var inner := ReferenceRect.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_top = 8
	inner.offset_right = -8
	inner.offset_bottom = -8
	inner.border_width = 1.5
	inner.border_color = Color(0.85, 0.70, 0.35, 0.5)
	_panel.add_child(inner)
	# Corner diamonds.
	for cx in [0.0, 1.0]:
		for cy in [0.0, 1.0]:
			var diamond := ColorRect.new()
			diamond.color = Color(0.85, 0.70, 0.35)
			diamond.custom_minimum_size = Vector2(12, 12)
			diamond.size = Vector2(12, 12)
			diamond.rotation = PI / 4
			diamond.set_anchors_preset(Control.PRESET_TOP_LEFT)
			# Position at corners (anchor trick: use offsets).
			diamond.anchor_left = cx
			diamond.anchor_right = cx
			diamond.anchor_top = cy
			diamond.anchor_bottom = cy
			diamond.offset_left = -6
			diamond.offset_top = -6
			diamond.offset_right = 6
			diamond.offset_bottom = 6
			_panel.add_child(diamond)
	# Name plate: overlaps the top edge, classic JRPG style.
	var plate := ColorRect.new()
	plate.color = Color(0.10, 0.12, 0.22, 0.98)
	plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	plate.offset_left = 32
	plate.offset_top = -22
	plate.offset_right = 332
	plate.offset_bottom = 22
	_panel.add_child(plate)
	var plate_border := ReferenceRect.new()
	plate_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate_border.border_width = 2.5
	plate_border.border_color = Color(0.85, 0.70, 0.35)
	plate.add_child(plate_border)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.add_child(_name_label)
	# Dialogue text (typewriter).
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 26)
	_text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.offset_left = 32
	_text_label.offset_top = 40
	_text_label.offset_right = -32
	_text_label.offset_bottom = -70
	_panel.add_child(_text_label)
	# Bouncing "next" indicator.
	_next_indicator = Label.new()
	_next_indicator.text = "▼"
	_next_indicator.add_theme_font_size_override("font_size", 32)
	_next_indicator.add_theme_color_override("font_color", Color(0.85, 0.70, 0.35))
	_next_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_indicator.offset_left = -60
	_next_indicator.offset_top = -60
	_next_indicator.offset_right = -20
	_next_indicator.offset_bottom = -20
	_panel.add_child(_next_indicator)
	_next_btn = Button.new()
	_next_btn.text = "NEXT"
	_next_btn.custom_minimum_size = Vector2(140, 44)
	_next_btn.add_theme_font_size_override("font_size", 24)
	_next_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_btn.offset_left = -180
	_next_btn.offset_top = -58
	_next_btn.offset_right = -40
	_next_btn.offset_bottom = -14
	_next_btn.pressed.connect(_on_next)
	_panel.add_child(_next_btn)
	# Quest buttons: ACCEPT/DECLINE on offer last lines, COMPLETE on turn-ins.
	_accept_btn = _quest_button("ACCEPT", Color(0.45, 0.85, 0.5))
	_accept_btn.offset_left = -360
	_accept_btn.offset_right = -200
	_accept_btn.pressed.connect(_on_quest_accept)
	_panel.add_child(_accept_btn)
	_decline_btn = _quest_button("DECLINE", Color(0.9, 0.55, 0.5))
	_decline_btn.offset_left = -180
	_decline_btn.offset_right = -40
	_decline_btn.pressed.connect(_on_quest_decline)
	_panel.add_child(_decline_btn)
	_complete_btn = _quest_button("COMPLETE", Color(1.0, 0.85, 0.35))
	_complete_btn.offset_left = -180
	_complete_btn.offset_right = -40
	_complete_btn.pressed.connect(_on_quest_complete)
	_panel.add_child(_complete_btn)
	add_child(_panel)
	_build_talk_button()

func _quest_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.visible = false
	b.custom_minimum_size = Vector2(140, 44)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", color)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_top = -58
	b.offset_bottom = -14
	return b

## Small TALK button shown on proximity (does NOT pause the game).
## Tapping it opens the full dialogue.
func _build_talk_button() -> void:
	_talk_panel = Control.new()
	_talk_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_talk_panel.offset_top = -240
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
	label.offset_top = 8
	label.offset_bottom = -62
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

func show_talk_button(npc_name: String, lines: Array, offer := "", turnin := "") -> void:
	_pending_name = npc_name
	_pending_lines = lines
	_pending_offer = offer
	_pending_turnin = turnin
	var label := _talk_panel.get_node("TalkLabel") as Label
	label.text = "%s wants to talk" % npc_name
	_talk_panel.visible = true

func hide_talk_button() -> void:
	_talk_panel.visible = false
	_pending_name = ""
	_pending_lines = []
	_pending_offer = ""
	_pending_turnin = ""

func _on_talk_pressed() -> void:
	_talk_panel.visible = false
	if _pending_name != "":
		show_dialogue(_pending_name, _pending_lines, _pending_offer, _pending_turnin)

func show_dialogue(npc_name: String, lines: Array, offer := "", turnin := "") -> void:
	_name_label.text = npc_name
	_lines = lines
	_offer_id = offer
	_turnin_id = turnin
	_idx = 0
	_update_text()
	_panel.visible = true
	_update_pause()

func hide_dialogue() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	_hide_quest_buttons()
	_update_pause()
	QuestMan.on_dialogue_closed(_name_label.text)

func _hide_quest_buttons() -> void:
	_accept_btn.visible = false
	_decline_btn.visible = false
	_complete_btn.visible = false
	_next_btn.visible = true

func _on_quest_accept() -> void:
	if _offer_id != "":
		QuestMan.accept_quest(_offer_id)
	_offer_id = ""
	_turnin_id = ""
	hide_dialogue()

func _on_quest_decline() -> void:
	_offer_id = ""
	_turnin_id = ""
	hide_dialogue()

func _on_quest_complete() -> void:
	if _turnin_id != "":
		QuestMan.turn_in_quest(_turnin_id)
	_offer_id = ""
	_turnin_id = ""
	hide_dialogue()

## Returns true if the dialogue panel is currently open.
func is_dialogue_open() -> bool:
	return _panel.visible

## Update the pause state: paused if dialogue, shop, or menu is open.
func _update_pause() -> void:
	var paused := _panel.visible
	var shop := get_tree().get_first_node_in_group("shop_ui")
	if shop != null and shop.has_method("is_shop_open") and shop.is_shop_open():
		paused = true
	var menu := get_tree().get_first_node_in_group("char_menu")
	if menu != null and menu.has_method("is_menu_open") and menu.is_menu_open():
		paused = true
	get_tree().paused = paused

func _update_text() -> void:
	if _idx < _lines.size():
		_full_text = _lines[_idx]
		_text_label.text = ""
		_char_timer = 0.0
		var is_last := _idx == _lines.size() - 1
		_next_btn.text = "CLOSE" if is_last else "NEXT"
		_next_indicator.visible = false
		# Quest buttons replace NEXT/CLOSE on the last line of offers/turn-ins.
		var show_offer := is_last and _offer_id != ""
		var show_turnin := is_last and _turnin_id != ""
		_accept_btn.visible = show_offer
		_decline_btn.visible = show_offer
		_complete_btn.visible = show_turnin
		_next_btn.visible = not show_offer and not show_turnin

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	# Typewriter: reveal characters over time.
	if _text_label.text.length() < _full_text.length():
		_char_timer += delta
		var count := int(_char_timer * CHARS_PER_SEC)
		_text_label.text = _full_text.left(count)
		if _text_label.text.length() >= _full_text.length():
			_next_indicator.visible = true
	else:
		# Bounce the next indicator.
		_bounce_time += delta
		_next_indicator.position.y = _next_indicator.position.y + sin(_bounce_time * 6.0) * 0.5

func _on_next() -> void:
	# First tap completes the typewriter; second tap advances.
	if _text_label.text.length() < _full_text.length():
		_text_label.text = _full_text
		_next_indicator.visible = true
		return
	_idx += 1
	if _idx >= _lines.size():
		hide_dialogue()
	else:
		_update_text()
	AudioMan.play("click")
