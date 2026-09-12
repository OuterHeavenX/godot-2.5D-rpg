class_name Spells
extends RefCounted
## Spell definitions for the magic system.
## Each spell: id, name, description, mp cost, unlock level, damage multiplier,
## projectile color, and special effect.

const FIREBALL := "fireball"
const FROST_BOLT := "frost_bolt"
const HEAL := "heal"

static func all() -> Array:
	return [FIREBALL, FROST_BOLT, HEAL]

static func get_info(spell_id: String) -> Dictionary:
	match spell_id:
		FIREBALL:
			return {
				"id": FIREBALL,
				"name": "Fireball",
				"desc": "Hurls a blazing orb that explodes on impact.",
				"mp": 8,
				"unlock_level": 1,
				"dmg_mult": 1.5,
				"color": Color(1.0, 0.45, 0.1),
				"kind": "projectile",
			}
		FROST_BOLT:
			return {
				"id": FROST_BOLT,
				"name": "Frost Bolt",
				"desc": "A shard of ice that chills enemies, slowing them.",
				"mp": 6,
				"unlock_level": 5,
				"dmg_mult": 1.0,
				"color": Color(0.4, 0.8, 1.0),
				"kind": "projectile",
				"slow_duration": 4.0,
			}
		HEAL:
			return {
				"id": HEAL,
				"name": "Heal",
				"desc": "Mends wounds, restoring 40% of max HP.",
				"mp": 10,
				"unlock_level": 3,
				"dmg_mult": 0.0,
				"color": Color(0.3, 1.0, 0.5),
				"kind": "instant",
				"heal_frac": 0.4,
			}
	return {}

static func unlocked_spells(player_level: int) -> Array:
	var result := []
	for spell_id in all():
		if player_level >= int(get_info(spell_id)["unlock_level"]):
			result.append(spell_id)
	return result
