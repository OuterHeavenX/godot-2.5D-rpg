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

const STANCES := ["follow", "stay", "attack"]
const GEAR_MAX := 10

# Banter: a companion speaks now and then while the party walks. Keyed by
# the music region so the lines fit where you are.
const BANTER := {
	"mira": {
		"village": [
			"Old Fen tells the story of you differently every time.",
			"Pip asked me to teach him magic. I told him to ask you first.",
			"The lamps look warmer since Vorgath fell.",
		],
		"north": [
			"My frost bolts fly straighter in this cold.",
			"Stay on the road. The treeline is full of teeth.",
			"I can feel the ice ahead. Something's awake in it.",
		],
		"boss": [
			"I'll keep you standing. Go!",
			"Watch the wind-up. Dodge, then hit it!",
		],
		"any": [
			"Need a heal? Just say the word. Or bleed. I'll notice.",
			"Bram says magic is cheating. Bram also can't count past four.",
		],
	},
	"bram": {
		"village": [
			"HA! Remember when you fell in the well? No? Good story anyway.",
			"The tavern's ale is better than the inn up north. Don't tell Yrsa.",
		],
		"north": [
			"Cold. Dead trees. Skeletons. I love it here.",
			"If it's got bones, I'll break them. If it's ice, I'll break that too.",
			"Grimholt still stands. Good. I owe Hob a drink.",
		],
		"boss": [
			"That's a big one. Let me in front!",
			"Its heart's glowing. Hit the heart!",
		],
		"any": [
			"Mira's frost bolts tickle. Mine don't. I don't have any.",
			"You walk fast for someone with such short legs.",
		],
	},
}
const BANTER_MIN := 22.0
const BANTER_MAX := 40.0

var recruited: Array = []  # companion IDs the player has recruited
var active: Array = []     # companion IDs currently following (subset of recruited)
var stances := {}          # id -> "follow" | "stay" | "attack"
var gear := {}             # id -> gear level (0..GEAR_MAX), bought at the forge
var _nodes := {}           # id -> Companion node
var _banter_timer := 12.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# Banter while walking (not paused, not in a building).
	if get_tree().paused or active.is_empty():
		return
	var player := _player() as Node3D
	if player == null or player.global_position.x > 400.0:
		return
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0 if player is CharacterBody3D else false
	if not moving:
		return
	_banter_timer -= delta
	if _banter_timer > 0.0:
		return
	_banter_timer = randf_range(BANTER_MIN, BANTER_MAX)
	var cid: String = active[randi() % active.size()]
	var comp: Node = _nodes.get(cid)
	if comp == null or not is_instance_valid(comp) or bool(comp.get("knocked_out")):
		return
	var region := AudioMan.current_region()
	var pool: Array = []
	var lines: Dictionary = BANTER.get(cid, {})
	pool.append_array(lines.get(region, []))
	if region != "boss":
		pool.append_array(lines.get("any", []))
	if pool.is_empty():
		return
	comp.say(String(pool[randi() % pool.size()]))

# ---------------------------------------------------------------- commands

func get_stance(cid: String) -> String:
	return String(stances.get(cid, "follow"))

func set_stance(cid: String, stance: String) -> void:
	if not stance in STANCES:
		return
	stances[cid] = stance
	var comp: Node = _nodes.get(cid)
	if comp != null and is_instance_valid(comp):
		comp.set_stance(stance)
	party_changed.emit()

## The party command key: every active companion steps to the next stance.
func cycle_stance_all() -> String:
	if active.is_empty():
		return ""
	var cur := get_stance(active[0])
	var next: String = STANCES[(STANCES.find(cur) + 1) % STANCES.size()]
	for cid in active:
		set_stance(cid, next)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("toast"):
		hud.toast("Party: %s" % next.to_upper())
	AudioMan.play("click", 1.2, -4.0)
	return next

# ---------------------------------------------------------------- gear

func gear_level(cid: String) -> int:
	return int(gear.get(cid, 0))

func gear_price(cid: String) -> int:
	return 120 + 60 * gear_level(cid)

func gear_name(cid: String) -> String:
	var base := "Axe" if cid == "bram" else "Staff"
	return "%s's %s +%d" % [String(get_info(cid).get("name", cid)), base, gear_level(cid) + 1]

## Buy the next gear level at the forge (+2 damage, +10% HP per level).
func upgrade_gear(cid: String) -> bool:
	if not is_recruited(cid) or gear_level(cid) >= GEAR_MAX:
		return false
	var player := _player()
	if player == null or not player.spend_gold(gear_price(cid)):
		return false
	gear[cid] = gear_level(cid) + 1
	var comp: Node = _nodes.get(cid)
	if comp != null and is_instance_valid(comp):
		comp.apply_gear(gear_level(cid))
	party_changed.emit()
	return true

## Forget the party (new game, or back to the title screen).
func reset() -> void:
	for cid in _nodes.keys():
		_despawn_companion(cid)
	_nodes.clear()
	recruited.clear()
	active.clear()
	stances.clear()
	gear.clear()
	party_changed.emit()

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
		if _nodes.has(cid) and is_instance_valid(_nodes[cid]):
			out.append(_nodes[cid])
	return out

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _spawn_companion(cid: String) -> void:
	if _nodes.has(cid) and is_instance_valid(_nodes[cid]):
		return
	_nodes.erase(cid)
	var player := _player()
	if player == null:
		return
	var comp_script := load("res://src/party/companion.gd")
	var comp := comp_script.new() as CharacterBody3D
	comp.setup(cid, COMPANIONS[cid])
	comp.apply_gear(gear_level(cid))
	comp.set_stance(get_stance(cid))
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
		if _nodes.has(cid) and is_instance_valid(_nodes[cid]):
			var n: Node3D = _nodes[cid]
			n.global_position = pos + Vector3(-1.2 - i * 0.9, 0.1, 1.2)
			n.velocity = Vector3.ZERO
			i += 1

## Ensure companions exist after scene setup / load.
func sync_companions() -> void:
	for cid in active:
		if not _nodes.has(cid) or not is_instance_valid(_nodes[cid]):
			_spawn_companion(cid)

func get_save_data() -> Dictionary:
	return {"recruited": recruited.duplicate(), "active": active.duplicate(),
		"stances": stances.duplicate(), "gear": gear.duplicate()}

func load_save_data(d: Dictionary) -> void:
	recruited = d.get("recruited", []).duplicate()
	active = d.get("active", []).duplicate()
	stances = {}
	for k in d.get("stances", {}):
		stances[String(k)] = String(d["stances"][k])
	gear = {}
	for k in d.get("gear", {}):
		gear[String(k)] = int(d["gear"][k])
	# Nodes spawn once the scene is ready.
	call_deferred("sync_companions")
