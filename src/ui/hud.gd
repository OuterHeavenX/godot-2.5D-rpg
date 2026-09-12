extends CanvasLayer
## Combat HUD: health bar (top-left), kill counter (top-right),
## and a red damage flash. Always visible.

var _hp_fill: ColorRect
var _hp_bg: ColorRect
var _atb_fill: ColorRect
var _atb_bg: ColorRect
var _xp_fill: ColorRect
var _xp_bg: ColorRect
var _level_label: Label
var _kills_label: Label
var _gold_label: Label
var _flash: ColorRect
var _flash_alpha := 0.0
var _last_hp := -1.0
var _pulse := 0.0
var _banner: Label
var _banner_alpha := 0.0

func _ready() -> void:
	layer = 5
	_build()
	# Hook up to the player and skeleton manager once they're ready.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_signal("hp_changed"):
			player.hp_changed.connect(_on_hp_changed)
		if player.has_signal("atb_changed"):
			player.atb_changed.connect(_on_atb_changed)
		if player.has_method("get"):
			_on_hp_changed(player.get("hp"), player.get("max_hp"))
			_on_atb_changed(player.get("atb"))
			_on_xp_changed(player.get("xp"), player.xp_for_next(), player.get("level"))
		if player.has_signal("xp_changed"):
			player.xp_changed.connect(_on_xp_changed)
		if player.has_signal("leveled_up"):
			player.leveled_up.connect(_on_leveled_up)
		if player.has_signal("gold_changed"):
			player.gold_changed.connect(_on_gold_changed)
	var mgr := get_tree().get_first_node_in_group("skeleton_manager")
	if mgr != null and mgr.has_signal("kills_changed"):
		mgr.kills_changed.connect(_on_kills_changed)

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

func _on_hp_changed(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.offset_right = 19 + 194 * frac
	# Green -> yellow -> red as health drops.
	_hp_fill.color = Color(0.9 - 0.65 * frac, 0.25 + 0.55 * frac, 0.25)
	if _last_hp >= 0.0 and hp < _last_hp:
		_flash_alpha = 0.35
	_last_hp = hp

func _on_kills_changed(count: int) -> void:
	_kills_label.text = "KILLS %d" % count

func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "GOLD %d" % amount

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
