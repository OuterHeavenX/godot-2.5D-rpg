extends Node
## Autosave: writes the save file after quest events and level-ups, plus a
## slow periodic save during play. Skips the title screen, story scenes and
## the moment of death. Shows a quiet HUD toast on each save.

const PERIODIC_SECONDS := 120.0

var _timer := 0.0

func _ready() -> void:
	add_to_group("autosave")
	QuestMan.quest_accepted.connect(_on_quest_event)
	QuestMan.quest_turned_in.connect(_on_quest_event)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("leveled_up"):
		player.leveled_up.connect(_on_level_up)

func _process(delta: float) -> void:
	# Only ticks while the game runs (this node pauses with the tree).
	_timer += delta
	if _timer >= PERIODIC_SECONDS:
		_timer = 0.0
		save_now("Autosaved")

func _on_quest_event(_quest_id: String) -> void:
	# Turn-ins fire from inside a dialogue; save once it has closed.
	call_deferred("save_now", "Progress saved")

func _on_level_up(_level: int) -> void:
	save_now("Progress saved")

func save_now(notice := "Game saved") -> void:
	var mm := get_tree().get_first_node_in_group("main_menu")
	if mm != null:
		if mm.has_method("is_open") and mm.is_open():
			return
		if mm.has_method("is_story_showing") and mm.is_story_showing():
			return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or bool(player.get("dead")):
		return
	# The legacy single count in the save: every region's kills, so an
	# old-format read of this file is not just the southern wilds'.
	var kills := 0
	for mgr in get_tree().get_nodes_in_group("foe_spawner"):
		kills += int(mgr.get("kills"))
	SaveGame.save_progress(player, kills)
	_timer = 0.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast(notice)
