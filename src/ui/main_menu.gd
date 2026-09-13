extends CanvasLayer
## Main menu: title screen with New Game / Continue and How to Play.
## The game is paused until Play is pressed. Built entirely in code
## for a cohesive stylized look. Also drives the story intro and the
## ending scene once the final quest is turned in.

var _menu_root: Control
var _how_panel: PanelContainer
var _intro: CanvasLayer
var _showing_story := false  # interlude or ending on screen (not the intro)
var _showing_ending := false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("main_menu")
	_build()
	_intro = load("res://src/ui/story_intro.gd").new()
	_intro.name = "StoryIntro"
	add_child(_intro)
	_intro.intro_finished.connect(_on_story_finished)
	# The quest autoload outlives scene reloads (quit to title): rebind it
	# to the fresh scene and forget the old run until the player picks one.
	QuestMan.reset()
	QuestMan.rebind()
	PartyMan.reset()
	QuestMan.quest_turned_in.connect(_on_quest_turned_in)
	get_tree().paused = true

func is_open() -> bool:
	return _menu_root.visible

## True while the intro or the ending is on screen.
func is_story_showing() -> bool:
	return _intro != null and _intro.is_showing()

func _build() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_root)

	# Dim the world behind.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(dim)

	# Centered column.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title.
	var title := Label.new()
	title.text = "ROGUE'S TALE"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle.
	var sub := Label.new()
	sub.text = "A  2.5D  ADVENTURE"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	# Spacer.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 30)
	vbox.add_child(spacer)

	# Continue first when a save exists, then New Game.
	var has_save := SaveGame.has_save()
	if has_save:
		var cont := _make_menu_button("CONTINUE", 64, Color(0.15, 0.55, 0.75), Color(0.4, 0.9, 1.0))
		cont.pressed.connect(_on_continue)
		vbox.add_child(cont)
	var play := _make_menu_button("NEW GAME" if has_save else "PLAY", 64 if not has_save else 44,
		Color(0.15, 0.55, 0.75) if not has_save else Color(0.55, 0.42, 0.15),
		Color(0.4, 0.9, 1.0) if not has_save else Color(0.95, 0.78, 0.38))
	play.pressed.connect(_on_play)
	vbox.add_child(play)

	# How to play button.
	var how := _make_menu_button("HOW TO PLAY", 40, Color(0.18, 0.20, 0.28), Color(0.6, 0.65, 0.8))
	how.pressed.connect(_on_how)
	vbox.add_child(how)

	# Footer hint.
	var hint := Label.new()
	hint.text = "KayKit assets · CC0"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	_build_how_panel()

func _make_menu_button(text: String, font_size: int, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.custom_minimum_size = Vector2(340, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_border_width_all(3)
	normal.border_color = border
	normal.set_corner_radius_all(14)
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	normal.content_margin_left = 32
	normal.content_margin_right = 32
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.18)
	hover.border_color = border.lightened(0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _build_how_panel() -> void:
	_how_panel = PanelContainer.new()
	_how_panel.set_anchors_preset(Control.PRESET_CENTER)
	_how_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.97)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.85, 1.0, 0.7)
	style.set_corner_radius_all(16)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	_how_panel.add_theme_stylebox_override("panel", style)
	add_child(_how_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_how_panel.add_child(vbox)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var is_touch := DisplayServer.is_touchscreen_available()
	var lines := [
		["Move", "Left stick" if is_touch else "WASD / Arrows  (gamepad: left stick)"],
		["Attack", "Sword button (when ATB is full)" if is_touch else "SPACE (when ATB is full)  /  X"],
		["Dodge", "Roll button" if is_touch else "SHIFT  /  B"],
		["Cast", "Spark button" if is_touch else "C  /  Y"],
		["Sprint", "Fast button" if is_touch else "F  /  LB"],
		["Potion", "Flask button" if is_touch else "Q  /  RB"],
		["Talk / Enter", "Tap the prompt" if is_touch else "E or ENTER  /  A"],
		["Menu", "Top-right button" if is_touch else "ESC or TAB  /  Start"],
		["", ""],
		["Goal", "Talk to Old Fen by the well, then head south through the gate."],
		["", "Skeletons telegraph attacks with a red ! —"],
		["", "dodge the flash, then punish with your slash."],
		["", ""],
		["XP", "Slain skeletons grant XP. Level up for more HP, MP and"],
		["", "harder hits. Dying costs a tenth of your gold."],
	]
	for line in lines:
		var lbl := Label.new()
		if line[0] == "":
			lbl.text = line[1]
			lbl.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		else:
			lbl.text = "%s:  %s" % [line[0], line[1]]
			lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)

	var close := _make_menu_button("CLOSE", 32, Color(0.18, 0.20, 0.28), Color(0.6, 0.65, 0.8))
	close.pressed.connect(_on_close_how)
	vbox.add_child(close)

func _on_close_how() -> void:
	AudioMan.play("click")
	_how_panel.visible = false

func _on_play() -> void:
	AudioMan.play("click")
	_menu_root.visible = false
	QuestMan.reset()
	PartyMan.reset()
	# New game: tell the tale of Emberfell first. The game stays paused
	# until the intro finishes.
	_showing_story = false
	_showing_ending = false
	_intro.show_intro()

func _on_story_finished() -> void:
	get_tree().paused = false
	if _showing_story:
		_showing_story = false
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("announce"):
			hud.announce("THE NORTH IS FREE" if _showing_ending else "CHAPTER TWO: THE NORTHERN ROAD")
		_showing_ending = false
		# The turn-in happened under the story scene; record it now.
		get_tree().call_group("autosave", "save_now", "Progress saved")
		return
	# The opening scene hands the hero their first main quest.
	if QuestMan.get_state("emberfell_arrives") == QuestDB.State.AVAILABLE:
		QuestMan.accept_quest("emberfell_arrives")

func _on_quest_turned_in(quest_id: String) -> void:
	# The turn-in happens inside a dialogue that unpauses on close; wait a
	# frame so the story scene's pause is the last word.
	if quest_id == "the_drowned_tyrant":
		call_deferred("_show_story", false)
	elif quest_id == "the_frozen_heart":
		call_deferred("_show_story", true)

func _show_story(is_ending: bool) -> void:
	_showing_story = true
	_showing_ending = is_ending
	get_tree().paused = true
	if is_ending:
		_intro.show_ending()
	else:
		_intro.show_interlude()

func _on_continue() -> void:
	AudioMan.play("click")
	var d := SaveGame.load_progress()
	var player := get_tree().get_first_node_in_group("player")
	var mgr := get_tree().get_first_node_in_group("skeleton_manager")
	if player != null:
		SaveGame.apply_progress(d, player, mgr)
	get_tree().paused = false
	_menu_root.visible = false

func _on_how() -> void:
	AudioMan.play("click")
	_how_panel.visible = true
