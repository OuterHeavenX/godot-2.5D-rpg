extends CanvasLayer
## Full-screen game menu: STATUS / ITEMS / EQUIP / MAGIC / QUESTS / SAVE / CONFIG.
## Toggle with ESC / Tab (gamepad Start) or the floating menu button.
## Pauses the game while open.
## Built in code for a cohesive JRPG look.

const GOLD := Color(0.95, 0.78, 0.38)
const GOLD_DIM := Color(0.72, 0.62, 0.42)
const INK := Color(0.93, 0.94, 1.0)
const PORTRAIT := preload("res://src/ui/portrait.gd")
const TABS := ["STATUS", "ITEMS", "EQUIP", "SKILLS", "MAGIC", "QUESTS", "PARTY", "SAVE", "CONFIG"]

var _menu_root: Control
var _menu_btn: ActionButton
var _open := false
var _tab_index := 0
var _tab_btns: Array[Button] = []
var _pages: Array[Control] = []
# Sidebar refs.
var _side_level: Label
var _side_hp_fill: ColorRect
var _side_hp_label: Label
var _side_xp_fill: ColorRect
var _side_xp_label: Label
# Page refs.
var _stat_values := {}
var _party_list: VBoxContainer
var _magic_list: VBoxContainer
var _items_list: VBoxContainer
var _selected_item := ""
var _skills_list: VBoxContainer
var _quest_list: VBoxContainer
var _save_status: Label
var _music_btn: Button
var _sfx_btn: Button
var _erase_btn: Button
var _erase_armed := false
var _quit_btn: Button
var _quit_armed := false

func _ready() -> void:
	add_to_group("char_menu")
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	_build_button() # last: stays above the menu so it can close it

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if not _open:
		# Never open over the title screen or a story scene.
		var mm := get_tree().get_first_node_in_group("main_menu")
		if mm != null and mm.has_method("is_open") and mm.is_open():
			return
		if mm != null and mm.has_method("is_story_showing") and mm.is_story_showing():
			return
	_open = not _open
	AudioMan.play("click")
	if _open:
		_refresh()
		_select_tab(0)
		_menu_root.visible = true
		_update_pause()
		_menu_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_menu_root, "modulate:a", 1.0, 0.2)
	else:
		_menu_root.visible = false
		_update_pause()

## Returns true if the menu is currently open.
func is_menu_open() -> bool:
	return _open

## Update the pause state: paused if menu, dialogue, or shop is open.
func _update_pause() -> void:
	var paused := _open
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue != null and dialogue.has_method("is_dialogue_open") and dialogue.is_dialogue_open():
		paused = true
	var shop := get_tree().get_first_node_in_group("shop_ui")
	if shop != null and shop.has_method("is_shop_open") and shop.is_shop_open():
		paused = true
	get_tree().paused = paused

# ---------------------------------------------------------------- build

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

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.97)
	style.set_border_width_all(2)
	style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.6)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.visible = false
	add_child(_menu_root)

	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.045, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(margin)

	# Vertical stack: header, tab bar, content. Nothing scrolls.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# ---- header: portrait, name/level, bars
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel_style())
	vbox.add_child(header)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 14)
	header.add_child(hh)
	var portrait := PORTRAIT.new()
	portrait.portrait_size = 110.0
	hh.add_child(portrait)
	var hinfo := VBoxContainer.new()
	hinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hinfo.alignment = BoxContainer.ALIGNMENT_CENTER
	hinfo.add_theme_constant_override("separation", 4)
	hh.add_child(hinfo)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	hinfo.add_child(title_row)
	title_row.add_child(_label("Hooded Rogue", 20, GOLD))
	_side_level = _label("Lv 1", 24, INK)
	title_row.add_child(_side_level)
	_side_hp_label = _label("", 14, GOLD_DIM)
	hinfo.add_child(_side_hp_label)
	_side_hp_fill = _bar(hinfo, Color(0.35, 0.85, 0.4))
	_side_xp_label = _label("", 14, GOLD_DIM)
	hinfo.add_child(_side_xp_label)
	_side_xp_fill = _bar(hinfo, Color(0.65, 0.4, 1.0))

	# ---- tab bar: all tabs + CLOSE, always visible, no scrolling
	var tab_panel := PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", _panel_style())
	vbox.add_child(tab_panel)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_panel.add_child(tab_bar)
	for i in TABS.size():
		var b := _make_tab(TABS[i])
		b.pressed.connect(_select_tab.bind(i))
		tab_bar.add_child(b)
		_tab_btns.append(b)
	var close_btn := _make_tab("CLOSE")
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.65))
	close_btn.pressed.connect(toggle)
	tab_bar.add_child(close_btn)

	# ---- content pages (panel hugs the visible page; no scroller needed,
	# pages are short)
	var content := PanelContainer.new()
	content.add_theme_stylebox_override("panel", _panel_style())
	vbox.add_child(content)
	_pages = [
		_build_status_page(),
		_build_items_page(),
		_build_equip_page(),
		_build_skills_page(),
		_build_magic_page(),
		_build_quest_page(),
		_build_party_page(),
		_build_save_page(),
		_build_config_page(),
	]
	for p in _pages:
		content.add_child(p)

# ---------------------------------------------------------------- widgets

func _label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Thin bar; returns the fill ColorRect. Caller sets fill.anchor_right 0..1.
func _bar(parent: Control, color: Color) -> ColorRect:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 12)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wrap)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(fill)
	return fill

func _make_tab(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	_style_tab(b, false)
	return b

func _style_tab(b: Button, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.78, 0.38, 0.14) if selected \
			else Color(0.95, 0.78, 0.38, 0.05) if state == "hover" \
			else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", GOLD if selected else GOLD_DIM)
	b.add_theme_color_override("font_hover_color", GOLD)

func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.visible = false
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func _header(text: String) -> Label:
	var h := _label(text, 30, GOLD)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return h

func _body(text: String, size := 20, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _row(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := Label.new()
	k.text = key
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_theme_font_size_override("font_size", 22)
	k.add_theme_color_override("font_color", GOLD_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_font_size_override("font_size", 22)
	v.add_theme_color_override("font_color", INK)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	row.set_meta("value_label", v)
	return row

func _big_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(280, 56)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.78, 0.38, 0.12)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = Color(0.95, 0.78, 0.38, 0.25)
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_color_override("font_color", GOLD)
	return b

# ---------------------------------------------------------------- pages

func _build_status_page() -> Control:
	var v := _page()
	v.add_child(_header("STATUS"))
	for key in ["HEALTH", "MANA", "ATTACK", "KILLS", "DEATHS", "TIME PLAYED"]:
		var row := _row(key, "—")
		v.add_child(row)
		_stat_values[key] = row.get_meta("value_label")
	return v

func _build_items_page() -> Control:
	var v := _page()
	v.add_child(_header("ITEMS"))
	_items_list = VBoxContainer.new()
	_items_list.add_theme_constant_override("separation", 10)
	_items_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_items_list)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("items_changed"):
		player.items_changed.connect(_on_items_changed)
	return v

func _on_items_changed() -> void:
	if _open and TABS[_tab_index] == "ITEMS":
		_refresh_items()

## Every owned item in display order: potion first, then by kind.
func _owned_items() -> Array:
	var player := get_tree().get_first_node_in_group("player")
	var out := []
	if player == null:
		return out
	if int(player.get("potions")) > 0:
		out.append("potion")
	var rest := []
	var items: Dictionary = player.get("items")
	for id in items:
		if int(items[id]) > 0:
			rest.append(String(id))
	rest.sort_custom(func(x, y): return ItemDB.item_name(x) < ItemDB.item_name(y))
	var order := [ItemDB.KIND_CONSUMABLE, ItemDB.KIND_ACCESSORY, ItemDB.KIND_MATERIAL]
	for kind in order:
		for id in rest:
			if ItemDB.is_kind(id, kind):
				out.append(id)
	return out

func _refresh_items() -> void:
	for c in _items_list.get_children():
		c.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	var owned := _owned_items()
	if owned.is_empty():
		_items_list.add_child(_body("Your pack is empty.", 22))
		_items_list.add_child(_body("Potions, reagents and charms you find on your travels will appear here.",
			18, Color(1, 1, 1, 0.45)))
		return
	if _selected_item != "" and not owned.has(_selected_item):
		_selected_item = ""
	if _selected_item == "":
		_selected_item = owned[0]
	# Grid of item cells.
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_items_list.add_child(grid)
	for id in owned:
		grid.add_child(_item_cell(id, player.item_count(id), id == _selected_item,
			id == String(player.get("accessory"))))
	# Detail panel for the selected item.
	var info := ItemDB.get_item(_selected_item)
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 14)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_list.add_child(detail)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(text)
	var title := "%s  x%d" % [ItemDB.item_name(_selected_item), player.item_count(_selected_item)]
	if _selected_item == String(player.get("accessory")):
		title += "   (worn)"
	var tl := _body(title, 24, GOLD)
	text.add_child(tl)
	text.add_child(_body(String(info.get("desc", "")), 18))
	var kind := String(info.get("kind", ""))
	var hint := ""
	match kind:
		ItemDB.KIND_MATERIAL:
			hint = "Crafting reagent. The blacksmith forges with it; merchants buy it for %dG." % int(info.get("sell", 0))
		ItemDB.KIND_CONSUMABLE:
			hint = "Sells for %dG." % int(info.get("sell", 0))
			if _selected_item == "potion" and not DisplayServer.is_touchscreen_available():
				hint = "Press Q in the field to drink one. " + hint
		ItemDB.KIND_ACCESSORY:
			hint = "Accessory: one worn at a time. Sells for %dG." % int(info.get("sell", 0))
	text.add_child(_body(hint, 16, Color(1, 1, 1, 0.45)))
	if kind == ItemDB.KIND_CONSUMABLE:
		var use_btn := _big_button("USE")
		use_btn.custom_minimum_size = Vector2(130, 48)
		use_btn.pressed.connect(_on_use_item.bind(_selected_item))
		detail.add_child(use_btn)
	elif kind == ItemDB.KIND_ACCESSORY:
		var worn := _selected_item == String(player.get("accessory"))
		var eq_btn := _big_button("REMOVE" if worn else "WEAR")
		eq_btn.custom_minimum_size = Vector2(130, 48)
		eq_btn.pressed.connect(_on_equip_accessory.bind("" if worn else _selected_item))
		detail.add_child(eq_btn)

## A square cell: tinted glyph with the count in the corner.
func _item_cell(id: String, count: int, selected: bool, worn: bool) -> Control:
	var info := ItemDB.get_item(id)
	var col: Color = info.get("color", Color(1, 1, 1))
	var b := Button.new()
	b.text = String(info.get("glyph", "?"))
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", col.lightened(0.35))
	b.add_theme_color_override("font_hover_color", col.lightened(0.5))
	b.add_theme_color_override("font_pressed_color", col.lightened(0.5))
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r, col.g, col.b, 0.28 if state != "normal" else 0.18)
		sb.set_border_width_all(2)
		sb.border_color = GOLD if selected else Color(col.r, col.g, col.b, 0.6)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(_on_item_cell_pressed.bind(id))
	var n := Label.new()
	n.text = ("*" if worn else "") + str(count)
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", INK)
	n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	n.add_theme_constant_override("outline_size", 3)
	n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	n.offset_left = -30
	n.offset_top = -22
	n.offset_right = -4
	n.offset_bottom = -2
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(n)
	return b

func _on_item_cell_pressed(id: String) -> void:
	_selected_item = id
	AudioMan.play("click", 1.1, -6.0)
	_refresh_items()

func _on_use_item(id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("use_item"):
		if player.use_item(id):
			_refresh()
		else:
			AudioMan.play("click", 0.8, -4.0)

func _on_equip_accessory(id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("equip_accessory"):
		player.equip_accessory(id)
		AudioMan.play("click")
		_refresh()

func _build_equip_page() -> Control:
	var v := _page()
	v.add_child(_header("EQUIPMENT"))
	# Weapon (dynamic).
	var weapon_row := _row("WEAPON", _weapon_text())
	weapon_row.name = "WeaponRow"
	var wicon := TextureRect.new()
	wicon.name = "WeaponIcon"
	wicon.texture = _weapon_icon_texture()
	wicon.custom_minimum_size = Vector2(40, 40)
	wicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_row.add_child(wicon)
	weapon_row.move_child(wicon, 1)
	v.add_child(weapon_row)
	# Cape and hood (dynamic — updates when equipment changes).
	var cape_row := _row("CAPE", _cape_text())
	cape_row.name = "CapeRow"
	v.add_child(cape_row)
	var hood_row := _row("HOOD", _hood_text())
	hood_row.name = "HoodRow"
	v.add_child(hood_row)
	var acc_row := _row("ACCESSORY", _accessory_text())
	acc_row.name = "AccessoryRow"
	v.add_child(acc_row)
	v.add_child(_row("BODY", "Traveler's Garb"))
	v.add_child(_spacer(8))
	v.add_child(_body("Buy weapons at the blacksmith, who also forges charms from reagents. Capes and hoods at the market.", 18, Color(1, 1, 1, 0.45)))
	# Refresh when equipment changes.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("equipment_changed"):
		player.equipment_changed.connect(_refresh_equip_page)
	return v

func _weapon_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return "—"
	var lvl: int = player.get("weapon_level")
	if lvl <= 0:
		return "Rusty Dagger"
	return "%s (+%.1f ATK)" % [Equipment.weapon_name(lvl), Equipment.weapon_attack_bonus(lvl)]

func _cape_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return "—"
	var lvl: int = player.get("cape_level")
	if lvl <= 0:
		return "Worn Cape"
	return "%s (+%d HP)" % [Equipment.cape_name(lvl), int(Equipment.cape_hp_bonus(lvl))]

## Icon for the player's current weapon tier (0-5, Slate to Radiant).
func _weapon_icon_texture() -> Texture2D:
	var player := get_tree().get_first_node_in_group("player")
	var lvl: int = int(player.get("weapon_level")) if player != null else 0
	var tier := 0
	if lvl > 0:
		tier = mini((lvl - 1) / 10, 5)
	return load("res://assets/icons/weapon_tier%d.png" % tier) as Texture2D

func _hood_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return "—"
	var lvl: int = player.get("hood_level")
	if lvl <= 0:
		return "Worn Hood"
	return "%s (+%.1f ATK)" % [Equipment.hood_name(lvl), Equipment.hood_attack_bonus(lvl)]

func _accessory_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or String(player.get("accessory")) == "":
		return "—"
	var id := String(player.get("accessory"))
	return "%s (%s)" % [ItemDB.item_name(id), String(ItemDB.get_item(id).get("desc", ""))]

func _refresh_equip_page() -> void:
	# Find and update the equipment rows if the equip page exists.
	var acc_row := find_child("AccessoryRow", true, false)
	if acc_row != null and acc_row.get_child_count() >= 2:
		(acc_row.get_child(1) as Label).text = _accessory_text()
	var weapon_row := find_child("WeaponRow", true, false)
	var cape_row := find_child("CapeRow", true, false)
	var hood_row := find_child("HoodRow", true, false)
	if weapon_row != null and weapon_row.get_child_count() >= 3:
		(weapon_row.get_child(1) as TextureRect).texture = _weapon_icon_texture()
		(weapon_row.get_child(2) as Label).text = _weapon_text()
	if cape_row != null and cape_row.get_child_count() >= 2:
		(cape_row.get_child(1) as Label).text = _cape_text()
	if hood_row != null and hood_row.get_child_count() >= 2:
		(hood_row.get_child(1) as Label).text = _hood_text()

func _build_skills_page() -> Control:
	var v := _page()
	v.add_child(_header("SKILLS"))
	_skills_list = VBoxContainer.new()
	_skills_list.add_theme_constant_override("separation", 8)
	_skills_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_skills_list)
	return v

## Rebuild the skill list: points available, one row per skill with rank
## pips and a LEARN button.
func _refresh_skills_page() -> void:
	if _skills_list == null:
		return
	for c in _skills_list.get_children():
		c.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var points := int(player.get("skill_points"))
	_skills_list.add_child(_body("Skill points: %d   (one per level-up)" % points, 20,
		GOLD if points > 0 else GOLD_DIM))
	for id in Skills.ids():
		var info := Skills.get_skill(id)
		var rank: int = player.skill_rank(id)
		var maxr := Skills.max_rank(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _body(String(info["name"]), 22, GOLD if rank > 0 else INK)
		name_label.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_label)
		var pips := ""
		for i in maxr:
			pips += "●" if i < rank else "○"
		var pip_label := _body(pips, 22, GOLD if rank > 0 else Color(1, 1, 1, 0.35))
		pip_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(pip_label)
		var desc := _body(String(info["desc"]), 18, Color(1, 1, 1, 0.75))
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 20)
		if rank >= maxr:
			btn.text = "MAXED"
			btn.disabled = true
		else:
			btn.text = "LEARN"
			btn.disabled = points <= 0
			btn.pressed.connect(_on_learn_skill.bind(id))
		row.add_child(btn)
		_skills_list.add_child(row)

func _on_learn_skill(id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.learn_skill(id):
		AudioMan.play("levelup", 1.5, -8.0)
	else:
		AudioMan.play("click", 0.8, -4.0)
	_refresh_skills_page()

func _build_magic_page() -> Control:
	var v := _page()
	v.add_child(_header("MAGIC"))
	_magic_list = VBoxContainer.new()
	_magic_list.add_theme_constant_override("separation", 10)
	v.add_child(_magic_list)
	return v

## Rebuild the spell list (called on tab select and after level-ups).
func _refresh_magic_page() -> void:
	if _magic_list == null:
		return
	for child in _magic_list.get_children():
		child.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	var plevel := int(player.get("level")) if player != null else 1
	var selected := String(player.get("selected_spell")) if player != null else ""
	for spell_id in Spells.all():
		var info := Spells.get_info(spell_id)
		var unlock := int(info["unlock_level"])
		var unlocked := bool(player.call("is_spell_unlocked", spell_id)) if player != null else plevel >= unlock
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := _body(String(info["name"]), 24, GOLD)
		name_label.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_label)
		if not unlocked:
			var hint := String(info.get("unlock_hint", "Unlocks at Lv %d" % unlock))
			if hint == "":
				hint = "Unlocks at Lv %d" % unlock
			var lock_label := _body(hint, 20, Color(1, 1, 1, 0.4))
			lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lock_label)
		else:
			var desc := _body("%s  (%d MP)" % [String(info["desc"]), int(info["mp"])], 20)
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(desc)
			var btn := Button.new()
			if selected == spell_id:
				btn.text = "ACTIVE"
				btn.disabled = true
			else:
				btn.text = "SELECT"
				btn.pressed.connect(_on_select_spell.bind(spell_id))
			btn.custom_minimum_size = Vector2(140, 48)
			btn.add_theme_font_size_override("font_size", 22)
			row.add_child(btn)
		_magic_list.add_child(row)
	# Hint about casting.
	var hint := _body("Tap SELECT, then use the spark button (or C key) to cast.",
		18, Color(1, 1, 1, 0.45))
	_magic_list.add_child(hint)

func _on_select_spell(spell_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("select_spell"):
		player.select_spell(spell_id)
		AudioMan.play("click")
	_refresh_magic_page()

func _build_quest_page() -> Control:
	var v := _page()
	v.add_child(_header("QUESTS"))
	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 10)
	_quest_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_quest_list)
	return v

## Rebuild the quest list (called on tab select and when quests change).
func _refresh_quest_page() -> void:
	if _quest_list == null:
		return
	for child in _quest_list.get_children():
		child.queue_free()
	var any := false
	# Active quests: main story first, then side quests.
	for section in [["MAIN QUEST", true], ["SIDE QUESTS", false]]:
		var shown_header := false
		for qid in QuestDB.quest_ids():
			if QuestMan.get_state(qid) != QuestDB.State.ACTIVE:
				continue
			var q := QuestDB.get_quest(qid)
			if bool(q.get("main", false)) != section[1]:
				continue
			if not shown_header:
				_quest_list.add_child(_body(String(section[0]), 20, Color(1.0, 0.78, 0.42, 0.9)))
				shown_header = true
			any = true
			_quest_list.add_child(_body(String(q["title"]), 24, GOLD))
			_quest_list.add_child(_body(QuestMan.objective_text(qid), 20))
			_quest_list.add_child(_body("Reward: %dG, %d XP — return to %s" % [
				int(q["reward_gold"]), int(q["reward_xp"]), String(q["giver"])] ,
				18, Color(1, 1, 1, 0.45)))
	# Available quests.
	for qid in QuestDB.quest_ids():
		if QuestMan.get_state(qid) != QuestDB.State.AVAILABLE:
			continue
		any = true
		var q := QuestDB.get_quest(qid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _body(String(q["title"]), 22, GOLD)
		name_label.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_label)
		var giver_label := _body("Talk to %s" % String(q["giver"]), 20,
			Color(1.0, 0.85, 0.35, 0.8))
		giver_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(giver_label)
		_quest_list.add_child(row)
	# Completed quests.
	for qid in QuestDB.quest_ids():
		var st := QuestMan.get_state(qid)
		if st != QuestDB.State.COMPLETE and st != QuestDB.State.TURNED_IN:
			continue
		any = true
		var q := QuestDB.get_quest(qid)
		var done_text := "DONE"
		var done_color := Color(0.5, 0.9, 0.5, 0.7)
		if st == QuestDB.State.COMPLETE:
			done_text = "Return to %s!" % String(q["giver"])
			done_color = Color(1.0, 0.85, 0.35)
		_quest_list.add_child(_body("%s — %s" % [String(q["title"]), done_text],
			20, done_color))
	if not any:
		_quest_list.add_child(_body("No quests yet.", 22))
		_quest_list.add_child(_body("Talk to villagers — look for the golden !",
			18, Color(1, 1, 1, 0.45)))

func _build_party_page() -> Control:
	var v := _page()
	v.add_child(_header("PARTY"))
	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 8)
	v.add_child(_party_list)
	return v

func _build_save_page() -> Control:
	var v := _page()
	v.add_child(_header("SAVE"))
	v.add_child(_body("Record your journey and continue it later. The game also saves itself after quests and level-ups.", 20))
	var b := _big_button("SAVE GAME")
	b.pressed.connect(_on_save_pressed)
	var center := CenterContainer.new()
	center.add_child(b)
	v.add_child(center)
	_save_status = _body("", 18, GOLD_DIM)
	v.add_child(_save_status)
	v.add_child(_spacer(12))
	_quit_btn = _big_button("QUIT TO TITLE")
	_quit_btn.pressed.connect(_on_quit_pressed)
	var center2 := CenterContainer.new()
	center2.add_child(_quit_btn)
	v.add_child(center2)
	v.add_child(_body("Unsaved progress is lost when you quit.", 16, Color(1, 1, 1, 0.45)))
	return v

func _build_config_page() -> Control:
	var v := _page()
	v.add_child(_header("SETTINGS"))
	_music_btn = _big_button("MUSIC: ON")
	_music_btn.pressed.connect(_on_music_toggle)
	v.add_child(_music_btn)
	_sfx_btn = _big_button("SFX: ON")
	_sfx_btn.pressed.connect(_on_sfx_toggle)
	v.add_child(_sfx_btn)
	v.add_child(_spacer(12))
	_erase_btn = _big_button("ERASE SAVE")
	_erase_btn.pressed.connect(_on_erase_pressed)
	v.add_child(_erase_btn)
	return v

# ---------------------------------------------------------------- behavior

func _select_tab(i: int) -> void:
	_tab_index = i
	for j in _tab_btns.size():
		_style_tab(_tab_btns[j], j == i)
		_pages[j].visible = j == i
	if TABS[i] == "MAGIC":
		_refresh_magic_page()
	if TABS[i] == "SKILLS":
		_refresh_skills_page()
	if TABS[i] == "QUESTS":
		_refresh_quest_page()

func _refresh() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var lvl: int = player.get("level")
	var xp: int = player.get("xp")
	var xp_next: int = player.xp_for_next()
	var hp: float = player.get("hp")
	var max_hp: float = player.get("max_hp")
	var mp: float = player.get("mp")
	var max_mp: float = player.get("max_mp")
	var atk: float = player.get("attack_damage")
	var deaths: int = player.get("deaths")
	var play_time: float = player.get("play_time")
	var mgr := get_tree().get_first_node_in_group("skeleton_manager")
	var kills := int(mgr.get("kills")) if mgr != null else 0

	_side_level.text = "Lv %d" % lvl
	_side_hp_label.text = "HP %d / %d" % [int(hp), int(max_hp)]
	_side_hp_fill.anchor_right = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	_side_xp_label.text = "XP %d / %d" % [xp, xp_next]
	_side_xp_fill.anchor_right = clampf(float(xp) / float(maxi(xp_next, 1)), 0.0, 1.0)

	_stat_values["HEALTH"].text = "%d / %d" % [int(hp), int(max_hp)]
	_stat_values["MANA"].text = "%d / %d" % [int(mp), int(max_mp)]
	_stat_values["ATTACK"].text = "%d" % int(atk)
	_stat_values["KILLS"].text = "%d" % kills
	_stat_values["DEATHS"].text = "%d" % deaths
	_stat_values["TIME PLAYED"].text = _fmt_time(play_time)

	for c in _party_list.get_children():
		c.queue_free()
	var row := _row("Hooded Rogue", "Lv %d  ·  HP %d/%d" % [lvl, int(hp), int(max_hp)])
	_party_list.add_child(row)
	# Recruited companions.
	for cid in PartyMan.recruited:
		var cinfo := PartyMan.get_info(cid)
		var cname := String(cinfo.get("name", cid))
		var ctitle := String(cinfo.get("title", ""))
		var label := cname
		if ctitle != "":
			label += " (%s)" % ctitle
		var hp_text := ""
		var node: Node = null
		for n in get_tree().get_nodes_in_group("companions"):
			if String(n.get("companion_id")) == cid:
				node = n
				break
		if node != null:
			var chp: float = node.get("hp")
			var cmax: float = node.get("max_hp")
			if bool(node.get("knocked_out")):
				hp_text = "KO"
			else:
				hp_text = "HP %d/%d" % [int(chp), int(cmax)]
		elif not PartyMan.is_active(cid):
			hp_text = "Away"
		var crow := _row(label, hp_text)
		_party_list.add_child(crow)
		if PartyMan.is_active(cid):
			var dis := _big_button("DISMISS " + cname.to_upper())
			dis.pressed.connect(_on_dismiss_companion.bind(cid))
			_party_list.add_child(dis)
	if PartyMan.recruited.is_empty():
		_party_list.add_child(_body("No companions yet.", 22))
		_party_list.add_child(_body("Some villagers may join you as your legend grows...", 18, Color(1, 1, 1, 0.45)))

	var last := SaveGame.last_saved()
	_save_status.text = "Last saved: %s" % last if last != "" else "No save yet."
	_music_btn.text = "MUSIC: " + ("ON" if AudioMan.music_enabled else "OFF")
	_sfx_btn.text = "SFX: " + ("ON" if AudioMan.sfx_enabled else "OFF")
	_erase_armed = false
	_erase_btn.text = "ERASE SAVE"
	_quit_armed = false
	_quit_btn.text = "QUIT TO TITLE"
	_refresh_items()

func _on_use_potion() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("use_potion"):
		if player.use_potion():
			_refresh()
		else:
			AudioMan.play("click", 0.8, -4.0)

func _on_save_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var mgr := get_tree().get_first_node_in_group("skeleton_manager")
	var kills := int(mgr.get("kills")) if mgr != null else 0
	SaveGame.save_progress(player, kills)
	AudioMan.play("levelup", 1.3, -6.0)
	_save_status.text = "Progress saved."

func _on_dismiss_companion(cid: String) -> void:
	PartyMan.dismiss(cid)
	AudioMan.play("click", 1.0, -2.0)
	_refresh()

func _on_quit_pressed() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_btn.text = "TAP AGAIN TO QUIT"
		return
	_quit_armed = false
	AudioMan.play("click")
	# Back to the title: reload the main scene. Autoloads survive the
	# reload, so quest state is reset explicitly by the title screen.
	_open = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_music_toggle() -> void:
	AudioMan.set_music_enabled(not AudioMan.music_enabled)
	_music_btn.text = "MUSIC: " + ("ON" if AudioMan.music_enabled else "OFF")
	SaveGame.save_settings()
	AudioMan.play("click")

func _on_sfx_toggle() -> void:
	AudioMan.set_sfx_enabled(not AudioMan.sfx_enabled)
	_sfx_btn.text = "SFX: " + ("ON" if AudioMan.sfx_enabled else "OFF")
	SaveGame.save_settings()
	AudioMan.play("click")

func _on_erase_pressed() -> void:
	if not _erase_armed:
		_erase_armed = true
		_erase_btn.text = "TAP AGAIN TO CONFIRM"
		return
	_erase_armed = false
	_erase_btn.text = "ERASE SAVE"
	SaveGame.delete_save()
	_save_status.text = "Save erased."
	AudioMan.play("click")

func _fmt_time(s: float) -> String:
	var total := int(s)
	var h := total / 3600
	var m := (total % 3600) / 60
	var sec := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]
