class_name SaveGame
## Static save/load helpers. Progress + settings live in one ConfigFile
## at user:// (persisted to IndexedDB on web).

const SAVE_PATH := "user://savegame.cfg"

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

## Write progress (and keep any stored settings).
static func save_progress(player: Node, kills: int) -> void:
	var cfg := ConfigFile.new()
	if has_save():
		cfg.load(SAVE_PATH)
	cfg.set_value("progress", "level", player.get("level"))
	cfg.set_value("progress", "xp", player.get("xp"))
	cfg.set_value("progress", "max_hp", player.get("max_hp"))
	cfg.set_value("progress", "max_mp", player.get("max_mp"))
	cfg.set_value("progress", "selected_spell", player.get("selected_spell"))
	cfg.set_value("progress", "attack", player.get("attack_damage"))
	cfg.set_value("progress", "kills", kills)
	cfg.set_value("progress", "deaths", player.get("deaths"))
	cfg.set_value("progress", "potions", player.get("potions"))
	cfg.set_value("progress", "gold", player.get("gold"))
	cfg.set_value("progress", "cape_level", player.get("cape_level"))
	cfg.set_value("progress", "hood_level", player.get("hood_level"))
	cfg.set_value("progress", "weapon_level", player.get("weapon_level"))
	cfg.set_value("progress", "play_time", player.get("play_time"))
	var pos: Vector3 = player.global_position
	cfg.set_value("progress", "pos", [pos.x, pos.y, pos.z])
	cfg.set_value("progress", "quests", QuestMan.get_save_data())
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
	if has_save():
		cfg.load(SAVE_PATH)
	cfg.set_value("settings", "music", AudioMan.music_enabled)
	cfg.set_value("settings", "sfx", AudioMan.sfx_enabled)
	cfg.save(SAVE_PATH)

static func load_progress() -> Dictionary:
	var d := {}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return d
	for key in ["level", "xp", "max_hp", "max_mp", "selected_spell", "attack", "kills", "deaths", "potions", "gold", "cape_level", "hood_level", "weapon_level", "play_time"]:
		d[key] = cfg.get_value("progress", key, null)
	var pos: Array = cfg.get_value("progress", "pos", [])
	d["pos"] = Vector3(pos[0], pos[1], pos[2]) if pos.size() == 3 else Vector3.ZERO
	d["quests"] = cfg.get_value("progress", "quests", {})
	return d

## Apply a loaded progress dict to the live player + skeleton manager.
static func apply_progress(d: Dictionary, player: Node, mgr: Node) -> void:
	if d.is_empty():
		return
	player.set("level", int(d["level"]))
	player.set("xp", int(d["xp"]))
	player.set("max_hp", float(d["max_hp"]))
	player.set("max_mp", float(d["max_mp"]) if d["max_mp"] != null else 30.0)
	player.set("mp", float(d["max_mp"]) if d["max_mp"] != null else 30.0)
	if d["selected_spell"] != null:
		player.set("selected_spell", String(d["selected_spell"]))
	player.set("attack_damage", float(d["attack"]))
	player.set("hp", float(d["max_hp"]))
	player.set("deaths", int(d["deaths"]))
	player.set("potions", int(d["potions"]) if d["potions"] != null else 0)
	player.set("gold", int(d["gold"]) if d["gold"] != null else 0)
	if player.has_method("load_equipment"):
		player.load_equipment(
			int(d["cape_level"]) if d["cape_level"] != null else 0,
			int(d["hood_level"]) if d["hood_level"] != null else 0,
			int(d["weapon_level"]) if d["weapon_level"] != null else 0
		)
	player.set("play_time", float(d["play_time"]))
	player.global_position = d["pos"]
	if mgr != null:
		mgr.set("kills", int(d["kills"]))
		if mgr.has_signal("kills_changed"):
			mgr.emit_signal("kills_changed", int(d["kills"]))
	var quests: Dictionary = d.get("quests", {})
	if not quests.is_empty():
		QuestMan.load_save_data(quests)
