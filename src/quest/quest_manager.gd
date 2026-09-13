extends Node
## QuestMan (autoload): tracks quest states, objective progress, and rewards.
## Watches player/skeleton signals, drives quest dialogue, the HUD tracker,
## villager "!" markers, and the QUESTS menu tab.

signal quests_changed
signal quest_accepted(quest_id: String)
signal quest_turned_in(quest_id: String)

var _states := {} # quest_id -> {"state": int, "kills_at_accept": int}
var _talked_to := {} # npc_name -> true
var _bosses_slain := {} # boss_id -> true (e.g. "vorgath", "morvain")
var _reach_timer := 0.0
var _player: Node = null
var _skel_mgr: Node = null
var _hud: Node = null

func _ready() -> void:
	# Initialize quest states immediately (villagers query markers in _ready).
	for qid in QuestDB.quest_ids():
		_states[qid] = {"state": QuestDB.State.LOCKED, "kills_at_accept": 0}
	call_deferred("_late_setup")

func _late_setup() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_skel_mgr = get_tree().get_first_node_in_group("skeleton_manager")
	_hud = get_tree().get_first_node_in_group("hud")
	if _skel_mgr != null and _skel_mgr.has_signal("kills_changed"):
		_skel_mgr.kills_changed.connect(_on_kills_changed)
	# Northern wilds kills count too.
	var north_mgr := get_tree().get_first_node_in_group("north_manager")
	if north_mgr != null and north_mgr.has_signal("kills_changed"):
		north_mgr.kills_changed.connect(_on_kills_changed)
	if _player != null:
		if _player.has_signal("potions_changed"):
			_player.potions_changed.connect(_on_potions_changed)
		if _player.has_signal("leveled_up"):
			_player.leveled_up.connect(_on_leveled_up)
	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null and boss.has_signal("died"):
		boss.died.connect(_on_boss_died)
	# Connect to every other boss in the group (Morvain, ...).
	# died(self) emits the boss as its argument.
	for b in get_tree().get_nodes_in_group("boss"):
		if b != boss and b.has_signal("died"):
			b.died.connect(_on_boss_died)
	quests_changed.emit()

func _on_boss_died(boss: Node) -> void:
	var boss_id := "vorgath"
	if boss != null and boss.get("boss_id") != null:
		boss_id = String(boss.get("boss_id"))
	_bosses_slain[boss_id] = true
	_check_completion()

func _process(delta: float) -> void:
	# Poll "reach" objectives a few times per second.
	_reach_timer += delta
	if _reach_timer < 0.25:
		return
	_reach_timer = 0.0
	if _player == null:
		return
	var any_reach := false
	for qid in QuestDB.quest_ids():
		if int(_states[qid]["state"]) == QuestDB.State.ACTIVE \
				and String(QuestDB.get_quest(qid)["objective_type"]) == "reach":
			any_reach = true
			break
	if any_reach:
		_check_completion()

# ---------------------------------------------------------------- state

## Dynamic state: prereqs gate AVAILABLE; stored state otherwise.
func get_state(quest_id: String) -> int:
	var stored: int = int(_states[quest_id]["state"])
	if stored == QuestDB.State.ACTIVE or stored == QuestDB.State.COMPLETE \
			or stored == QuestDB.State.TURNED_IN:
		return stored
	var q := QuestDB.get_quest(quest_id)
	var prereq := String(q.get("prereq", ""))
	if prereq == "" or get_state(prereq) == QuestDB.State.TURNED_IN:
		return QuestDB.State.AVAILABLE
	return QuestDB.State.LOCKED

## The most relevant quest for an NPC: turn-in first, then active
## reminder, then a fresh offer. Turned-in quests are skipped so chains
## across the same giver (Old Fen) advance properly.
func quest_by_giver(npc_name: String) -> Dictionary:
	var offer := {}
	for qid in QuestDB.quest_ids():
		var q := QuestDB.get_quest(qid)
		if String(q["giver"]) != npc_name:
			continue
		match get_state(qid):
			QuestDB.State.COMPLETE:
				return q
			QuestDB.State.ACTIVE:
				return q
			QuestDB.State.AVAILABLE:
				if offer.is_empty():
					offer = q
	return offer

func marker_for(npc_name: String) -> String:
	var q := quest_by_giver(npc_name)
	if q.is_empty():
		return ""
	match get_state(String(q["id"])):
		QuestDB.State.AVAILABLE:
			return "!"
		QuestDB.State.COMPLETE:
			return "?"
	return ""

# ---------------------------------------------------------------- objectives

func _kills() -> int:
	# Aggregate both wilderness managers: southern + northern kills.
	var total := 0
	if _skel_mgr != null:
		total += int(_skel_mgr.get("kills"))
	var north_mgr := get_tree().get_first_node_in_group("north_manager")
	if north_mgr != null:
		total += int(north_mgr.get("kills"))
	return total

func objective_progress(quest_id: String) -> int:
	var q := QuestDB.get_quest(quest_id)
	match String(q["objective_type"]):
		"kill":
			return _kills() - int(_states[quest_id]["kills_at_accept"])
		"collect":
			return int(_player.get("potions")) if _player != null else 0
		"level":
			return int(_player.get("level")) if _player != null else 0
		"talk":
			return 1 if _talked_to.has(String(q["objective_target"])) else 0
		"reach":
			if _player == null:
				return 0
			var t: Array = q["objective_target"]
			var pp: Vector3 = _player.global_position
			var d := Vector2(pp.x - float(t[0]), pp.z - float(t[1])).length()
			return 1 if d <= float(t[2]) else 0
		"bosskill":
			var boss_id := String(q.get("boss_id", "vorgath"))
			return 1 if bool(_bosses_slain.get(boss_id, false)) else 0
	return 0

func objective_target(quest_id: String) -> int:
	var q := QuestDB.get_quest(quest_id)
	if String(q["objective_type"]) in ["talk", "reach", "bosskill"]:
		return 1
	return int(q["objective_target"])

func objective_text(quest_id: String) -> String:
	var q := QuestDB.get_quest(quest_id)
	var target := objective_target(quest_id)
	var prog := mini(objective_progress(quest_id), target)
	if String(q["objective_type"]) in ["talk", "reach", "bosskill"]:
		return String(q["objective_text"])
	return "%s (%d/%d)" % [String(q["objective_text"]), prog, target]

func _check_completion() -> void:
	var changed := false
	for qid in QuestDB.quest_ids():
		if int(_states[qid]["state"]) != QuestDB.State.ACTIVE:
			continue
		if objective_progress(qid) >= objective_target(qid):
			_states[qid]["state"] = QuestDB.State.COMPLETE
			_announce("QUEST COMPLETE: %s" % String(QuestDB.get_quest(qid)["title"]))
			AudioMan.play("levelup", 1.0, 0.0)
			changed = true
	if changed:
		quests_changed.emit()

func _on_kills_changed(_count: int) -> void:
	_check_completion()

func _on_potions_changed(_count: int) -> void:
	_check_completion()

func _on_leveled_up(_new_level: int) -> void:
	_check_completion()

## Called by dialogue_ui when any NPC dialogue closes.
func on_dialogue_closed(npc_name: String) -> void:
	_talked_to[npc_name] = true
	_check_completion()

# ---------------------------------------------------------------- accept / turn in

func accept_quest(quest_id: String, via_dialogue: bool = false) -> void:
	if get_state(quest_id) != QuestDB.State.AVAILABLE:
		return
	_states[quest_id]["state"] = QuestDB.State.ACTIVE
	_states[quest_id]["kills_at_accept"] = _kills()
	# Talk quests require visiting after acceptance. If the player accepted
	# during a conversation with the giver and the target IS the giver,
	# that conversation counts as the talk. Auto-accepts (intro, etc.)
	# never count — the player still has to go talk to them.
	var q := QuestDB.get_quest(quest_id)
	if String(q["objective_type"]) == "talk":
		var tgt := String(q["objective_target"])
		if tgt == String(q["giver"]) and via_dialogue:
			_talked_to[tgt] = true
		else:
			_talked_to.erase(tgt)
	_announce("QUEST ACCEPTED: %s" % String(q["title"]))
	AudioMan.play("click", 1.0, 0.0)
	quest_accepted.emit(quest_id)
	_check_completion()
	quests_changed.emit()

func turn_in_quest(quest_id: String) -> void:
	if int(_states[quest_id]["state"]) != QuestDB.State.COMPLETE:
		return
	var q := QuestDB.get_quest(quest_id)
	_states[quest_id]["state"] = QuestDB.State.TURNED_IN
	if _player != null:
		_player.add_gold(int(q["reward_gold"]))
		_player.gain_xp(int(q["reward_xp"]))
		# Quest spell rewards (e.g. Glacial Spike from The Frozen Heart).
		var rspell := String(q.get("reward_spell", ""))
		if rspell != "" and _player.has_method("unlock_spell"):
			_player.unlock_spell(rspell)
			var sinfo := Spells.get_info(rspell)
			_announce("SPELL LEARNED: %s" % String(sinfo.get("name", rspell)))
			AudioMan.play("levelup", 1.0, -2.0)
		# Quest companion rewards (recruitment).
		var rcomp := String(q.get("reward_companion", ""))
		if rcomp != "":
			if PartyMan.recruit(rcomp):
				var cinfo := PartyMan.get_info(rcomp)
				_announce("%s JOINED THE PARTY!" % String(cinfo.get("name", rcomp)).to_upper())
				AudioMan.play("levelup", 1.0, -2.0)
	_announce("QUEST COMPLETE: %s (+%dG)" % [String(q["title"]), int(q["reward_gold"])])
	AudioMan.play("levelup", 1.0, -4.0)
	quest_turned_in.emit(quest_id)
	quests_changed.emit()

func _announce(text: String) -> void:
	if _hud != null and _hud.has_method("announce"):
		_hud.announce(text)

# ---------------------------------------------------------------- dialogue

## Contextual dialogue for an NPC: quest offer / turn-in / reminder / fallback.
## Returns {"lines": [...], "offer": quest_id or "", "turnin": quest_id or ""}.
func get_talk(npc_name: String, fallback_lines: Array) -> Dictionary:
	var q := quest_by_giver(npc_name)
	if q.is_empty():
		return {"lines": fallback_lines, "offer": "", "turnin": ""}
	var qid := String(q["id"])
	match get_state(qid):
		QuestDB.State.AVAILABLE:
			return {"lines": q["offer"], "offer": qid, "turnin": ""}
		QuestDB.State.COMPLETE:
			return {"lines": q["complete_lines"], "offer": "", "turnin": qid}
		QuestDB.State.ACTIVE:
			var lines: Array = (q["reminder"] as Array).duplicate()
			lines.append("Progress: %s" % objective_text(qid))
			return {"lines": lines, "offer": "", "turnin": ""}
	return {"lines": fallback_lines, "offer": "", "turnin": ""}

# ---------------------------------------------------------------- HUD + menu

## One-line tracker for the HUD: first active quest + objective.
func tracker_text() -> String:
	for qid in QuestDB.quest_ids():
		if int(_states[qid]["state"]) == QuestDB.State.ACTIVE:
			var q := QuestDB.get_quest(qid)
			return "%s: %s" % [String(q["title"]), objective_text(qid)]
	return ""

# ---------------------------------------------------------------- save

func get_save_data() -> Dictionary:
	var states := {}
	for qid in _states:
		states[qid] = {
			"state": int(_states[qid]["state"]),
			"kills_at_accept": int(_states[qid]["kills_at_accept"]),
		}
	return {"states": states, "talked_to": _talked_to.keys(),
		"bosses_slain": _bosses_slain}

func load_save_data(d: Dictionary) -> void:
	_states.clear()
	var states: Dictionary = d.get("states", {})
	for qid in QuestDB.quest_ids():
		if states.has(qid):
			_states[qid] = {
				"state": int(states[qid].get("state", QuestDB.State.LOCKED)),
				"kills_at_accept": int(states[qid].get("kills_at_accept", 0)),
			}
		else:
			_states[qid] = {"state": QuestDB.State.LOCKED, "kills_at_accept": 0}
	_talked_to.clear()
	for n in d.get("talked_to", []):
		_talked_to[String(n)] = true
	_bosses_slain.clear()
	# Migrate old saves: "boss_slain" meant Vorgath.
	if bool(d.get("boss_slain", false)):
		_bosses_slain["vorgath"] = true
	for bid in d.get("bosses_slain", {}):
		if bool(d["bosses_slain"][bid]):
			_bosses_slain[String(bid)] = true
	if not _bosses_slain.is_empty():
		# Slain bosses stay dead: remove them from the world.
		for boss in get_tree().get_nodes_in_group("boss"):
			var bid := "vorgath"
			if boss.get("boss_id") != null:
				bid = String(boss.get("boss_id"))
			if _bosses_slain.has(bid):
				boss.queue_free()
	quests_changed.emit()
