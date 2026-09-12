extends CanvasLayer
## Shop UI: buy items with gold. Supports different sellers with custom inventories.
## Shows a TALK prompt near the shopkeeper, opens the shop panel on talk.

const Equipment := preload("res://src/item/equipment.gd")

var _items := [
	{"name": "Potion", "price": 50, "desc": "Restores 50 HP"},
	{"name": "Hi-Potion", "price": 150, "desc": "Restores 150 HP"},
]
var _shop_title := "MERCHANT'S WARES"

var _talk_prompt: Control
var _shop_panel: Control
var _gold_label: Label
var _items_box: VBoxContainer
var _player: Node3D

func _ready() -> void:
	add_to_group("shop_ui")
	layer = 10
	_player = get_tree().get_first_node_in_group("player")
	_build_talk_prompt()
	_build_shop_panel()
	visible = true

func _build_talk_prompt() -> void:
	_talk_prompt = Control.new()
	_talk_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_talk_prompt.offset_top = -180
	_talk_prompt.offset_bottom = -120
	_talk_prompt.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_prompt.add_child(bg)
	var label := Label.new()
	label.text = "Merchant: \"Welcome, traveler!\""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -40
	_talk_prompt.add_child(label)
	var talk_btn := Button.new()
	talk_btn.text = "TALK"
	talk_btn.custom_minimum_size = Vector2(160, 50)
	talk_btn.add_theme_font_size_override("font_size", 28)
	talk_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	talk_btn.offset_left = -80
	talk_btn.offset_right = 80
	talk_btn.offset_top = -55
	talk_btn.offset_bottom = -5
	talk_btn.pressed.connect(_on_talk_pressed)
	_talk_prompt.add_child(talk_btn)
	add_child(_talk_prompt)

func _build_shop_panel() -> void:
	_shop_panel = Control.new()
	_shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_panel.visible = false
	# Dim background.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_panel.add_child(dim)
	# Panel.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 400)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -200
	panel.offset_bottom = 200
	_shop_panel.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	# Title.
	var title := Label.new()
	title.text = _shop_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	# Gold display.
	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_gold_label)
	# Items.
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_items_box)
	_refresh_items()
	# Close button.
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(200, 50)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)
	add_child(_shop_panel)

func _refresh_items() -> void:
	for child in _items_box.get_children():
		child.queue_free()
	_update_gold_label()
	for item in _items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		var display_name: String = item["name"]
		# Upgrade items show the equipment name.
		if item["name"] == "CapeUp" and item.has("cape_level"):
			display_name = Equipment.cape_name(item["cape_level"])
		elif item["name"] == "HoodUp" and item.has("hood_level"):
			display_name = Equipment.hood_name(item["hood_level"])
		name_label.text = "%s - %d G\n%s" % [display_name, item["price"], item["desc"]]
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var buy_btn := Button.new()
		buy_btn.text = "BUY"
		buy_btn.custom_minimum_size = Vector2(100, 50)
		buy_btn.add_theme_font_size_override("font_size", 24)
		# Disable if can't afford.
		if _player != null and _player.get("gold") < item["price"]:
			buy_btn.disabled = true
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		row.add_child(buy_btn)
		_items_box.add_child(row)

func _update_gold_label() -> void:
	if _player != null:
		_gold_label.text = "Your Gold: %d G" % _player.get("gold")

func show_talk_prompt() -> void:
	# Only show if not in shop panel and player is in market interior.
	var doors := get_tree().get_first_node_in_group("doors")
	if doors != null and doors.has_method("is_in_interior"):
		if not doors.is_in_interior() or doors.get_current_interior() != "market":
			return
	_talk_prompt.visible = true

func hide_talk_prompt() -> void:
	_talk_prompt.visible = false

func _on_talk_pressed() -> void:
	_talk_prompt.visible = false
	_shop_panel.visible = true
	_refresh_merchant_inventory()
	_refresh_items()

## Build the merchant inventory: potions + next cape/hood upgrades.
func _refresh_merchant_inventory() -> void:
	# Only for the merchant (not the innkeeper).
	if _shop_title != "MERCHANT'S WARES":
		return
	var items := [
		{"name": "Potion", "price": 50, "desc": "Restores 50 HP"},
		{"name": "Hi-Potion", "price": 150, "desc": "Restores 150 HP"},
	]
	if _player != null:
		var cape_lvl: int = _player.get("cape_level")
		var hood_lvl: int = _player.get("hood_level")
		if cape_lvl < Equipment.MAX_LEVEL:
			var next_cape := cape_lvl + 1
			items.append({
				"name": "CapeUp",
				"price": Equipment.upgrade_price(cape_lvl),
				"desc": "%s (+%d Max HP)" % [Equipment.cape_name(next_cape), int(Equipment.cape_hp_bonus(next_cape))],
				"cape_level": next_cape,
			})
		if hood_lvl < Equipment.MAX_LEVEL:
			var next_hood := hood_lvl + 1
			items.append({
				"name": "HoodUp",
				"price": Equipment.upgrade_price(hood_lvl),
				"desc": "%s (+%.1f ATK)" % [Equipment.hood_name(next_hood), Equipment.hood_attack_bonus(next_hood)],
				"hood_level": next_hood,
			})
	_items = items
	# Pause the game while shopping (like the menu does).
	get_tree().paused = true

func _on_close_pressed() -> void:
	_shop_panel.visible = false
	get_tree().paused = false

func _on_buy_pressed(item: Dictionary) -> void:
	if _player == null:
		return
	if not _player.spend_gold(item["price"]):
		return  # Can't afford (button should be disabled anyway).
	# Give the item.
	if item["name"] == "Potion":
		_player.add_potion(1)
	elif item["name"] == "Hi-Potion":
		_player.add_potion(3)
	elif item["name"] == "Ale":
		# Restore 25 HP directly.
		var new_hp = minf(_player.get("max_hp"), _player.get("hp") + 25.0)
		_player.set("hp", new_hp)
		if _player.has_signal("hp_changed"):
			_player.hp_changed.emit(new_hp, _player.get("max_hp"))
	elif item["name"] == "Rest":
		# Full heal.
		_player.set("hp", _player.get("max_hp"))
		if _player.has_signal("hp_changed"):
			_player.hp_changed.emit(_player.get("hp"), _player.get("max_hp"))
	elif item["name"] == "CapeUp" and item.has("cape_level"):
		if _player.has_method("equip_cape"):
			_player.equip_cape(item["cape_level"])
	elif item["name"] == "HoodUp" and item.has("hood_level"):
		if _player.has_method("equip_hood"):
			_player.equip_hood(item["hood_level"])
	AudioMan.play("potion", 1.0, 0.0)
	# Rebuild merchant inventory (cape/hood show next level after purchase).
	_refresh_merchant_inventory()
	_refresh_items()

## Set a custom shop inventory (for different sellers).
func set_shop(title: String, items: Array) -> void:
	_shop_title = title
	_items = items
