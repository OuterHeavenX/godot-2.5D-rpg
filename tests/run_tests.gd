extends SceneTree
## Headless integration tests. Run with:
##   godot --headless --path . -s tests/run_tests.gd
## Boots the real main scene, then drives the systems directly: the whole
## main quest chain, kills, the guardians of all five regions, a save
## round-trip, death and respawn, party recruitment. Exits 1 on failure.
##
## Careful with global class names in here: naming a class whose script
## touches an autoload (AudioMan, QuestMan, PartyMan) compiles it before
## the autoloads exist and breaks the whole run. Load those with load()
## inside the test instead.

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

## Turning in a guardian's quest puts a story card up and pauses the tree.
## Tests read the card as "did it appear", then clear it.
func _clear_story_card() -> bool:
	var was_paused := paused
	paused = false
	var mm := get_first_node_in_group("main_menu")
	if mm != null:
		mm.set("_showing_story", false)
	return was_paused

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
	_check(get_first_node_in_group("west_manager") != null, "west spawner present")
	_check(get_first_node_in_group("east_manager") != null, "east spawner present")
	_check(get_first_node_in_group("deep_manager") != null, "vault spawner present")
	_check(get_nodes_in_group("boss").size() == 5, "five bosses present")
	_check(get_nodes_in_group("villagers").size() >= 7, "villagers present")
	# The title screen pauses the tree; tests drive the game directly.
	paused = false
	var mm := get_first_node_in_group("main_menu")
	if mm != null:
		mm.set("_showing_story", false)

	print("== boss arenas")
	# Each guardian has to stay on its own ground. Morvain once carried
	# bounds from an arena that had moved, and spent the game standing in
	# the middle of the north road instead.
	var arenas := {
		"vorgath": Vector3(37, 0, 57), "morvain": Vector3(0, 0, -288),
		"kael": Vector3(-286, 0, 0), "gholl": Vector3(286, 0, 0),
		"hollow": Vector3(0, 0, 358),
	}
	await _seconds(0.6)
	for b0 in get_nodes_in_group("boss"):
		var bid := String(b0.get("boss_id"))
		var home: Vector3 = arenas.get(bid, Vector3.ZERO)
		var bp: Vector3 = (b0 as Node3D).global_position
		_check(Vector2(bp.x - home.x, bp.z - home.z).length() < 16.0,
			"%s stands in its own arena" % bid)
	# And has to be able to close on a hero at the edge of it. Vorgath's
	# square bounds used to stop him three metres short of the bridge
	# landing, where the hero could stand and plink at him.
	player.global_position = Vector3(31.5, 0.45, 57.0)
	await _seconds(5.0)
	for b1 in get_nodes_in_group("boss"):
		if String(b1.get("boss_id")) != "vorgath":
			continue
		var vp: Vector3 = (b1 as Node3D).global_position
		_check(Vector2(vp.x - 31.5, vp.z - 57.0).length()
			< float(b1.get("attack_range")) * 1.35 + 0.8,
			"Vorgath reaches the hero at the bridge landing")
	# And every guardian has to be allowed to walk its whole arena. Square
	# bounds inside a round one left a ring at the rim the boss could not
	# reach, which is where a hero learns to stand.
	for b3 in get_nodes_in_group("boss"):
		var bid3 := String(b3.get("boss_id"))
		var rad: float = b3.get("roam_radius")
		if rad <= 0.0:
			continue
		var arena_r: float = {"vorgath": 7.0, "morvain": 15.0,
			"kael": 14.0, "gholl": 14.0}.get(bid3, 0.0)
		_check(arena_r > 0.0 and rad > arena_r - 2.0,
			"%s may walk to the edge of its ground" % bid3)
	player.global_position = Vector3(0, 0.1, 5)
	# Dying to a boss has to hand back the fight it started, not a harder
	# one: full health, its opening numbers, and none of the help it
	# called still standing in the arena.
	for b2 in get_nodes_in_group("boss"):
		var bid2 := String(b2.get("boss_id"))
		# Only the later bosses keep their opening numbers this way.
		var raw: Variant = b2.get("_fight_base")
		if not raw is Dictionary or (raw as Dictionary).is_empty():
			continue
		var base: Dictionary = raw
		b2.set("hp", float(b2.get("max_hp")) * 0.2)
		for key: String in base:
			b2.set(_stat_for(key), float(base[key]) * 0.5)
		# _adds is a typed Array[Node]; an untyped one will not assign.
		var adds: Array[Node] = []
		for i in 2:
			var add := Node3D.new()
			b2.add_child(add)
			adds.append(add)
		b2.set("_adds", adds)
		b2.call("_on_player_died")
		await _frames(2)
		_check(float(b2.get("hp")) == float(b2.get("max_hp")),
			"%s comes back at full health" % bid2)
		var restored := true
		for key: String in base:
			if not is_equal_approx(float(b2.get(_stat_for(key))), float(base[key])):
				restored = false
		_check(restored, "%s comes back with its opening numbers" % bid2)
		var cleared := true
		for add in adds:
			if is_instance_valid(add):
				cleared = false
		_check(cleared and (b2.get("_adds") as Array).is_empty(),
			"%s takes the help it called down with it" % bid2)
		var warn: Variant = b2.get("_warn_label")
		_check(warn == null or not (warn as Label3D).visible,
			"%s lowers its guard on reset" % bid2)

	print("== falling out of the world")
	# Every hole found is fixed at the geometry, but a fall off the map
	# costs the whole run, so there is a net under it.
	player.global_position = Vector3(4.0, -120.0, -274.0)
	await _seconds(0.4)
	_check(player.global_position.y > -40.0
		and player.global_position.distance_to(Vector3(0, 0.1, 0)) < 2.0,
		"a fall out of the world puts the hero back at the well")
	# The frozen arena's kerb used to open fourteen metres wide across a
	# seven-metre slab, leaving a void band on each side of the corridor.
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var sealed := true
	for probe_x: float in [4.0, 5.0, 6.0, 7.0]:
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(probe_x, 1.0, -280.0), Vector3(probe_x, 1.0, -268.0))
		if space.intersect_ray(q).is_empty():
			sealed = false
	_check(sealed, "the arena kerb closes everywhere there is no floor")
	# And still lets the hero in along the corridor.
	var way_in := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 1.0, -268.0), Vector3(0.0, 1.0, -280.0))
	_check(space.intersect_ray(way_in).is_empty(), "the corridor is still open")
	player.global_position = Vector3(0, 0.1, 5)

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
	# The southern foes only exist while the hero is in the south: stand
	# there and let the spawner wake before counting kills.
	player.global_position = Vector3(0, 0.1, 45)
	await _seconds(0.5)
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
	_check(_qm.get_state("the_frozen_heart") == QuestDB.State.TURNED_IN,
		"chapter two turned in")
	_check(not _qm.is_story_complete(), "the story does not end in the north")
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
	var mira: Node = get_nodes_in_group("companions")[0]
	mira.say("Test line")
	_check(mira.get("_bubble") != null and (mira.get("_bubble") as Label3D).visible, "banter bubble shows")
	_pm.set_stance("mira", "stay")
	_check(mira.get_stance() == "stay", "stance set to stay")
	_check(_pm.cycle_stance_all() == "attack", "party command cycles to attack")
	_check(mira.get_stance() == "attack", "companion follows the cycled stance")
	_pm.set_stance("mira", "follow")
	var dmg_before: float = mira.get("damage")
	player.set("gold", 1000)
	_check(_pm.upgrade_gear("mira"), "forge companion gear")
	_check(float(mira.get("damage")) == dmg_before + 2.0 and _pm.gear_level("mira") == 1, "gear raises damage")
	_check(int(player.get("gold")) == 880, "gear costs the forge price")
	_pm.dismiss("mira")
	await _frames(2)
	_check(get_nodes_in_group("companions").is_empty(), "dismiss removes the companion")
	_check((mira_villager as Node3D).visible, "village Mira returns after dismissal")
	# A dismissal is not the end of anyone: they stay recruited and can be
	# called back up from the party page.
	# Mira's whole job is mending the hero mid-fight. Her heal used to sit
	# at the end of the follow branch, which only runs with no enemy in
	# reach — that is, never when the hero is actually being hit.
	_pm.recruit("mira")
	await _frames(2)
	var healer: Node = null
	for c2 in _pm.active_companions():
		if String(c2.get("companion_id")) == "mira":
			healer = c2
	if healer != null:
		healer.set("_heal_cd", 0.0)
		healer.set("_target", player)   # as if mid-fight
		player.set("hp", float(player.get("max_hp")) * 0.2)
		var hurt: float = player.get("hp")
		await _seconds(0.4)
		_check(float(player.get("hp")) > hurt, "Mira mends the hero in a fight")
		healer.set("_target", null)
	player.set("hp", float(player.get("max_hp")))
	_pm.dismiss("mira")
	await _frames(2)
	# Her bolts have to land. They flew a metre above the hit test for
	# the whole game, so the ranged companion dealt no damage at all.
	var bolt_scene: PackedScene = load("res://src/enemy/drowned_husk.tscn")
	var dummy: Node3D = bolt_scene.instantiate()
	dummy.position = Vector3(-12, 0.1, 52)
	current_scene.add_child(dummy)
	dummy.set("lurk_in_place", true)
	await _frames(2)
	var dummy_hp: float = dummy.get("hp")
	# Loaded at runtime: naming the class here would compile it before
	# the autoloads exist, and it reaches for AudioMan.
	var proj_script: GDScript = load("res://src/magic/projectile.gd")
	var bolt: Node3D = proj_script.create("frost_bolt",
		dummy.global_position + Vector3(-4, 0, 0), Vector3(1, 0, 0), 12.0)
	current_scene.add_child(bolt)
	await _seconds(0.8)
	_check(float(dummy.get("hp")) < dummy_hp, "a frost bolt fired from the ground connects")
	dummy.queue_free()
	await _frames(2)
	# A held position has to travel with a teleport, or a companion on
	# STAY walks back toward another region and pins itself to a wall.
	_pm.set_stance("mira", "stay")
	var stander: Node = null
	for c3 in _pm.active_companions():
		if String(c3.get("companion_id")) == "mira":
			stander = c3
	if stander != null:
		_pm.teleport_with(Vector3(0, 0.1, 200))
		await _frames(2)
		var hold: Vector3 = stander.get("_hold_pos")
		_check(hold.distance_to((stander as Node3D).global_position) < 2.0,
			"a companion on STAY holds where the teleport put them")
	_pm.set_stance("mira", "follow")
	_pm.teleport_with(player.global_position)
	await _frames(2)
	_check(_pm.is_recruited("mira") and not _pm.is_active("mira"), "a dismissed companion waits")
	_check(_pm.activate("mira"), "a waiting companion can be called back")
	await _frames(2)
	_check(get_nodes_in_group("companions").size() == 1, "the called companion returns")
	# A full party takes nobody else on the road. recruit() has to say so,
	# or the quest announces a join that never happened.
	_check(_pm.recruit("bram") and _pm.is_active("bram"), "the second slot fills")
	await _frames(2)
	_check(not _pm.recruit("ilsa"), "a full party cannot take a third")
	_check(_pm.is_recruited("ilsa") and not _pm.is_active("ilsa"), "the third waits instead")
	_check(not _pm.activate("ilsa"), "and cannot be called up while the party is full")
	# Bram gives an errand that can still be open when he is recruited.
	# If his village self vanishes, that errand can never be handed in —
	# and Mira's chain behind it dies with it.
	var bram_villager: Node = null
	for v2 in get_nodes_in_group("villagers"):
		if String(v2.get("npc_name")) == "Bram":
			bram_villager = v2
	var qstates: Dictionary = _qm.get("_states")
	qstates["bones_in_the_wild"]["state"] = QuestDB.State.TURNED_IN
	qstates["stock_up"]["state"] = QuestDB.State.AVAILABLE
	_qm.quests_changed.emit()
	await _frames(2)
	_check(bram_villager != null and (bram_villager as Node3D).visible,
		"a recruited giver stays in the square while an errand is open")
	# The other direction — stepping out once there is nothing left to
	# say — is the Mira case checked above.
	qstates["stock_up"]["state"] = QuestDB.State.TURNED_IN
	_qm.quests_changed.emit()
	await _frames(2)
	_pm.dismiss("bram")
	_pm.dismiss("mira")
	_pm.dismiss("ilsa")
	await _frames(2)

	print("== inventory and crafting")
	player.add_item("bone_shard", 6)
	player.add_item("stolen_trinket", 1)
	player.add_item("wisp_essence", 2)
	player.add_item("slime_gel", 1)
	player.set("gold", 500)
	_check(player.has_item("bone_shard", 6), "materials stored")
	_check(not player.craft("elixir"), "cannot craft without reagents")
	var shards_before: int = player.item_count("bone_shard")
	_check(player.craft("bone_charm"), "craft a bone charm")
	_check(player.has_item("bone_charm")
		and player.item_count("bone_shard") == shards_before - 6,
		"crafting consumes reagents")
	_check(int(player.get("gold")) == 420, "crafting charges the fee")
	_check(player.equip_accessory("bone_charm"), "wear the charm")
	_check(is_equal_approx(player.xp_multiplier(), 1.15), "charm boosts XP")
	_check(player.craft("ether") and player.has_item("ether"), "craft an ether")
	player.set("mp", 1.0)
	_check(player.use_item("ether") and float(player.get("mp")) > 20.0, "ether restores MP")
	_check(not player.use_item("ether"), "no ether left to drink")
	_check(player.equip_accessory(""), "remove the charm")
	_check(is_equal_approx(player.xp_multiplier(), 1.0), "XP bonus gone")
	# Taking a charm off has to leave exactly what was there without it.
	# The multiplier used to be folded into the stat, so every level
	# earned while wearing one was shaved on the way off.
	# Swapping a +HP charm on and off must not mint health. Removing it
	# only clamped, which did nothing below the lower ceiling, so every
	# WEAR handed the bonus back — free healing on two taps, forever.
	player.add_item("pearl_pendant", 1)
	player.set("hp", 20.0)
	var hp_before: float = player.get("hp")
	for cycle in 3:
		player.equip_accessory("pearl_pendant")
		player.equip_accessory("")
	_check(is_equal_approx(float(player.get("hp")), hp_before),
		"wearing a charm on and off does not mint health")
	player.set("hp", float(player.get("max_hp")))
	player.add_item("frost_talisman", 1)
	var bare_atk: float = player.get("attack_damage")
	_check(player.equip_accessory("frost_talisman"), "wear the talisman")
	_check(is_equal_approx(player.total_attack(), bare_atk * 1.10),
		"the talisman lifts attack by a tenth")
	player.set("attack_damage", bare_atk + 6.0)  # three levels' worth
	_check(is_equal_approx(player.total_attack(), (bare_atk + 6.0) * 1.10),
		"levels earned while wearing it count in full")
	_check(player.equip_accessory(""), "remove the talisman")
	_check(is_equal_approx(player.total_attack(), bare_atk + 6.0),
		"removing it leaves the levels untouched")
	player.set("attack_damage", bare_atk)
	# A boss drops its trophy once and never comes back, so no two
	# recipes may want the same one: forging the early accessory would
	# destroy the only ingredient for the late one.
	var unique_mats := ["drowned_crown", "frost_shard", "reaver_crest",
		"mire_heart", "hollow_crown"]
	var contested := ""
	for mat: String in unique_mats:
		var wants := 0
		for rid in ItemDB.RECIPES:
			var needs: Dictionary = ItemDB.RECIPES[rid]["needs"]
			if needs.has(mat):
				wants += 1
		if wants > 1:
			contested = mat
	_check(contested == "", "no boss trophy is wanted by two recipes")
	var drops_ok := false
	for e in get_nodes_in_group("skeletons"):
		if e.get("drops") != null and (e.get("drops") as Array).size() >= 2:
			drops_ok = true
			break
	_check(drops_ok, "foes carry drop tables")

	print("== skills")
	_check(int(player.get("skill_points")) >= 1, "level-ups granted skill points")
	var pts: int = player.get("skill_points")
	_check(not player.learn_skill("no_such_skill"), "unknown skill rejected")
	_check(player.learn_skill("swift_blade"), "learn Swift Blade")
	_check(int(player.get("skill_points")) == pts - 1, "learning spends a point")
	_check(player.atb_fill_time() < 1.4, "Swift Blade speeds the ATB gauge")
	player.set("skill_points", 5)
	player.learn_skill("arcane_focus")
	_check(player.spell_cost(10) == 8, "Arcane Focus cuts spell cost")
	player.learn_skill("iron_skin")
	_check(is_equal_approx(player.damage_taken_multiplier(), 0.92), "Iron Skin reduces damage")
	player.learn_skill("twin_slash")
	_check(not player.learn_skill("twin_slash"), "maxed skill cannot be learned again")
	player.set("skills", {})
	player.set("skill_points", 0)
	player.skills_changed.emit()

	print("== save round-trip")
	player.global_position = Vector3(3, 0.1, 5)
	player.set("gold", 1234)
	player.set("potions", 3)
	player.add_potion(0)
	player.add_item("black_pearl", 4)
	player.equip_accessory("bone_charm")
	player.set("skills", {"keen_edge": 2})
	player.set("skill_points", 3)
	_sg.current_slot = 2
	_sg.save_progress(player, 20)
	_check(_sg.has_save(2) and not _sg.has_save(3), "save written to slot 2 only")
	_check(_sg.slot_summary(2).begins_with("Lv ") and _sg.slot_summary(3) == "empty", "slot summaries")
	var d: Dictionary = _sg.load_progress()
	_check(int(d["gold"]) == 1234 and int(d["potions"]) == 3, "save holds gold and potions")
	player.set("gold", 0)
	player.set("potions", 0)
	player.set("items", {})
	player.set("accessory", "")
	player.set("skills", {})
	player.set("skill_points", 0)
	player.global_position = Vector3(20, 0.1, 20)
	_sg.apply_progress(d, player, get_first_node_in_group("skeleton_manager"))
	await _frames(2)
	_check(int(player.get("gold")) == 1234 and int(player.get("potions")) == 3, "load restores gold and potions")
	_check(player.item_count("black_pearl") == 4 and String(player.get("accessory")) == "bone_charm", "load restores items and accessory")
	_check(player.skill_rank("keen_edge") == 2 and int(player.get("skill_points")) == 3, "load restores skills")
	_check(_pm.gear_level("mira") == 1 and _pm.is_recruited("mira"), "load restores party gear")
	_check(player.global_position.distance_to(Vector3(3, 0.1, 5)) < 0.5, "load restores position")
	_check(_qm.get_state("the_frozen_heart") == QuestDB.State.TURNED_IN,
		"load restores quest states")
	# A save taken out in one of the far regions has to come back there,
	# not get bounced to the village square as an off-map position.
	for spot: Array in [[Vector3(-210.0, 0.1, 4.0), "Ashfall Watch"],
			[Vector3(210.0, 0.1, 0.0), "Drowned Chapel"],
			[Vector3(0.0, 0.1, 250.0), "The Sunken Vault"]]:
		player.global_position = spot[0]
		_sg.save_progress(player, 20)
		var far: Dictionary = _sg.load_progress()
		player.global_position = Vector3(0, 0.1, 0)
		_sg.apply_progress(far, player, get_first_node_in_group("skeleton_manager"))
		await _frames(2)
		_check(player.global_position.distance_to(spot[0]) < 0.5,
			"a save in %s comes back there" % String(spot[1]))
		_check(_sg.slot_summary(2).contains(String(spot[1])),
			"the slot says %s" % String(spot[1]))
	player.global_position = Vector3(3, 0.1, 5)
	# Each region keeps its own tally across a save. Storing only the
	# southern one used to hand every other region the south's count.
	var tallies := {}
	for mgr: Node in get_nodes_in_group("foe_spawner"):
		tallies[String(mgr.get("region"))] = int(mgr.get("kills"))
	var marked := {}
	var tally := 3
	for mgr: Node in get_nodes_in_group("foe_spawner"):
		marked[String(mgr.get("region"))] = tally
		mgr.set("kills", tally)
		tally += 4
	_sg.save_progress(player, 20)
	for mgr: Node in get_nodes_in_group("foe_spawner"):
		mgr.set("kills", 0)
	var kd: Dictionary = _sg.load_progress()
	_sg.apply_progress(kd, player, get_first_node_in_group("skeleton_manager"))
	await _frames(2)
	var kills_kept := true
	for mgr: Node in get_nodes_in_group("foe_spawner"):
		if int(mgr.get("kills")) != int(marked[String(mgr.get("region"))]):
			kills_kept = false
	_check(kills_kept and marked.size() > 1, "every region's kill count survives a save")
	for mgr: Node in get_nodes_in_group("foe_spawner"):
		mgr.set("kills", int(tallies.get(String(mgr.get("region")), 0)))
	_sg.delete_save(2)
	_check(not _sg.has_save(2), "erase removes the slot")
	_sg.current_slot = 1

	print("== weather")
	var weather := current_scene.get_node("Weather")
	player.global_position = Vector3(0, 0.1, 5)
	await _seconds(0.3)
	_check(weather.snow_intensity() < 0.1, "no snow in Emberfell")
	player.global_position = Vector3(0, 0.1, -200)
	await _seconds(0.3)
	_check(weather.snow_intensity() > 0.9, "blizzard deep in the north")

	print("== enemy behaviors")
	var bandit_scene: PackedScene = load("res://src/enemy/shadow_bandit.tscn")
	var bandit: Node3D = bandit_scene.instantiate()
	bandit.position = Vector3(-15, 0.1, 50)
	current_scene.add_child(bandit)
	player.global_position = Vector3(-14, 0.1, 50)
	await _seconds(0.3)
	bandit.take_damage(float(bandit.get("max_hp")) * 0.7, player.global_position)
	_check(String(bandit.get("_state")) == "flee", "hurt bandit flees")
	bandit.set("_flee_timer", 0.0)
	await _seconds(0.3)
	_check(String(bandit.get("_state")) != "flee" and bandit.is_enraged(), "bandit regroups and comes back enraged")
	var husk_scene: PackedScene = load("res://src/enemy/drowned_husk.tscn")
	# A husk left on its own sinks where it stands: only the southern shore
	# has black water to wade back to, and its spawner is what says so.
	var sunk: Node3D = husk_scene.instantiate()
	sunk.position = Vector3(-14, 0.1, 58)
	current_scene.add_child(sunk)
	player.global_position = Vector3(-10, 0.1, 50)
	await _seconds(0.3)
	_check(sunk.is_lurking() and absf(sunk.global_position.x + 14.0) < 1.0,
		"a husk away from the shore lurks where it stands")
	sunk.queue_free()
	var husk: Node3D = husk_scene.instantiate()
	husk.position = Vector3(20, 0.1, 55)
	current_scene.add_child(husk)
	husk.set("lurk_in_place", false)
	husk.call("_start_lurking")
	player.global_position = Vector3(-10, 0.1, 50)
	await _seconds(0.3)
	_check(husk.is_lurking() and husk.global_position.x > 24.0, "husk lurks in the shallows")
	player.global_position = husk.global_position + Vector3(-4, 0, 0)
	await _seconds(0.3)
	_check(not husk.is_lurking() and String(husk.get("_state")) != "lurk", "husk bursts out when approached")
	var wisp_script: GDScript = load("res://src/enemy/wisp.gd")
	var wisp: Node3D = wisp_script.new()
	wisp.position = Vector3(21.5, 0.1, 50)  # inside its roam bounds, on the shore
	current_scene.add_child(wisp)
	player.global_position = Vector3(19.5, 0.1, 50)
	await _seconds(0.4)
	_check(wisp.is_luring(), "wisp lures instead of striking at first")
	for foe in [bandit, husk, wisp]:
		foe.queue_free()
	await _frames(2)

	# A corpse must not go on telegraphing a swing it will never make.
	var warn_foe: Node = null
	for n2 in get_nodes_in_group("skeletons"):
		if not n2.is_in_group("boss") and not bool(n2.get("dead")):
			warn_foe = n2
			break
	if warn_foe != null:
		var wl: Label3D = warn_foe.get("_warn_label")
		if wl != null:
			wl.visible = true
			warn_foe.take_damage(99999.0, (warn_foe as Node3D).global_position)
			await _frames(2)
			_check(not wl.visible, "a killed foe drops its telegraph")

	print("== death and respawn")
	player.global_position = Vector3(10, 0.1, 50)
	player.set("gold", 100)
	player.take_damage(99999.0, Vector3(11, 0, 50))
	_check(bool(player.get("dead")), "player dies")
	_check(int(player.get("gold")) == 90, "death costs ten percent gold")
	await _seconds(2.4)
	_check(not bool(player.get("dead")), "player respawns")
	_check(player.global_position.distance_to(Vector3(0, 0.1, 0)) < 1.0, "respawn at the well")
	# The party comes back with the hero, not left fighting a healed boss.
	var strays := 0
	for comp in _pm.active_companions():
		if (comp as Node3D).global_position.distance_to(player.global_position) > 8.0:
			strays += 1
	_check(strays == 0, "companions respawn alongside the hero")
	_check(float(player.get("hp")) == float(player.get("max_hp")), "respawn with full health")

	print("== doors")
	var doors := get_first_node_in_group("doors")
	doors.call("_enter_interior", "market", Vector3(9, 0, -3))
	_check(doors.is_in_interior() and player.global_position.x > 400.0, "enter the market")
	doors.exit_interior()
	_check(not doors.is_in_interior() and player.global_position.x < 400.0, "exit the market")
	# Walking back through the doorway leaves too.
	doors.call("_enter_interior", "house_a", Vector3(-15, 0, 11.5))
	var doorway: Vector3 = player.global_position
	player.global_position = doorway + Vector3(0, 0, -3.0)
	await _seconds(0.2)
	player.global_position = doorway
	await _seconds(0.2)
	_check(not doors.is_in_interior() and player.global_position.x < 400.0, "walking back through the door exits")
	# A player who ends up inside without door state is rescued.
	player.global_position = Vector3(500, 0.1, 0)
	await _seconds(0.2)
	_check(player.global_position.x < 400.0, "stranded-indoors safety returns the player")

	print("== audio regions")
	player.global_position = Vector3(0, 0.1, -100)
	await _seconds(0.5)
	_check(_am.current_region() == "north", "north music past the gate")
	player.global_position = Vector3(0, 0.1, 5)
	await _seconds(0.5)
	_check(_am.current_region() == "village", "village music at home")

	print("== the highlands")
	_check(AshenHighlands.is_in_camp(-210.0, 0.0), "Ashfall Watch sits on the west road")
	_check(not AshenHighlands.is_in_camp(-120.0, 0.0), "the open road is not the camp")
	_check(AshenHighlands.is_in_arena(AshenHighlands.ARENA_CENTER.x, 0.0), "Kael has his own ground")
	var kael: Node = null
	for b in get_nodes_in_group("boss"):
		if String(b.get("boss_id")) == "kael":
			kael = b
	_check(kael != null, "Kael waits in the highlands")
	if kael != null:
		_check(AshenHighlands.is_in_arena((kael as Node3D).global_position.x,
			(kael as Node3D).global_position.z), "Kael stands on the black glass")
	var ilsa_found := false
	for n in get_nodes_in_group("villagers"):
		if String(n.get("npc_name")) == "Ilsa":
			ilsa_found = true
	_check(ilsa_found, "the Warden holds the watchtower")
	_check(QuestDB.get_quest("the_ash_reaver")["giver"] == "Ilsa", "the Warden sends you after Kael")
	_check(ItemDB.RECIPES.has("reavers_mark"), "the forge can work a reaver crest")

	print("== the fen")
	_check(Mirefen.is_on_causeway(120.0, 0.0), "the causeway runs the length of the fen")
	_check(not Mirefen.is_on_causeway(120.0, 14.0), "off the stones is not the causeway")
	_check(Mirefen.is_at_chapel(210.0, 0.0), "the chapel sits on its island")
	_check(Mirefen.is_in_pool(Mirefen.POOL_CENTER.x, 0.0), "Gholl has his pool")
	var gholl: Node = null
	for b2 in get_nodes_in_group("boss"):
		if String(b2.get("boss_id")) == "gholl":
			gholl = b2
	_check(gholl != null, "Gholl waits in the fen")
	if gholl != null:
		_check(Mirefen.is_in_pool((gholl as Node3D).global_position.x,
			(gholl as Node3D).global_position.z), "Gholl stands in the pool")
	var odren_found := false
	for n2 in get_nodes_in_group("villagers"):
		if String(n2.get("npc_name")) == "Odren":
			odren_found = true
	_check(odren_found, "the chapel still has its priest")
	_check(QuestDB.get_quest("the_mire_horror")["giver"] == "Odren", "the priest sends you after Gholl")
	_check(ItemDB.RECIPES.has("drowned_heart"), "the forge can work a mire heart")

	print("== the vault")
	_check(SunkenVault.is_inside(0.0, 250.0), "the gallery runs under the village")
	_check(not SunkenVault.is_inside(0.0, 100.0), "the world above is not the vault")
	_check(SunkenVault.is_inside(SunkenVault.chamber_center(0).x,
		SunkenVault.chamber_center(0).z), "the burial chambers open off the gallery")
	var crown: Node = null
	for b3 in get_nodes_in_group("boss"):
		if String(b3.get("boss_id")) == "hollow":
			crown = b3
	_check(crown != null, "the Hollow Crown sits at the end")
	if crown != null:
		_check((crown as Node3D).global_position.z > SunkenVault.THRONE_Z0,
			"the Crown keeps to its throne room")
	var alwin_found := false
	for n3 in get_nodes_in_group("villagers"):
		if String(n3.get("npc_name")) == "Keeper Alwin":
			alwin_found = true
	_check(alwin_found, "the keeper is still lighting the lamps")
	_check(QuestDB.get_quest("the_hollow_crown")["giver"] == "Keeper Alwin",
		"the keeper sends you to the throne")
	_check(ItemDB.RECIPES.has("kings_ruin"), "the forge can work the crown")
	# The whole main story, chapter by chapter.
	var chapters := ["the_drowned_tyrant", "the_frozen_heart", "the_ash_reaver",
		"the_mire_horror", "the_hollow_crown"]
	var chain_ok := true
	for qid in chapters:
		if QuestDB.get_quest(qid).is_empty():
			chain_ok = false
	_check(chain_ok, "five chapters, five guardians")
	# Loaded at runtime: story_intro.gd touches an autoload, and a -s
	# script that names it at compile time drags the whole UI in early.
	var story: GDScript = load("res://src/ui/story_intro.gd")
	_check(String(story.interlude_banner("the_ash_reaver")) != "",
		"felling Kael plays an interlude")
	_check(String(story.interlude_banner("the_mire_horror")) != "",
		"felling Gholl opens the well")

	print("== quests: chapters three to five")
	# Bank kills straight on a region's spawner rather than grinding a
	# whole population down in a headless run.
	var bank := func(group: String, n: int) -> void:
		var mgr := get_first_node_in_group(group)
		mgr.set("kills", int(mgr.get("kills")) + n)
		mgr.kills_changed.emit(int(mgr.get("kills")))
	var slay := func(want: String) -> bool:
		for b4 in get_nodes_in_group("boss"):
			if String(b4.get("boss_id")) == want:
				b4.take_damage(999999.0, Vector3.ZERO)
				return true
		return false
	# Chapter three: the road west, the Warden, and Kael.
	_qm.accept_quest("the_western_road")
	_qm.on_dialogue_closed("Old Fen")
	_qm.turn_in_quest("the_western_road")
	_qm.accept_quest("ashfall_watch")
	player.global_position = Vector3(-210, 0.1, 0)
	await _seconds(0.5)
	_check(_qm.get_state("ashfall_watch") == QuestDB.State.COMPLETE,
		"reaching Ashfall Watch completes the quest")
	_qm.turn_in_quest("ashfall_watch")
	_qm.accept_quest("the_reavers_toll")
	bank.call("west_manager", 14)
	await _frames(2)
	_check(_qm.get_state("the_reavers_toll") == QuestDB.State.COMPLETE,
		"fourteen reavers finish the toll")
	_qm.turn_in_quest("the_reavers_toll")
	_qm.accept_quest("the_ash_reaver")
	_check(slay.call("kael"), "Kael is in the world")
	await _frames(3)
	_check(_qm.get_state("the_ash_reaver") == QuestDB.State.COMPLETE,
		"Kael's fall completes the chapter")
	_qm.turn_in_quest("the_ash_reaver")
	await _frames(3)
	_check(_clear_story_card(), "chapter three ends on a story card")
	_check(_pm.is_recruited("ilsa"), "the Warden joins the party")
	_check(_qm.region_unlocked(Regions.EAST), "Kael's fall opens the fen")
	# Chapter four: the causeway, the chapel, and Gholl.
	_qm.accept_quest("the_drowned_road")
	_qm.on_dialogue_closed("Old Fen")
	_qm.turn_in_quest("the_drowned_road")
	_qm.accept_quest("into_the_mirefen")
	player.global_position = Vector3(210, 0.1, 0)
	await _seconds(0.5)
	_check(_qm.get_state("into_the_mirefen") == QuestDB.State.COMPLETE,
		"reaching the chapel completes the quest")
	_qm.turn_in_quest("into_the_mirefen")
	_qm.accept_quest("the_rotting_tide")
	bank.call("east_manager", 16)
	await _frames(2)
	_qm.turn_in_quest("the_rotting_tide")
	_qm.accept_quest("the_mire_horror")
	_check(slay.call("gholl"), "Gholl is in the world")
	await _frames(3)
	_qm.turn_in_quest("the_mire_horror")
	await _frames(3)
	_check(_clear_story_card(), "chapter four ends on a story card")
	_check(_qm.region_unlocked(Regions.DEEP), "Gholl's fall uncaps the well")
	# Chapter five: down the well.
	_qm.accept_quest("the_well_opens")
	_qm.on_dialogue_closed("Old Fen")
	_qm.turn_in_quest("the_well_opens")
	_qm.accept_quest("the_descent")
	player.global_position = SunkenVault.ENTRY
	await _seconds(0.5)
	_check(_qm.get_state("the_descent") == QuestDB.State.COMPLETE,
		"climbing down completes the descent")
	_qm.turn_in_quest("the_descent")
	_qm.accept_quest("bones_of_the_vault")
	bank.call("deep_manager", 18)
	await _frames(2)
	_qm.turn_in_quest("bones_of_the_vault")
	_qm.accept_quest("the_hollow_crown")
	_check(slay.call("hollow"), "the Hollow Crown is on its throne")
	await _frames(3)
	_check(_qm.get_state("the_hollow_crown") == QuestDB.State.COMPLETE,
		"the Crown's fall completes the last quest")
	_qm.turn_in_quest("the_hollow_crown")
	await _frames(3)
	_check(_clear_story_card(), "the last chapter ends on the ending")
	_check(_qm.is_story_complete(), "the story ends under the well")
	player.global_position = Vector3(0, 0.1, 5)
	await _seconds(0.4)

	print("== regions")
	_check(Regions.at(0, 0) == Regions.TOWN, "the centre is Emberfell")
	_check(Regions.at(0, 50) == Regions.SOUTH, "south past the wall")
	_check(Regions.at(0, -100) == Regions.NORTH, "north past the gate")
	_check(Regions.at(-120, 0) == Regions.WEST, "west past the gate")
	_check(Regions.at(120, 0) == Regions.EAST, "east past the gate")
	_check(Regions.at(0, 250) == Regions.DEEP, "the vault lies below")
	_check(Regions.at(520, 0) == Regions.TOWN, "interiors count as town")
	_qm.reset()
	await _frames(2)
	_check(_qm.region_unlocked(Regions.SOUTH), "the south is open from the start")
	_check(not _qm.region_unlocked(Regions.NORTH), "the north is sealed until Vorgath falls")
	_check(not _qm.region_unlocked(Regions.DEEP), "the well is capped")
	var gates := get_first_node_in_group("region_gates")
	_check(gates != null, "the village gates exist")
	_check(not gates.is_open(Regions.NORTH), "the north gate is barred")
	var south_mgr := get_first_node_in_group("skeleton_manager")
	var north_mgr := get_first_node_in_group("north_manager")
	player.global_position = Vector3(0, 0.1, 50)
	await _seconds(0.8)
	_check(bool(south_mgr.get("awake")), "southern foes walk while the hero is south")
	_check(not bool(north_mgr.get("awake")), "northern foes sleep while the hero is south")
	_qm.mark_boss_slain("vorgath")
	await _frames(2)
	_check(_qm.region_unlocked(Regions.NORTH), "Vorgath's fall opens the north")
	_check(gates.is_open(Regions.NORTH), "the north gate rises")
	_check(not _qm.region_unlocked(Regions.WEST), "the west waits on Morvain")
	var kept: int = int(north_mgr.get("kills"))
	player.global_position = Vector3(0, 0.1, -120)
	await _seconds(0.8)
	_check(bool(north_mgr.get("awake")), "northern foes walk while the hero is north")
	_check(not bool(south_mgr.get("awake")), "southern foes sleep while the hero is north")
	_check(int(north_mgr.get("kills")) == kept, "kill counts survive a region sleeping")
	# A barred gate is a wall, not a sign: walk into it and you stop.
	player.global_position = Vector3(-27.0, 0.1, 0.0)
	await _frames(3)
	_check(player.test_move(player.global_transform, Vector3(-6.0, 0.0, 0.0)),
		"the barred west gate blocks the road")
	_qm.mark_boss_slain("morvain")
	await _frames(3)
	_check(_qm.region_unlocked(Regions.WEST), "Morvain's fall opens the west")
	_check(not player.test_move(player.global_transform, Vector3(-6.0, 0.0, 0.0)),
		"the raised west gate lets the hero through")
	# The well: a capped shaft while anything still guards it, and the way
	# down once nothing does.
	var shaft := get_first_node_in_group("doors")
	var well_mouth: Vector3 = VillageLayout.WELL_POS + Vector3(0, 0.1, 2.2)
	player.global_position = well_mouth
	await _seconds(0.4)
	shaft.call("_on_enter_pressed")
	await _frames(2)
	_check(Regions.at_pos(player.global_position) == Regions.TOWN,
		"the capped well refuses the descent")
	_qm.mark_boss_slain("kael")
	_qm.mark_boss_slain("gholl")
	await _frames(3)
	player.global_position = well_mouth
	await _seconds(0.4)
	shaft.call("_on_enter_pressed")
	await _frames(2)
	_check(player.global_position.distance_to(SunkenVault.ENTRY) < 2.0,
		"the open well drops the hero into the vault")
	player.global_position = SunkenVault.ENTRY + Vector3(0, 0, -3.2)
	await _seconds(0.4)
	shaft.call("_on_enter_pressed")
	await _frames(2)
	_check(Regions.at_pos(player.global_position) == Regions.TOWN,
		"the stair climbs back to Emberfell")
	_check(_qm.region_unlocked(Regions.NORTH), "regions already opened stay open")

	# Empty the world before quitting: monsters still ticking while the
	# engine tears its scripts down print noise, not information.
	for mgr in get_nodes_in_group("foe_spawner"):
		mgr.call("sleep")
	for foe in get_nodes_in_group("skeletons"):
		foe.queue_free()
	await _frames(2)

	print("")
	print("%d passed, %d failed" % [_passes, _fails])
	if _fails > 0:
		printerr("TESTS FAILED")
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)

## The bosses record their opening numbers under short keys; this maps
## each back to the property it came from.
func _stat_for(key: String) -> String:
	match key:
		"dmg":
			return "attack_damage"
		"cd":
			return "attack_cooldown"
		"chase":
			return "chase_speed"
	return key
