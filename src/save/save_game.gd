class_name SaveGame
## Static save/load helpers. Three progress slots at user://savegame_N.cfg
## (persisted to IndexedDB on web); settings live in user://settings.cfg.
## The pre-slot file user://savegame.cfg is migrated into slot 1 once.

const SLOTS := 3
## Bumped when the shape of a saved field changes; see load_progress().
const SAVE_VERSION := 2
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

## True when the slot holds progress worth continuing. A file that is
## truncated or scribbled on — a browser tab closed mid-write, an
## IndexedDB store half flushed — parses to an empty or partial section,
## and that used to read as a save: CONTINUE started a blank character
## and the first autosave wrote it over whatever was left.
static func has_save(slot := current_slot) -> bool:
	migrate_legacy()
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("progress"):
		return false
	# A real save always carries a level and a position; anything without
	# both is a half-written file, not progress.
	var lvl: Variant = cfg.get_value("progress", "level", null)
	if not (lvl is int or lvl is float) or int(lvl) < 1:
		return false
	var p: Variant = cfg.get_value("progress", "pos", null)
	return p is Array and (p as Array).size() == 3

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
	# Quests count kills across every region, so every region's count has
	# to come back. Storing only the southern one made a kill quest that
	# spanned a save come back with negative progress.
	var by_region := {}
	for mgr in player.get_tree().get_nodes_in_group("foe_spawner"):
		by_region[String(mgr.get("region"))] = int(mgr.get("kills"))
	cfg.set_value("progress", "kills_by_region", by_region)
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
	# Version 2 stores attack without the worn accessory folded in; see
	# Player.total_attack(). Version 1 saves are unbaked on load.
	cfg.set_value("progress", "save_version", SAVE_VERSION)
	cfg.set_value("progress", "saved_at", Time.get_datetime_string_from_system())
	cfg.set_value("progress", "region", _region_name(pos))
	cfg.save(slot_path(slot))

## The place name shown on a save slot's summary line.
static func _region_name(pos: Vector3) -> String:
	match Regions.at(pos.x, pos.z):
		Regions.NORTH:
			if pos.z < -270.0:
				return "Frozen Arena"
			if pos.z < -230.0:
				return "Grimholt"
			return "Northern wilds"
		Regions.SOUTH:
			if pos.x > 24.0 and pos.z > 40.0:
				return "Black water"
			return "Southern wilds"
		Regions.WEST:
			if pos.x < -270.0:
				return "Kael's ground"
			if AshenHighlands.is_in_camp(pos.x, pos.z, 4.0):
				return "Ashfall Watch"
			return "Ashen Highlands"
		Regions.EAST:
			if pos.x > 270.0:
				return "Gholl's pool"
			if Mirefen.is_at_chapel(pos.x, pos.z, 4.0):
				return "Drowned Chapel"
			return "The Mirefen"
		Regions.DEEP:
			if pos.z > SunkenVault.THRONE_Z0:
				return "The Throne"
			return "The Sunken Vault"
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
	# The stored position may be missing or the wrong shape in a file that
	# was written badly; read it as a Variant and check before unpacking,
	# rather than crashing the load on a bad slot.
	var pos: Variant = cfg.get_value("progress", "pos", null)
	d["pos"] = Vector3.ZERO
	if pos is Array and (pos as Array).size() == 3:
		var a: Array = pos
		d["pos"] = Vector3(float(a[0]), float(a[1]), float(a[2]))
	d["quests"] = cfg.get_value("progress", "quests", {})
	d["items"] = cfg.get_value("progress", "items", {})
	d["accessory"] = cfg.get_value("progress", "accessory", "")
	d["skills"] = cfg.get_value("progress", "skills", {})
	d["kills_by_region"] = cfg.get_value("progress", "kills_by_region", {})
	d["skill_points"] = cfg.get_value("progress", "skill_points", 0)
	d["party"] = cfg.get_value("progress", "party", {})
	# Version 1 stored attack with the worn accessory multiplied in. Take
	# it back out, or the charm's bonus is counted a second time every
	# time the stat is read.
	if int(cfg.get_value("progress", "save_version", 1)) < 2:
		var worn := String(d["accessory"])
		if worn != "" and d["attack"] != null:
			var info := ItemDB.get_item(worn)
			var bare := float(d["attack"]) / float(info.get("atk_mult", 1.0))
			d["attack"] = bare - float(info.get("atk", 0.0))
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
	# Interiors are built far off the map at x>400; a save that landed in
	# one (an old save, a bad load) comes back to the village square. Every
	# real region sits well inside these bounds.
	if absf(pos.x) > 320.0 or pos.z < -320.0 or pos.z > 390.0:
		pos = Vector3(0, 0.1, 0)
	player.global_position = pos
	PartyMan.teleport_with(pos + Vector3(1.2, 0.0, 0.0))
	# Wake wherever the hero just landed before the next poll would: a
	# sleeping region has no floor, and a load can drop them into one.
	var runtime := player.get_tree().get_first_node_in_group("region_runtime")
	if runtime != null and runtime.has_method("sync_now"):
		runtime.call("sync_now")
	# Hand each region back its own tally. Older saves only carried one
	# number, which was the southern wilds'.
	var by_region: Dictionary = d.get("kills_by_region", {})
	var legacy := int(d["kills"]) if d["kills"] != null else 0
	for spawner in player.get_tree().get_nodes_in_group("foe_spawner"):
		var region := String(spawner.get("region"))
		var count := int(by_region.get(region, legacy if region == Regions.SOUTH else 0))
		spawner.set("kills", count)
		if spawner.has_signal("kills_changed"):
			spawner.emit_signal("kills_changed", count)
	if mgr != null and mgr.has_method("rescale_all"):
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
