extends SceneTree
## Headless integration tests. Run with:
##   godot --headless --path . -s tests/run_tests.gd
## Boots the real main scene, then drives the systems directly: the whole
## main quest chain, kills, both bosses, a save round-trip, death and
## respawn, party recruitment. Exits 1 on the first failure.

var _fails := 0
var _passes := 0
# Autoloads are not resolvable by name from a -s script; fetch them at boot.
var _qm: Node
var _pm: Node
var _am: Node
var _sg: GDScript  # SaveGame, loaded at runtime (it references autoloads)

func _init() -> void:
	call_deferred("_run")

func _check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	print("== boot")
	_qm = root.get_node("QuestMan")
	_pm = root.get_node("PartyMan")
	_am = root.get_node("AudioMan")
	_sg = load("res://src/save/save_game.gd")
	change_scene_to_file("res://src/world/main.tscn")
	await _frames(5)
	var scene := current_scene
	_check(scene != null, "main scene loaded")
	var player := get_first_node_in_group("player")
	_check(player != null, "player present")
	_check(get_first_node_in_group("hud") != null, "hud present")
	_check(get_first_node_in_group("skeleton_manager") != null, "south spawner present")
	_check(get_first_node_in_group("north_manager") != null, "north spawner present")
	_check(get_nodes_in_group("boss").size() == 2, "two bosses present")
	_check(get_nodes_in_group("villagers").size() >= 7, "villagers present")
	# The title screen pauses the tree; tests drive the game directly.
	paused = false
	var mm := get_first_node_in_group("main_menu")
	if mm != null:
		mm.set("_showing_story", false)

	print("== quests: chapter one")
	_qm.reset()
	_check(_qm.get_state("emberfell_arrives") == QuestDB.State.AVAILABLE, "first quest available")
	_qm.accept_quest("emberfell_arrives")
	_qm.on_dialogue_closed("Old Fen")
	_check(_qm.get_state("emberfell_arrives") == QuestDB.State.COMPLETE, "talk objective completes")
	var gold_before: int = player.get("gold")
	_qm.turn_in_quest("emberfell_arrives")
	_check(_qm.get_state("emberfell_arrives") == QuestDB.State.TURNED_IN, "turn-in recorded")
	_check(int(player.get("gold")) == gold_before + 50, "turn-in paid 50 gold")
	_check(_qm.get_state("what_stirs_below") == QuestDB.State.AVAILABLE, "next main quest unlocked")
	_qm.accept_quest("what_stirs_below")
	var killed := 0
	for n in get_nodes_in_group("skeletons"):
		if killed >= 8:
			break
		if n.is_in_group("boss") or bool(n.get("dead")):
			continue
		n.take_damage(99999.0, (n as Node3D).global_position + Vector3(1, 0, 0))
		killed += 1
	await _frames(3)
	_check(_qm.objective_progress("what_stirs_below") >= 8, "eight kills counted")
	_check(_qm.get_state("what_stirs_below") == QuestDB.State.COMPLETE, "kill quest completes")
	_check(int(player.get("level")) >= 2, "kills grant levels")
	_qm.turn_in_quest("what_stirs_below")
	_qm.accept_quest("the_black_water")
	player.global_position = Vector3(37, 0.5, 57)
	await _seconds(0.6)
	_check(_qm.get_state("the_black_water") == QuestDB.State.COMPLETE, "reach objective completes on the island")
	_check(_qm.objective_position() != null, "minimap has an objective while a turn-in is pending")
	_qm.turn_in_quest("the_black_water")
	_qm.accept_quest("the_drowned_tyrant")
	var vorgath: Node = null
	for b in get_nodes_in_group("boss"):
		if String(b.get("boss_id")) == "vorgath":
			vorgath = b
	_check(vorgath != null, "Vorgath found")
	vorgath.take_damage(99999.0, Vector3.ZERO)
	await _frames(3)
	_check(_qm.get_state("the_drowned_tyrant") == QuestDB.State.COMPLETE, "boss kill completes the quest")
	_qm.turn_in_quest("the_drowned_tyrant")
	await _frames(3)
	_check(paused, "chapter card pauses the game after Vorgath")
	paused = false
	if mm != null:
		mm.set("_showing_story", false)
	_check(_qm.get_state("the_northern_road") == QuestDB.State.AVAILABLE, "chapter two unlocked")

	print("== quests: chapter two")
	_qm.accept_quest("the_northern_road", true)
	_check(_qm.get_state("the_northern_road") == QuestDB.State.COMPLETE, "accepting from the giver counts as the talk")
	_qm.turn_in_quest("the_northern_road")
	_qm.accept_quest("grimholt_bound")
	player.global_position = Grimholt.CENTER + Vector3(0, 0.5, 0)
	await _seconds(0.6)
	_check(_qm.get_state("grimholt_bound") == QuestDB.State.COMPLETE, "reaching Grimholt completes the quest")
	_qm.turn_in_quest("grimholt_bound")
	_qm.accept_quest("the_cold_dark")
	killed = 0
	for n in get_nodes_in_group("skeletons"):
		if killed >= 12:
			break
		if n.is_in_group("boss") or bool(n.get("dead")):
			continue
		n.take_damage(99999.0, (n as Node3D).global_position + Vector3(1, 0, 0))
		killed += 1
	await _frames(3)
	_check(_qm.get_state("the_cold_dark") == QuestDB.State.COMPLETE, "twelve northern kills complete the quest")
	_qm.turn_in_quest("the_cold_dark")
	_qm.accept_quest("the_frozen_arena")
	player.global_position = Vector3(0, 0.5, -288)
	await _seconds(0.6)
	_check(_qm.get_state("the_frozen_arena") == QuestDB.State.COMPLETE, "reaching the arena completes the quest")
	_qm.turn_in_quest("the_frozen_arena")
	_qm.accept_quest("the_frozen_heart")
	var morvain: Node = null
	for b in get_nodes_in_group("boss"):
		if String(b.get("boss_id")) == "morvain":
			morvain = b
	_check(morvain != null, "Morvain found")
	morvain.take_damage(99999.0, Vector3.ZERO)
	await _frames(3)
	_check(_qm.get_state("the_frozen_heart") == QuestDB.State.COMPLETE, "Morvain kill completes the quest")
	_qm.turn_in_quest("the_frozen_heart")
	await _frames(3)
	_check(player.is_spell_unlocked("glacial_spike"), "Glacial Spike learned")
	_check(_qm.is_story_complete(), "story complete")
	_check(paused, "ending pauses the game")
	paused = false
	if mm != null:
		mm.set("_showing_story", false)

	print("== party")
	_check(_pm.recruit("mira"), "recruit Mira")
	await _frames(2)
	_check(get_nodes_in_group("companions").size() == 1, "companion spawned")
	var mira_villager: Node = null
	for v in get_nodes_in_group("villagers"):
		if String(v.get("npc_name")) == "Mira":
			mira_villager = v
	_check(mira_villager != null and not (mira_villager as Node3D).visible, "village Mira hidden while recruited")
	_pm.dismiss("mira")
	await _frames(2)
	_check(get_nodes_in_group("companions").is_empty(), "dismiss removes the companion")
	_check((mira_villager as Node3D).visible, "village Mira returns after dismissal")

	print("== inventory and crafting")
	player.add_item("bone_shard", 6)
	player.add_item("stolen_trinket", 1)
	player.add_item("wisp_essence", 2)
	player.add_item("slime_gel", 1)
	player.set("gold", 500)
	_check(player.has_item("bone_shard", 6), "materials stored")
	_check(not player.craft("elixir"), "cannot craft without reagents")
	_check(player.craft("bone_charm"), "craft a bone charm")
	_check(player.has_item("bone_charm") and not player.has_item("bone_shard"), "crafting consumes reagents")
	_check(int(player.get("gold")) == 420, "crafting charges the fee")
	_check(player.equip_accessory("bone_charm"), "wear the charm")
	_check(is_equal_approx(player.xp_multiplier(), 1.15), "charm boosts XP")
	_check(player.craft("ether") and player.has_item("ether"), "craft an ether")
	player.set("mp", 1.0)
	_check(player.use_item("ether") and float(player.get("mp")) > 20.0, "ether restores MP")
	_check(not player.use_item("ether"), "no ether left to drink")
	_check(player.equip_accessory(""), "remove the charm")
	_check(is_equal_approx(player.xp_multiplier(), 1.0), "XP bonus gone")
	var drops_ok := false
	for e in get_nodes_in_group("skeletons"):
		if e.get("drops") != null and (e.get("drops") as Array).size() >= 2:
			drops_ok = true
			break
	_check(drops_ok, "foes carry drop tables")

	print("== save round-trip")
	player.global_position = Vector3(3, 0.1, 5)
	player.set("gold", 1234)
	player.set("potions", 3)
	player.add_potion(0)
	player.add_item("black_pearl", 4)
	player.equip_accessory("bone_charm")
	_sg.save_progress(player, 20)
	_check(_sg.has_save(), "save written")
	var d: Dictionary = _sg.load_progress()
	_check(int(d["gold"]) == 1234 and int(d["potions"]) == 3, "save holds gold and potions")
	player.set("gold", 0)
	player.set("potions", 0)
	player.set("items", {})
	player.set("accessory", "")
	player.global_position = Vector3(20, 0.1, 20)
	_sg.apply_progress(d, player, get_first_node_in_group("skeleton_manager"))
	await _frames(2)
	_check(int(player.get("gold")) == 1234 and int(player.get("potions")) == 3, "load restores gold and potions")
	_check(player.item_count("black_pearl") == 4 and String(player.get("accessory")) == "bone_charm", "load restores items and accessory")
	_check(player.global_position.distance_to(Vector3(3, 0.1, 5)) < 0.5, "load restores position")
	_check(_qm.is_story_complete(), "load restores quest states")
	_sg.delete_save()
	_check(not _sg.has_save(), "erase removes progress")

	print("== death and respawn")
	player.global_position = Vector3(10, 0.1, 50)
	player.set("gold", 100)
	player.take_damage(99999.0, Vector3(11, 0, 50))
	_check(bool(player.get("dead")), "player dies")
	_check(int(player.get("gold")) == 90, "death costs ten percent gold")
	await _seconds(2.4)
	_check(not bool(player.get("dead")), "player respawns")
	_check(player.global_position.distance_to(Vector3(0, 0.1, 0)) < 1.0, "respawn at the well")
	_check(float(player.get("hp")) == float(player.get("max_hp")), "respawn with full health")

	print("== doors")
	var doors := get_first_node_in_group("doors")
	doors.call("_enter_interior", "market", Vector3(9, 0, -3))
	_check(doors.is_in_interior() and player.global_position.x > 400.0, "enter the market")
	doors.exit_interior()
	_check(not doors.is_in_interior() and player.global_position.x < 400.0, "exit the market")

	print("== audio regions")
	player.global_position = Vector3(0, 0.1, -100)
	await _seconds(0.5)
	_check(_am.current_region() == "north", "north music past the gate")
	player.global_position = Vector3(0, 0.1, 5)
	await _seconds(0.5)
	_check(_am.current_region() == "village", "village music at home")

	print("")
	print("%d passed, %d failed" % [_passes, _fails])
	if _fails > 0:
		printerr("TESTS FAILED")
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)
