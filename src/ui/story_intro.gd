class_name StoryIntro
extends CanvasLayer
## Story panels: the opening tale of Emberfell, an interlude each time a
## guardian falls and the next spoke of the world opens, and the ending
## under the village well. Tap to advance; the game stays paused until the
## tale is told.

signal intro_finished

const INTRO_PANELS := [
	{
		"title": "EMBERFELL",
		"body": "For a hundred years, the village of Emberfell has kept its lamps lit against the dark.\n\nBut the dead no longer rest."
	},
	{
		"title": "THE RISING",
		"body": "Night after night, skeletons crawl from the southern wilds, hungering for the warmth of the living.\n\nThe old ones whisper of black water... and something ancient beneath it."
	},
	{
		"title": "THE TRAVELER",
		"body": "You arrived at dusk with a dagger and an empty purse, seeking work and shelter.\n\nOld Fen, keeper of stories, waits by the village square.\nHe has been expecting you."
	},
]

## One interlude per guardian: the fight just won, and the gate it opened.
## Keyed by the quest whose turn-in plays it.
const INTERLUDES := {
	"the_drowned_tyrant": {
		"banner": "CHAPTER TWO: THE NORTHERN ROAD",
		"panels": [
			{
				"title": "THE CROWN IS SILENT",
				"body": "Vorgath sank back into the black water, and this time the water kept him.\n\nEmberfell's lamps burn bright again. But riders from the north bring grim news."
			},
			{
				"title": "CHAPTER TWO",
				"body": "Beyond the north gate the road runs cold and long, to a town called Grimholt.\n\nSomething older than any drowned king sleeps beneath the ice there. And it is waking."
			},
		],
	},
	"the_frozen_heart": {
		"banner": "CHAPTER THREE: THE WESTERN ROAD",
		"panels": [
			{
				"title": "THE FROZEN HEART",
				"body": "Morvain shattered on the black ice, and the first winter went out of the world with it.\n\nThe northern road is quiet. Grimholt's lamps will burn another hundred winters."
			},
			{
				"title": "CHAPTER THREE",
				"body": "The west gate has been barred so long the hinges have grown into the stone.\n\nFour years ago the highlands burned. Last night a rider came down out of them."
			},
		],
	},
	"the_ash_reaver": {
		"banner": "CHAPTER FOUR: THE DROWNED ROAD",
		"panels": [
			{
				"title": "THE ASH SETTLES",
				"body": "Kael fell on his own black glass, and the road through the highlands is a road again.\n\nEleven went up to hold Ashfall Watch. One walked back down, and she walks with you now."
			},
			{
				"title": "CHAPTER FOUR",
				"body": "East of the village the water came up a lifetime ago and never went down.\n\nSomewhere out in it a bell still rings at dusk, and nobody in Emberfell says so out loud."
			},
		],
	},
	"the_mire_horror": {
		"banner": "CHAPTER FIVE: THE WELL",
		"panels": [
			{
				"title": "THE WATER MOVES",
				"body": "Gholl went back under the pool in pieces, and for the first time in living memory the fen has a current.\n\nThe causeway is a road. The chapel has visitors again."
			},
			{
				"title": "CHAPTER FIVE",
				"body": "That same night, in Emberfell's square, the stone came off the well by itself.\n\nThere are steps cut into the shaft. Eleven generations have drawn water over them without knowing."
			},
		],
	},
}

const ENDING_PANELS := [
	{
		"title": "THE HOLLOW CROWN",
		"body": "The crown lies on the floor of the vault with nothing inside it.\n\nVorgath took it from something. Morvain was older, Kael was crueller, Gholl was hungrier. None of them were first."
	},
	{
		"title": "THE KEEPER",
		"body": "Alwin went down to fix the winch four hundred years ago and kept the lamps lit while he waited to be missed.\n\nHe puts them out himself, one by one, and does not come up with you."
	},
	{
		"title": "EMBERFELL",
		"body": "Five roads run out of one village, and every one of them is walkable.\n\nOld Fen has more stories than he has evenings left. For once he does not have to make up the endings."
	},
	{
		"title": "THE TRAVELER",
		"body": "You came with a dagger and an empty purse.\n\nThe roads stay open, and there are still bones in the wilds for anyone who wants the practice.\n\nThank you for playing."
	},
]

var _panels: Array = INTRO_PANELS
var _idx := 0
var _root: Control
var _title_label: Label
var _body_label: Label
var _hint_label: Label
var _full_text := ""
var _shown := 0
var _type_timer := 0.0
var _done_typing := false

func _ready() -> void:
	layer = 30 # Above the main menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide_intro()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# Faint vignette frame.
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(frame)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 180
	_title_label.offset_bottom = 280
	_root.add_child(_title_label)
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 30)
	_body_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.80))
	_body_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_label.offset_left = 120
	_body_label.offset_right = -120
	_body_label.offset_top = 300
	_body_label.offset_bottom = -160
	_root.add_child(_body_label)
	_hint_label = Label.new()
	_hint_label.text = "— tap to continue —"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -90
	_hint_label.offset_bottom = -50
	_root.add_child(_hint_label)
	# Skip button.
	var skip := Button.new()
	skip.text = "SKIP"
	skip.add_theme_font_size_override("font_size", 24)
	skip.custom_minimum_size = Vector2(130, 56)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -150
	skip.offset_right = -20
	skip.offset_top = 20
	skip.offset_bottom = 76
	skip.pressed.connect(_on_skip)
	_root.add_child(skip)
	# Tap anywhere to advance.
	var tap := Button.new()
	tap.text = ""
	tap.flat = true
	tap.modulate = Color(1, 1, 1, 0)
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(_on_advance)
	_root.add_child(tap)
	skip.move_to_front()

func show_intro() -> void:
	show_panels(INTRO_PANELS)

func show_ending() -> void:
	show_panels(ENDING_PANELS)

## The interlude for a guardian's turn-in, if it has one.
func show_interlude(quest_id: String) -> bool:
	if not INTERLUDES.has(quest_id):
		return false
	show_panels(INTERLUDES[quest_id]["panels"])
	return true

## The banner shown once that interlude is over.
static func interlude_banner(quest_id: String) -> String:
	if not INTERLUDES.has(quest_id):
		return ""
	return String(INTERLUDES[quest_id]["banner"])

## Play any list of {"title", "body"} panels; emits intro_finished at the end.
func show_panels(panels: Array) -> void:
	_panels = panels
	_idx = 0
	_root.visible = true
	_show_panel()

func hide_intro() -> void:
	_root.visible = false

func is_showing() -> bool:
	return _root.visible

func _show_panel() -> void:
	var p: Dictionary = _panels[_idx]
	_title_label.text = str(p["title"])
	_full_text = str(p["body"])
	_shown = 0
	_body_label.text = ""
	_type_timer = 0.0
	_done_typing = false
	_hint_label.visible = false

func _process(delta: float) -> void:
	if not _root.visible or _done_typing:
		return
	_type_timer += delta
	var want := int(_type_timer / 0.025)
	if want > _shown:
		_shown = mini(want, _full_text.length())
		_body_label.text = _full_text.left(_shown)
		if _shown >= _full_text.length():
			_done_typing = true
			_hint_label.visible = true

## Keyboard / gamepad: the interact action advances panels too.
func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("interact"):
		_on_advance()
		get_viewport().set_input_as_handled()

func _on_advance() -> void:
	if not _done_typing:
		# First tap completes the line.
		_shown = _full_text.length()
		_body_label.text = _full_text
		_done_typing = true
		_hint_label.visible = true
		return
	_idx += 1
	if _idx >= _panels.size():
		_finish()
	else:
		AudioMan.play("click")
		_show_panel()

func _on_skip() -> void:
	_finish()

func _finish() -> void:
	AudioMan.play("click")
	hide_intro()
	intro_finished.emit()
