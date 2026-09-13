class_name SaveGame
## Static save/load helpers. Progress + settings live in one ConfigFile
## at user:// (persisted to IndexedDB on web).

const SAVE_PATH := "user://savegame.cfg"

## True when the file holds progress (settings alone don't count).
static func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var cfg := ConfigFile.new()
	return cfg.load(SAVE_PATH) == OK and cfg.has_section("progress")

## Erase progress but keep the settings section.
static func delete_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section("progress"):
		cfg.erase_section("progress")
	cfg.save(SAVE_PATH)

## Write progress (and keep any stored settings).
static func save_progress(player: Node, kills: int) -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(SAVE_PATH):
		cfg.load(SAVE_PATH)
	cfg.set_value("progress", "level", player.get("level"))
	cfg.set_value("progress", "xp", player.get("xp"))
	cfg.set_value("progress", "max_hp", player.get("max_hp"))
	cfg.set_value("progress", "max_mp", player.get("max_mp"))
	cfg.set_value("progress", "selected_spell", player.get("selected_spell"))
	cfg.set_value("progress", "bonus_spells", player.get("bonus_spells"))
	cfg.set_value("progress", "attack", player.get("attack_damage"))
	cfg.set_value("progress", "kills", kills)
	cfg.set_value("progress", "deaths", player.get("deaths"))
	cfg.set_value("progress", "potions", player.get("potions"))
	cfg.set_value("progress", "gold", player.get("gold"))
	cfg.set_value("progress", "cape_level", player.get("cape_level"))
	cfg.set_value("progress", "hood_level", player.get("hood_level"))
	cfg.set_value("progress", "weapon_level", player.get("weapon_level"))
	cfg.set_value("progress", "play_time", player.get("play_time"))
	# Never save a position inside a building: interiors live off-map and
	# the door state isn't saved, so a load there would trap the player.
	var pos: Vector3 = player.global_position
	var doors := player.get_tree().get_first_node_in_group("doors")
	if doors != null and doors.has_method("is_in_interior") and doors.is_in_interior():
		pos = doors.get_return_pos()
	cfg.set_value("progress", "pos", [pos.x, pos.y, pos.z])
	cfg.set_value("progress", "quests", QuestMan.get_save_data())
	cfg.set_value("progress", "party", PartyMan.get_save_data())
	cfg.set_value("progress", "saved_at", Time.get_datetime_string_from_system())
	cfg.save(SAVE_PATH)

static func last_saved() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return ""
	return str(cfg.get_value("progress", "saved_at", ""))

## Write settings (and keep any stored progress).
static func save_settings() -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(SAVE_PATH):
		cfg.load(SAVE_PATH)
	cfg.set_value("settings", "music", AudioMan.music_enabled)
	cfg.set_value("settings", "sfx", AudioMan.sfx_enabled)
	cfg.save(SAVE_PATH)

static func load_progress() -> Dictionary:
	var d := {}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section("progress"):
		return d
	for key in ["level", "xp", "max_hp", "max_mp", "selected_spell", "bonus_spells", "attack", "kills", "deaths", "potions", "gold", "cape_level", "hood_level", "weapon_level", "play_time"]:
		d[key] = cfg.get_value("progress", key, null)
	var pos: Array = cfg.get_value("progress", "pos", [])
	d["pos"] = Vector3(pos[0], pos[1], pos[2]) if pos.size() == 3 else Vector3.ZERO
	d["quests"] = cfg.get_value("progress", "quests", {})
	d["party"] = cfg.get_value("progress", "party", {})
	return d

## Apply a loaded progress dict to the live player + skeleton manager.
static func apply_progress(d: Dictionary, player: Node, mgr: Node) -> void:
	if d.is_empty():
		return
	player.set("level", int(d["level"]) if d["level"] != null else 1)
	player.set("xp", int(d["xp"]) if d["xp"] != null else 0)
	player.set("max_hp", float(d["max_hp"]) if d["max_hp"] != null else 100.0)
	player.set("max_mp", float(d["max_mp"]) if d["max_mp"] != null else 30.0)
	player.set("mp", float(d["max_mp"]) if d["max_mp"] != null else 30.0)
	if d["selected_spell"] != null:
		player.set("selected_spell", String(d["selected_spell"]))
	if d.get("bonus_spells") != null:
		var bs: Array = []
		for s in d["bonus_spells"]:
			bs.append(String(s))
		player.set("bonus_spells", bs)
	player.set("attack_damage", float(d["attack"]) if d["attack"] != null else 14.0)
	player.set("hp", player.get("max_hp"))
	player.set("deaths", int(d["deaths"]) if d["deaths"] != null else 0)
	player.set("potions", int(d["potions"]) if d["potions"] != null else 0)
	player.set("gold", int(d["gold"]) if d["gold"] != null else 0)
	if player.has_method("load_equipment"):
		player.load_equipment(
			int(d["cape_level"]) if d["cape_level"] != null else 0,
			int(d["hood_level"]) if d["hood_level"] != null else 0,
			int(d["weapon_level"]) if d["weapon_level"] != null else 0
		)
	player.set("play_time", float(d["play_time"]) if d["play_time"] != null else 0.0)
	var pos: Vector3 = d["pos"]
	if absf(pos.x) > 100.0 or absf(pos.z) > 100.0:
		pos = Vector3(0, 0.1, 0)  # old save from inside a building
	player.global_position = pos
	if mgr != null:
		mgr.set("kills", int(d["kills"]) if d["kills"] != null else 0)
		if mgr.has_signal("kills_changed"):
			mgr.emit_signal("kills_changed", int(mgr.get("kills")))
		if mgr.has_method("rescale_all"):
			mgr.rescale_all(int(player.get("level")))
	var quests: Dictionary = d.get("quests", {})
	if not quests.is_empty():
		QuestMan.load_save_data(quests)
	var party: Dictionary = d.get("party", {})
	if not party.is_empty():
		PartyMan.load_save_data(party)
	# Fields were written directly; tell the HUD and menus about them.
	if player.has_method("emit_all_stats"):
		player.emit_all_stats()
