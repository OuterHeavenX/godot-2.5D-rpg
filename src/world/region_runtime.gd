extends Node
## Runs the hub-and-spoke world: works out which region the hero stands
## in, wakes that region's monsters and scenery, puts the rest to sleep,
## switches the music, and announces the border crossing.
##
## Scenery nodes opt in by joining the "scenery" group and carrying a
## "region" meta tag. Monster spawners are found through the
## "foe_spawner" group.

const POLL := 0.25
## Scenery wakes this far outside its own region, so nothing pops in
## while the hero is close enough to see it.
const SCENERY_MARGIN := 70.0

var current := ""

var _timer := 0.0
var _player: Node3D = null
var _hud: Node = null

func _ready() -> void:
	add_to_group("region_runtime")
	QuestMan.region_opened.connect(_on_region_opened)
	call_deferred("_bind")

func _bind() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_hud = get_tree().get_first_node_in_group("hud")
	current = ""
	_sync(true)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < POLL:
		return
	_timer = 0.0
	_sync(false)

## Re-bind after a scene reload (new game, load, return to title).
func rebind() -> void:
	call_deferred("_bind")

func _sync(silent: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var pos := _player.global_position
	if pos.x > Regions.INTERIOR_X:
		# Indoors: the world outside keeps whatever state it had, so
		# stepping back out of a door shows no pop-in.
		return
	var region := Regions.at_pos(pos)
	for node in get_tree().get_nodes_in_group("foe_spawner"):
		var sp := node as RegionSpawner
		if sp == null:
			continue
		if sp.can_wake() and Regions.near(sp.region, pos, RegionSpawner.WAKE_MARGIN):
			sp.wake()
		else:
			sp.sleep()
	for node in get_tree().get_nodes_in_group("scenery"):
		var vis := node as Node3D
		if vis == null:
			continue
		var home := String(vis.get_meta("region", Regions.TOWN))
		var awake := Regions.near(home, pos, SCENERY_MARGIN)
		if vis.visible == awake:
			continue
		# A sleeping region is neither drawn nor ticked: its villagers stop
		# walking their rounds and its boss stops pacing until the hero is
		# close enough to see either happen.
		vis.visible = awake
		vis.process_mode = Node.PROCESS_MODE_INHERIT if awake \
			else Node.PROCESS_MODE_DISABLED
	if region == current:
		return
	current = region
	if silent:
		return
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("announce"):
		_hud.announce(Regions.display_name(region))

func _on_region_opened(region: String) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_hud = get_tree().get_first_node_in_group("hud")
	if _hud != null and _hud.has_method("announce"):
		_hud.announce("%s LIES OPEN" % Regions.display_name(region))
	AudioMan.play("levelup", 0.8, -2.0)
