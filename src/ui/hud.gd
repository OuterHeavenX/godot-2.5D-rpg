extends CanvasLayer
## Combat HUD: health bar (top-left), kill counter (top-right),
## and a red damage flash. Always visible.

var _hp_fill: ColorRect
var _hp_bg: ColorRect
var _atb_fill: ColorRect
var _atb_bg: ColorRect
var _xp_fill: ColorRect
var _xp_bg: ColorRect
var _mp_fill: ColorRect
var _mp_bg: ColorRect
var _level_label: Label
var _kills_label: Label
var _gold_label: Label
var _flash: ColorRect
var _flash_alpha := 0.0
var _boss_bar: Control
var _boss_fill: ColorRect
var _boss_label: Label
var _last_hp := -1.0
var _pulse := 0.0
var _banner: Label
var _banner_alpha := 0.0
var _potion_label: Label
var _quest_tracker: Label
var _toast: Label
var _toast_alpha := 0.0
var _minimap: Control

func _ready() -> void:
	add_to_group("hud")
	layer = 5
	_build()
	# Hook up to the player and skeleton manager once they're ready.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_signal("hp_changed"):
			player.hp_changed.connect(_on_hp_changed)
		if player.has_signal("mp_changed"):
			player.mp_changed.connect(_on_mp_changed)
		if player.has_signal("atb_changed"):
			player.atb_changed.connect(_on_atb_changed)
		if player.has_method("get"):
			_on_hp_changed(player.get("hp"), player.get("max_hp"))
			_on_mp_changed(player.get("mp"), player.get("max_mp"))
			_on_atb_changed(player.get("atb"))
			_on_xp_changed(player.get("xp"), player.xp_for_next(), player.get("level"))
		if player.has_signal("xp_changed"):
			player.xp_changed.connect(_on_xp_changed)
		if player.has_signal("leveled_up"):
			player.leveled_up.connect(_on_leveled_up)
		if player.has_signal("gold_changed"):
			player.gold_changed.connect(_on_gold_changed)
		if player.has_signal("potions_changed"):
			player.potions_changed.connect(_on_potions_changed)
			_on_potions_changed(int(player.get("potions")))
	# Every region reports its own kills; the counter shows the total.
	for mgr in get_tree().get_nodes_in_group("foe_spawner"):
		if mgr.has_signal("kills_changed"):
			mgr.kills_changed.connect(_on_kills_changed)
	if QuestMan.has_signal("quests_changed"):
		QuestMan.quests_changed.connect(_on_quests_changed)
		_on_quests_changed()

func _build() -> void:
	# Health bar background.
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.15, 0.05, 0.05, 0.85)
	_hp_bg.anchor_left = 0.0
	_hp_bg.anchor_top = 0.0
	_hp_bg.offset_left = 16
	_hp_bg.offset_top = 16
	_hp_bg.offset_right = 216
	_hp_bg.offset_bottom = 40
	add_child(_hp_bg)
	# Health fill.
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.25, 0.8, 0.3)
	_hp_fill.anchor_left = 0.0
	_hp_fill.anchor_top = 0.0
	_hp_fill.offset_left = 19
	_hp_fill.offset_top = 19
	_hp_fill.offset_right = 213
	_hp_fill.offset_bottom = 37
	add_child(_hp_fill)
	# ATB bar background (below the health bar).
	_atb_bg = ColorRect.new()
	_atb_bg.color = Color(0.05, 0.08, 0.15, 0.85)
	_atb_bg.anchor_left = 0.0
	_atb_bg.anchor_top = 0.0
	_atb_bg.offset_left = 16
	_atb_bg.offset_top = 44
	_atb_bg.offset_right = 216
	_atb_bg.offset_bottom = 58
	add_child(_atb_bg)
	# ATB fill (cyan, pulses when full).
	_atb_fill = ColorRect.new()
	_atb_fill.color = Color(0.2, 0.8, 1.0)
	_atb_fill.anchor_left = 0.0
	_atb_fill.anchor_top = 0.0
	_atb_fill.offset_left = 19
	_atb_fill.offset_top = 47
	_atb_fill.offset_right = 213
	_atb_fill.offset_bottom = 55
	add_child(_atb_fill)
	# Kill counter (top-right). Plain text — web fonts lack the skull emoji.
	_kills_label = Label.new()
	_kills_label.text = "KILLS 0"
	_kills_label.add_theme_font_size_override("font_size", 24)
	_kills_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_kills_label.anchor_left = 1.0
	_kills_label.anchor_right = 1.0
	_kills_label.offset_left = -224
	_kills_label.offset_top = 12
	_kills_label.offset_right = -76
	_kills_label.offset_bottom = 48
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_kills_label)
	# Gold counter (below kills, top-right).
	_gold_label = Label.new()
	_gold_label.text = "GOLD 0"
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_label.anchor_left = 1.0
	_gold_label.anchor_right = 1.0
	_gold_label.offset_left = -224
	_gold_label.offset_top = 44
	_gold_label.offset_right = -76
	_gold_label.offset_bottom = 80
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_gold_label)
	# XP bar background (thin, below ATB).
	_xp_bg = ColorRect.new()
	_xp_bg.color = Color(0.10, 0.06, 0.18, 0.85)
	_xp_bg.anchor_left = 0.0
	_xp_bg.anchor_top = 0.0
	_xp_bg.offset_left = 16
	_xp_bg.offset_top = 62
	_xp_bg.offset_right = 216
	_xp_bg.offset_bottom = 70
	add_child(_xp_bg)
	# XP fill (violet).
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.65, 0.4, 1.0)
	_xp_fill.anchor_left = 0.0
	_xp_fill.anchor_top = 0.0
	_xp_fill.offset_left = 19
	_xp_fill.offset_top = 64
	_xp_fill.offset_right = 19
	_xp_fill.offset_bottom = 68
	add_child(_xp_fill)
	# Level label (left of the health bar).
	_level_label = Label.new()
	_level_label.text = "Lv 1"
	_mp_bg = ColorRect.new()
	_mp_bg.color = Color(0.05, 0.08, 0.20, 0.85)
	_mp_bg.anchor_left = 0.0
	_mp_bg.anchor_top = 0.0
	_mp_bg.offset_left = 16
	_mp_bg.offset_top = 74
	_mp_bg.offset_right = 216
	_mp_bg.offset_bottom = 82
	add_child(_mp_bg)
	# MP fill (blue).
	_mp_fill = ColorRect.new()
	_mp_fill.color = Color(0.25, 0.5, 1.0)
	_mp_fill.anchor_left = 0.0
	_mp_fill.anchor_top = 0.0
	_mp_fill.offset_left = 19
	_mp_fill.offset_top = 76
	_mp_fill.offset_right = 213
	_mp_fill.offset_bottom = 80
	add_child(_mp_fill)
	_level_label.add_theme_font_size_override("font_size", 24)
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_level_label.add_theme_constant_override("outline_size", 4)
	_level_label.anchor_left = 0.0
	_level_label.anchor_top = 0.0
	_level_label.offset_left = 224
	_level_label.offset_top = 14
	_level_label.offset_right = 300
	_level_label.offset_bottom = 44
	add_child(_level_label)
	# Level-up banner (center screen, fades).
	_banner = Label.new()
	_banner.text = ""
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 0.0))
	_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.0))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	# Damage flash (full screen, fades out).
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	# Potion counter (below the MP bar, top-left).
	var potion_icon := TextureRect.new()
	potion_icon.texture = preload("res://assets/icons/potion.png")
	potion_icon.anchor_left = 0.0
	potion_icon.anchor_top = 0.0
	potion_icon.offset_left = 16
	potion_icon.offset_top = 88
	potion_icon.offset_right = 44
	potion_icon.offset_bottom = 116
	potion_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	potion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	potion_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(potion_icon)
	_potion_label = Label.new()
	_potion_label.text = "x 0" if DisplayServer.is_touchscreen_available() else "x 0   (Q)"
	_potion_label.add_theme_font_size_override("font_size", 22)
	_potion_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
	_potion_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_potion_label.add_theme_constant_override("outline_size", 4)
	_potion_label.anchor_left = 0.0
	_potion_label.anchor_top = 0.0
	_potion_label.offset_left = 48
	_potion_label.offset_top = 88
	_potion_label.offset_right = 130
	_potion_label.offset_bottom = 116
	_potion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_potion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_potion_label)
	# Quest tracker (below the potion counter, top-left).
	_quest_tracker = Label.new()
	_quest_tracker.text = ""
	_quest_tracker.add_theme_font_size_override("font_size", 20)
	_quest_tracker.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	_quest_tracker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_quest_tracker.add_theme_constant_override("outline_size", 4)
	_quest_tracker.anchor_left = 0.0
	_quest_tracker.anchor_top = 0.0
	_quest_tracker.offset_left = 16
	_quest_tracker.offset_top = 120
	_quest_tracker.offset_right = 500
	_quest_tracker.offset_bottom = 148
	_quest_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quest_tracker)
	# Small toast (bottom-right corner): autosave notices and the like.
	_toast = Label.new()
	_toast.text = ""
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 0.0))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.0
	_toast.anchor_bottom = 0.0
	_toast.offset_left = -360
	_toast.offset_right = -76
	_toast.offset_top = 80
	_toast.offset_bottom = 104
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	# Minimap (top-right, under the counters).
	_minimap = Minimap.new()
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.anchor_top = 0.0
	_minimap.anchor_bottom = 0.0
	_minimap.offset_left = -206
	_minimap.offset_right = -16
	_minimap.offset_top = 112
	_minimap.offset_bottom = 302
	add_child(_minimap)
	# Boss bar (top-center, shown near the Drowned King).
	_boss_bar = Control.new()
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.offset_left = -260
	_boss_bar.offset_right = 260
	_boss_bar.offset_top = 14
	_boss_bar.offset_bottom = 70
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_bar)
	_boss_label = Label.new()
	_boss_label.text = "VORGATH, THE DROWNED KING"
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_font_size_override("font_size", 22)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	_boss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_boss_label.add_theme_constant_override("outline_size", 6)
	_boss_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_label.offset_bottom = 30
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_label)
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(0.1, 0.02, 0.02, 0.85)
	boss_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_bg.offset_top = 32
	boss_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(boss_bg)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.75, 0.12, 0.15)
	_boss_fill.anchor_left = 0.0
	_boss_fill.anchor_top = 0.0
	_boss_fill.anchor_right = 0.0
	_boss_fill.anchor_bottom = 1.0
	_boss_fill.offset_left = 3
	_boss_fill.offset_top = 35
	_boss_fill.offset_right = 517
	_boss_fill.offset_bottom = -3
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_fill)

func _process(delta: float) -> void:
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 1.5)
		_flash.color.a = _flash_alpha
	# Pulse the ATB bar when it's full and ready.
	_pulse += delta * 6.0
	if _atb_fill.offset_right >= 212.0:
		_atb_fill.color = Color(0.4 + 0.3 * sin(_pulse), 0.9, 1.0)
	else:
		_atb_fill.color = Color(0.2, 0.8, 1.0)
	# Fade the level-up banner.
	if _banner_alpha > 0.0:
		_banner_alpha = maxf(0.0, _banner_alpha - delta * 0.5)
		_banner.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.35, _banner_alpha))
		_banner.add_theme_color_override("font_outline_color",
			Color(0.1, 0.05, 0.0, _banner_alpha))
	if _toast_alpha > 0.0:
		_toast_alpha = maxf(0.0, _toast_alpha - delta * 0.6)
		_toast.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, minf(1.0, _toast_alpha)))
		_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, minf(1.0, _toast_alpha)))
	_update_boss_bar()

## Quiet corner notice (e.g. "Game saved"). Stays ~2s, then fades.
func toast(text: String) -> void:
	_toast.text = text
	_toast_alpha = 2.2

func _update_boss_bar() -> void:
	# Show the nearest living boss within 30 units (Vorgath or Morvain).
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_boss_bar.visible = false
		return
	var pp: Vector3 = player.global_position
	var best: Node = null
	var best_dist := 30.0
	for b in get_tree().get_nodes_in_group("boss"):
		if b == null or bool(b.get("dead")):
			continue
		var bp: Vector3 = b.global_position
		var dist := Vector2(bp.x - pp.x, bp.z - pp.z).length()
		if dist < best_dist:
			best = b
			best_dist = dist
	if best == null:
		_boss_bar.visible = false
		return
	_boss_bar.visible = true
	var bname: Variant = best.get("boss_name")
	_boss_label.text = String(bname) if bname != null else "BOSS"
	var frac := clampf(float(best.get("hp")) / float(maxi(1, best.get("max_hp"))), 0.0, 1.0)
	_boss_fill.offset_right = 3.0 + 514.0 * frac

func _on_hp_changed(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.offset_right = 19 + 194 * frac
	# Green -> yellow -> red as health drops.
	_hp_fill.color = Color(0.9 - 0.65 * frac, 0.25 + 0.55 * frac, 0.25)
	if _last_hp >= 0.0 and hp < _last_hp:
		_flash_alpha = 0.35
	_last_hp = hp

func _on_mp_changed(mp: float, max_mp: float) -> void:
	var frac := clampf(mp / max_mp, 0.0, 1.0)
	_mp_fill.offset_right = 19 + 194 * frac

func _on_kills_changed(_count: int) -> void:
	var total := 0
	for mgr in get_tree().get_nodes_in_group("foe_spawner"):
		total += int(mgr.get("kills"))
	_kills_label.text = "KILLS %d" % total

func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "GOLD %d" % amount

func _on_potions_changed(count: int) -> void:
	if DisplayServer.is_touchscreen_available():
		_potion_label.text = "x %d" % count
	else:
		_potion_label.text = "x %d   (Q)" % count

func _on_quests_changed() -> void:
	_quest_tracker.text = QuestMan.tracker_text()

## Center-screen announcement banner (quests, etc.).
func announce(text: String) -> void:
	_banner.text = text
	_banner_alpha = 1.0

func _on_atb_changed(atb: float) -> void:
	_atb_fill.offset_right = 19 + 194 * clampf(atb, 0.0, 1.0)

func _on_xp_changed(xp: int, xp_next: int, level: int) -> void:
	var frac := clampf(float(xp) / float(maxi(xp_next, 1)), 0.0, 1.0)
	_xp_fill.offset_right = 19 + 194 * frac
	_level_label.text = "Lv %d" % level

func _on_leveled_up(new_level: int) -> void:
	_banner.text = "LEVEL UP!"
	_banner_alpha = 1.0
	_level_label.text = "Lv %d" % new_level
	toast("Skill point earned (SKILLS tab)")
