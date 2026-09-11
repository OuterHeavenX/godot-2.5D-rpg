extends CanvasLayer
## Combat HUD: health bar (top-left), kill counter (top-right),
## and a red damage flash. Always visible.

var _hp_fill: ColorRect
var _hp_bg: ColorRect
var _atb_fill: ColorRect
var _atb_bg: ColorRect
var _kills_label: Label
var _flash: ColorRect
var _flash_alpha := 0.0
var _last_hp := -1.0
var _pulse := 0.0

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
			_on_hp_changed(player.get("hp"), player.get("MAX_HP"))
			_on_atb_changed(player.get("atb"))
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
	# Kill counter.
	_kills_label = Label.new()
	_kills_label.text = "💀 0"
	_kills_label.add_theme_font_size_override("font_size", 28)
	_kills_label.anchor_left = 1.0
	_kills_label.anchor_right = 1.0
	_kills_label.offset_left = -120
	_kills_label.offset_top = 12
	_kills_label.offset_right = -16
	_kills_label.offset_bottom = 48
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_kills_label)
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

func _on_hp_changed(hp: float, max_hp: float) -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.offset_right = 19 + 194 * frac
	# Green -> yellow -> red as health drops.
	_hp_fill.color = Color(0.9 - 0.65 * frac, 0.25 + 0.55 * frac, 0.25)
	if _last_hp >= 0.0 and hp < _last_hp:
		_flash_alpha = 0.35
	_last_hp = hp

func _on_kills_changed(count: int) -> void:
	_kills_label.text = "💀 %d" % count

func _on_atb_changed(atb: float) -> void:
	_atb_fill.offset_right = 19 + 194 * clampf(atb, 0.0, 1.0)
