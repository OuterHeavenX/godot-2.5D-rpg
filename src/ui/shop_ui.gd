extends CanvasLayer
## Shop UI: buy items with gold. Supports different sellers with custom inventories.
## Shows a TALK prompt near the shopkeeper, opens the shop panel on talk.

const MERCHANT_TITLE := "MERCHANT'S WARES"
const BLACKSMITH_TITLE := "BLACKSMITH'S FORGE"
const MERCHANT_ITEMS := [
	{"name": "Potion", "price": 50, "desc": "Restores 50 HP"},
	{"name": "Potion Bundle", "price": 140, "desc": "Three potions (150 HP in all)"},
]

var _items: Array = MERCHANT_ITEMS.duplicate()
var _shop_title := MERCHANT_TITLE
var _greeting := "Merchant: \"Welcome, traveler!\""

var _talk_prompt: Control
var _greeting_label: Label
var _shop_panel: Control
var _title_label: Label
var _gold_label: Label
var _items_box: VBoxContainer
var _player: Node3D

func _ready() -> void:
	add_to_group("shop_ui")
	layer = 10
	# Must process while paused, or the BUY buttons freeze.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_tree().get_first_node_in_group("player")
	_build_talk_prompt()
	_build_shop_panel()
	visible = true

func _build_talk_prompt() -> void:
	_talk_prompt = Control.new()
	_talk_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_talk_prompt.offset_top = -240
	_talk_prompt.offset_bottom = -120
	_talk_prompt.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_prompt.add_child(bg)
	_greeting_label = Label.new()
	_greeting_label.text = _greeting
	_greeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_greeting_label.add_theme_font_size_override("font_size", 24)
	_greeting_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_greeting_label.offset_top = 8
	_greeting_label.offset_bottom = -62
	_talk_prompt.add_child(_greeting_label)
	var talk_btn := Button.new()
	talk_btn.text = "TALK" if DisplayServer.is_touchscreen_available() else "TALK  (E)"
	talk_btn.focus_mode = Control.FOCUS_NONE
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
	# Title (updated by set_shop for each seller).
	_title_label = Label.new()
	_title_label.text = _shop_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)
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
	close_btn.focus_mode = Control.FOCUS_NONE
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
		elif item["name"] == "WeaponUp" and item.has("weapon_level"):
			display_name = Equipment.weapon_name(item["weapon_level"])
		elif item.has("craft"):
			display_name = "Forge: " + ItemDB.item_name(String(item["craft"]))
		elif item.has("sell"):
			display_name = "Sell: %s (x%d)" % [ItemDB.item_name(String(item["sell"])), _player.item_count(String(item["sell"]))]
		name_label.text = "%s - %d G\n%s" % [display_name, item["price"], item["desc"]]
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var buy_btn := Button.new()
		buy_btn.text = "SELL" if item.has("sell") else ("FORGE" if item.has("craft") else "BUY")
		buy_btn.custom_minimum_size = Vector2(100, 50)
		buy_btn.add_theme_font_size_override("font_size", 24)
		# Disable if can't afford or don't meet the level requirement.
		var can_buy := true
		if _player != null:
			if not item.has("sell") and _player.get("gold") < item["price"]:
				can_buy = false
			if item.has("req_level") and _player.get("level") < item["req_level"]:
				can_buy = false
			if item.has("craft"):
				var needs: Dictionary = ItemDB.RECIPES[String(item["craft"])]["needs"]
				for mat in needs:
					if not _player.has_item(String(mat), int(needs[mat])):
						can_buy = false
		if not can_buy:
			buy_btn.disabled = true
		buy_btn.focus_mode = Control.FOCUS_NONE
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		row.add_child(buy_btn)
		_items_box.add_child(row)

func _update_gold_label() -> void:
	if _player != null:
		_gold_label.text = "Your Gold: %d G" % _player.get("gold")

func show_talk_prompt() -> void:
	# Sellers can be indoors (merchant, smith, innkeepers) or out in the
	# open (Wren in Grimholt); the prompt only ever comes from a seller.
	if _shop_panel.visible:
		return
	_talk_prompt.visible = true

func hide_talk_prompt() -> void:
	_talk_prompt.visible = false

func _on_talk_pressed() -> void:
	_talk_prompt.visible = false
	_shop_panel.visible = true
	_title_label.text = _shop_title
	_refresh_merchant_inventory()
	_refresh_blacksmith_inventory()
	_refresh_wren_inventory()
	_refresh_items()
	# Pause the game while shopping (like the menu does), whoever the seller is.
	_update_pause()

## True when the interact action should go to this UI.
func wants_interact() -> bool:
	return _talk_prompt.visible or _shop_panel.visible

## Keyboard / gamepad: the interact action opens the shop from the prompt.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _talk_prompt.visible and not _shop_panel.visible:
		_on_talk_pressed()
		get_viewport().set_input_as_handled()

## Build the merchant inventory: potions + next cape/hood upgrades.
func _refresh_merchant_inventory() -> void:
	# Only for the merchant (not the innkeeper or blacksmith).
	if _shop_title != MERCHANT_TITLE:
		return
	var items: Array = MERCHANT_ITEMS.duplicate(true)
	if _player != null:
		var cape_lvl: int = _player.get("cape_level")
		var hood_lvl: int = _player.get("hood_level")
		if cape_lvl < Equipment.MAX_LEVEL:
			var next_cape := cape_lvl + 1
			var req := Equipment.required_player_level(next_cape)
			var req_text := " (Requires Lv.%d)" % req if req > 0 else ""
			items.append({
				"name": "CapeUp",
				"price": Equipment.upgrade_price(cape_lvl),
				"desc": "+%d Max HP%s" % [int(Equipment.cape_hp_bonus(next_cape)), req_text],
				"cape_level": next_cape,
				"req_level": req,
			})
		if hood_lvl < Equipment.MAX_LEVEL:
			var next_hood := hood_lvl + 1
			var req := Equipment.required_player_level(next_hood)
			var req_text := " (Requires Lv.%d)" % req if req > 0 else ""
			items.append({
				"name": "HoodUp",
				"price": Equipment.upgrade_price(hood_lvl),
				"desc": "+%.1f ATK%s" % [Equipment.hood_attack_bonus(next_hood), req_text],
				"hood_level": next_hood,
				"req_level": req,
			})
	items.append_array(_sell_rows())
	_items = items

## Wren in Grimholt trades potions and buys reagents.
func _refresh_wren_inventory() -> void:
	if _shop_title != "WREN'S WARES":
		return
	var items: Array = []
	for it in _items:
		if not it.has("sell"):
			items.append(it)
	items.append_array(_sell_rows())
	_items = items

## Sellable reagents and spare consumables the player carries.
func _sell_rows() -> Array:
	var rows := []
	if _player == null:
		return rows
	var ids: Array = (_player.get("items") as Dictionary).keys()
	ids.sort()
	for id in ids:
		var info := ItemDB.get_item(String(id))
		if info.is_empty() or _player.item_count(String(id)) <= 0:
			continue
		if String(id) == String(_player.get("accessory")):
			continue
		rows.append({"name": "Sell", "sell": String(id), "price": int(info.get("sell", 0)),
			"desc": String(info.get("desc", ""))})
	return rows

## Build the blacksmith inventory: next weapon upgrade, then the forge recipes.
func _refresh_blacksmith_inventory() -> void:
	if _shop_title != BLACKSMITH_TITLE:
		return
	var items := []
	if _player != null:
		var weapon_lvl: int = _player.get("weapon_level")
		if weapon_lvl < Equipment.MAX_LEVEL:
			var next_weapon := weapon_lvl + 1
			var req := Equipment.required_player_level(next_weapon)
			var req_text := " (Requires Lv.%d)" % req if req > 0 else ""
			items.append({
				"name": "WeaponUp",
				"price": Equipment.weapon_upgrade_price(weapon_lvl),
				"desc": "+%.1f ATK%s" % [Equipment.weapon_attack_bonus(next_weapon), req_text],
				"weapon_level": next_weapon,
				"req_level": req,
			})
	for rid in ItemDB.recipe_ids():
		var recipe: Dictionary = ItemDB.RECIPES[rid]
		items.append({
			"name": "Craft",
			"craft": String(rid),
			"price": int(recipe.get("fee", 0)),
			"desc": "%s Needs %s." % [String(ItemDB.get_item(String(rid)).get("desc", "")), ItemDB.recipe_text(String(rid))],
		})
	_items = items

func _on_close_pressed() -> void:
	_shop_panel.visible = false
	_update_pause()

## Returns true if the shop panel is currently open.
func is_shop_open() -> bool:
	return _shop_panel.visible

## Update the pause state: paused if shop, dialogue, or menu is open.
func _update_pause() -> void:
	var paused := _shop_panel.visible
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue != null and dialogue.has_method("is_dialogue_open") and dialogue.is_dialogue_open():
		paused = true
	var menu := get_tree().get_first_node_in_group("char_menu")
	if menu != null and menu.has_method("is_menu_open") and menu.is_menu_open():
		paused = true
	get_tree().paused = paused

func _on_buy_pressed(item: Dictionary) -> void:
	if _player == null:
		return
	# Enforce level requirement (in case the button was enabled).
	if item.has("req_level") and _player.get("level") < item["req_level"]:
		return
	if item.has("sell"):
		if _player.remove_item(String(item["sell"]), 1):
			_player.add_gold(int(item["price"]))
			AudioMan.play("potion", 0.9, 0.0)
		_refresh_merchant_inventory()
		_refresh_blacksmith_inventory()
		_refresh_wren_inventory()
		_refresh_items()
		return
	if item.has("craft"):
		if _player.craft(String(item["craft"])):
			AudioMan.play("levelup", 1.4, -8.0)
		else:
			AudioMan.play("click", 0.8, -4.0)
		_refresh_blacksmith_inventory()
		_refresh_items()
		return
	if not _player.spend_gold(item["price"]):
		return  # Can't afford (button should be disabled anyway).
	# Give the item.
	if item["name"] == "Potion":
		_player.add_potion(1)
	elif item["name"] == "Potion Bundle":
		_player.add_potion(3)
	elif item["name"] == "Ale":
		# Restore 25 HP directly.
		var new_hp = minf(_player.get("max_hp"), _player.get("hp") + 25.0)
		_player.set("hp", new_hp)
		if _player.has_signal("hp_changed"):
			_player.hp_changed.emit(new_hp, _player.get("max_hp"))
	elif item["name"] == "Rest":
		# Full heal, body and mind.
		_player.set("hp", _player.get("max_hp"))
		_player.set("mp", _player.get("max_mp"))
		if _player.has_signal("hp_changed"):
			_player.hp_changed.emit(_player.get("hp"), _player.get("max_hp"))
		if _player.has_signal("mp_changed"):
			_player.mp_changed.emit(_player.get("mp"), _player.get("max_mp"))
	elif item["name"] == "CapeUp" and item.has("cape_level"):
		if _player.has_method("equip_cape"):
			_player.equip_cape(item["cape_level"])
	elif item["name"] == "HoodUp" and item.has("hood_level"):
		if _player.has_method("equip_hood"):
			_player.equip_hood(item["hood_level"])
	elif item["name"] == "WeaponUp" and item.has("weapon_level"):
		if _player.has_method("equip_weapon"):
			_player.equip_weapon(item["weapon_level"])
	AudioMan.play("potion", 1.0, 0.0)
	# Rebuild inventories (upgrades show next level after purchase).
	_refresh_merchant_inventory()
	_refresh_blacksmith_inventory()
	_refresh_items()

## Set a custom shop inventory (for different sellers). The greeting is
## the line shown on the TALK prompt.
func set_shop(title: String, items: Array, greeting := "") -> void:
	_shop_title = title
	_items = items
	_greeting = greeting if greeting != "" else "Welcome, traveler!"
	if _greeting_label != null:
		_greeting_label.text = _greeting
	if _title_label != null:
		_title_label.text = _shop_title
