class_name SaveGame
## Static save/load helpers. Three progress slots at user://savegame_N.cfg
## (persisted to IndexedDB on web); settings live in user://settings.cfg.
## The pre-slot file user://savegame.cfg is migrated into slot 1 once.

const SLOTS := 3
const SETTINGS_PATH := "user://settings.cfg"
const LEGACY_PATH := "user://savegame.cfg"
# Kept for old callers; points at the legacy file (settings fallback).
const SAVE_PATH := LEGACY_PATH

## The slot the running game saves to (autosave included).
static var current_slot := 1

static func slot_path(slot: int) -> String:
	return "user://savegame_%d.cfg" % clampi(slot, 1, SLOTS)

## One-time move of the old single save into slot 1 and settings.cfg.
static func migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_PATH) != OK:
		return
	if cfg.has_section("progress") and not FileAccess.file_exists(slot_path(1)):
		var out := ConfigFile.new()
		for key in cfg.get_section_keys("progress"):
			out.set_value("progress", key, cfg.get_value("progress", key))
		out.save(slot_path(1))
	if cfg.has_section("settings") and not FileAccess.file_exists(SETTINGS_PATH):
		var sett := ConfigFile.new()
		for key in cfg.get_section_keys("settings"):
			sett.set_value("settings", key, cfg.get_value("settings", key))
		sett.save(SETTINGS_PATH)
	DirAccess.remove_absolute(LEGACY_PATH)

## True when the slot holds progress.
static func has_save(slot := current_slot) -> bool:
	migrate_legacy()
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	return cfg.load(path) == OK and cfg.has_section("progress")

static func any_save() -> bool:
	for i in range(1, SLOTS + 1):
		if has_save(i):
			return true
	return false

## Erase a slot's progress.
static func delete_save(slot := current_slot) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## Write progress to a slot.
static func save_progress(player: Node, kills: int, slot := current_slot) -> void:
	var cfg := ConfigFile.new()
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
	cfg.set_value("progress", "items", player.get("items"))
	cfg.set_value("progress", "accessory", player.get("accessory"))
	cfg.set_value("progress", "skills", player.get("skills"))
	cfg.set_value("progress", "skill_points", player.get("skill_points"))
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
	cfg.set_value("progress", "region", _region_name(pos))
	cfg.save(slot_path(slot))

static func _region_name(pos: Vector3) -> String:
	if pos.z < -270.0:
		return "Frozen Arena"
	if pos.z < -230.0:
		return "Grimholt"
	if pos.z < -30.0:
		return "Northern wilds"
	if pos.x > 24.0 and pos.z > 40.0:
		return "Black water"
	if pos.z > 30.0:
		return "Southern wilds"
	return "Emberfell"

static func last_saved(slot := current_slot) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return ""
	return str(cfg.get_value("progress", "saved_at", ""))

## Short line for slot pickers: "Lv 7 · 1,240 G · 0:42 · Grimholt".
static func slot_summary(slot: int) -> String:
	if not has_save(slot):
		return "empty"
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return "empty"
	var t := int(cfg.get_value("progress", "play_time", 0.0))
	var clock := "%d:%02d" % [t / 3600, (t % 3600) / 60] if t >= 3600 else "%d:%02d" % [t / 60, t % 60]
	return "Lv %d  ·  %d G  ·  %s  ·  %s" % [int(cfg.get_value("progress", "level", 1)),
		int(cfg.get_value("progress", "gold", 0)), clock, str(cfg.get_value("progress", "region", ""))]

## Settings (music / sfx) in their own file.
static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("settings", "music", AudioMan.music_enabled)
	cfg.set_value("settings", "sfx", AudioMan.sfx_enabled)
	cfg.save(SETTINGS_PATH)

static func load_progress(slot := current_slot) -> Dictionary:
	var d := {}
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK or not cfg.has_section("progress"):
		return d
	for key in ["level", "xp", "max_hp", "max_mp", "selected_spell", "bonus_spells", "attack", "kills", "deaths", "potions", "gold", "cape_level", "hood_level", "weapon_level", "play_time"]:
		d[key] = cfg.get_value("progress", key, null)
	var pos: Array = cfg.get_value("progress", "pos", [])
	d["pos"] = Vector3(pos[0], pos[1], pos[2]) if pos.size() == 3 else Vector3.ZERO
	d["quests"] = cfg.get_value("progress", "quests", {})
	d["items"] = cfg.get_value("progress", "items", {})
	d["accessory"] = cfg.get_value("progress", "accessory", "")
	d["skills"] = cfg.get_value("progress", "skills", {})
	d["skill_points"] = cfg.get_value("progress", "skill_points", 0)
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
	var loaded_items := {}
	for k in d.get("items", {}):
		loaded_items[String(k)] = int(d["items"][k])
	player.set("items", loaded_items)
	# Accessory bonuses are already baked into the saved stats.
	player.set("accessory", String(d.get("accessory", "")))
	var loaded_skills := {}
	for k in d.get("skills", {}):
		loaded_skills[String(k)] = int(d["skills"][k])
	player.set("skills", loaded_skills)
	player.set("skill_points", int(d.get("skill_points", 0)))
	if player.has_method("load_equipment"):
		player.load_equipment(
			int(d["cape_level"]) if d["cape_level"] != null else 0,
			int(d["hood_level"]) if d["hood_level"] != null else 0,
			int(d["weapon_level"]) if d["weapon_level"] != null else 0
		)
	player.set("play_time", float(d["play_time"]) if d["play_time"] != null else 0.0)
	var pos: Vector3 = d["pos"]
	if absf(pos.x) > 100.0 or absf(pos.z) > 400.0:
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
