extends Node
## PartyMan (autoload): manages recruited companions.
## Companions follow the player, fight alongside them, and persist in saves.

signal party_changed

const MAX_ACTIVE := 2

const COMPANIONS := {
	"mira": {
		"name": "Mira",
		"title": "Apprentice Mage",
		"role": "ranged",
		"kaykit": "Mage",
		"tint": Color(0.55, 0.30, 0.35),
		"hp": 70.0,
		"damage": 12.0,
		"attack_range": 10.0,
		"move_speed": 4.2,
		"desc": "Hurls frost bolts from afar. Mends your wounds when you falter.",
	},
	"bram": {
		"name": "Bram",
		"title": "Barbarian",
		"role": "melee",
		"kaykit": "Barbarian",
		"tint": Color(0.35, 0.45, 0.55),
		"hp": 130.0,
		"damage": 16.0,
		"attack_range": 2.2,
		"move_speed": 3.6,
		"desc": "A wall of muscle. Wades into the fray and breaks bones.",
	},
}

var recruited: Array = []  # companion IDs the player has recruited
var active: Array = []     # companion IDs currently following (subset of recruited)
var _nodes := {}           # id -> Companion node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_recruited(cid: String) -> bool:
	return cid in recruited

func is_active(cid: String) -> bool:
	return cid in active

func can_recruit() -> bool:
	return active.size() < MAX_ACTIVE

func recruit(cid: String) -> bool:
	if not COMPANIONS.has(cid):
		return false
	if not cid in recruited:
		recruited.append(cid)
	if not cid in active and active.size() < MAX_ACTIVE:
		active.append(cid)
		_spawn_companion(cid)
	party_changed.emit()
	return true

func dismiss(cid: String) -> void:
	active.erase(cid)
	_despawn_companion(cid)
	party_changed.emit()

func get_info(cid: String) -> Dictionary:
	return COMPANIONS.get(cid, {})

func active_companions() -> Array:
	var out := []
	for cid in active:
		if _nodes.has(cid):
			out.append(_nodes[cid])
	return out

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _spawn_companion(cid: String) -> void:
	if _nodes.has(cid):
		return
	var player := _player()
	if player == null:
		return
	var comp_script := load("res://src/party/companion.gd")
	var comp := comp_script.new() as CharacterBody3D
	comp.setup(cid, COMPANIONS[cid])
	var idx := active.find(cid)
	var offset := Vector3(-1.5 - idx * 0.8, 0, 1.5)
	comp.position = player.global_position + offset
	# Add to the scene root so companions persist across teleports.
	var scene := get_tree().current_scene
	if scene != null:
		scene.add_child(comp)
		_nodes[cid] = comp

func _despawn_companion(cid: String) -> void:
	if _nodes.has(cid):
		var n: Node = _nodes[cid]
		_nodes.erase(cid)
		if is_instance_valid(n):
			n.queue_free()

## Teleport all active companions alongside the player (doors/interiors).
func teleport_with(pos: Vector3) -> void:
	var i := 0
	for cid in active:
		if _nodes.has(cid):
			var n: Node3D = _nodes[cid]
			if is_instance_valid(n):
				n.global_position = pos + Vector3(-1.2 - i * 0.9, 0.1, 1.2)
				i += 1

## Ensure companions exist after scene setup / load.
func sync_companions() -> void:
	for cid in active:
		if not _nodes.has(cid):
			_spawn_companion(cid)

func get_save_data() -> Dictionary:
	return {"recruited": recruited.duplicate(), "active": active.duplicate()}

func load_save_data(d: Dictionary) -> void:
	recruited = d.get("recruited", []).duplicate()
	active = d.get("active", []).duplicate()
	# Nodes spawn once the scene is ready.
	call_deferred("sync_companions")
