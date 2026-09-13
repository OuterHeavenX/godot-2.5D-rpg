class_name ItemDB
## Static item definitions: consumables, crafting materials and accessories,
## plus the blacksmith's recipes. Potions keep their own counter on the
## player (HUD, quests and shops all use it); everything else lives in the
## player's `items` dictionary keyed by these ids.

const KIND_CONSUMABLE := "consumable"
const KIND_MATERIAL := "material"
const KIND_ACCESSORY := "accessory"

const ITEMS := {
	"potion": {"name": "Potion", "kind": KIND_CONSUMABLE, "desc": "Restores 50 HP.",
		"sell": 20, "color": Color(0.9, 0.15, 0.2), "glyph": "P"},
	"ether": {"name": "Ether", "kind": KIND_CONSUMABLE, "desc": "Restores 20 MP.",
		"sell": 30, "color": Color(0.35, 0.55, 1.0), "glyph": "E", "mp": 20.0},
	"elixir": {"name": "Elixir", "kind": KIND_CONSUMABLE, "desc": "Fully restores HP and MP.",
		"sell": 120, "color": Color(1.0, 0.85, 0.3), "glyph": "X", "full": true},
	"bone_shard": {"name": "Bone Shard", "kind": KIND_MATERIAL, "desc": "A splinter of walking bone. Smiths grind it into charms.",
		"sell": 6, "color": Color(0.85, 0.82, 0.7), "glyph": "B"},
	"black_pearl": {"name": "Black Pearl", "kind": KIND_MATERIAL, "desc": "Grown in the black water. Cold to the touch.",
		"sell": 18, "color": Color(0.2, 0.22, 0.35), "glyph": "O"},
	"stolen_trinket": {"name": "Stolen Trinket", "kind": KIND_MATERIAL, "desc": "A bandit's take. Worth a fair bit to the right buyer.",
		"sell": 40, "color": Color(0.9, 0.7, 0.3), "glyph": "T"},
	"slime_gel": {"name": "Slime Gel", "kind": KIND_MATERIAL, "desc": "Wobbles. Binds other reagents together.",
		"sell": 8, "color": Color(0.4, 0.9, 0.35), "glyph": "G"},
	"wisp_essence": {"name": "Wisp Essence", "kind": KIND_MATERIAL, "desc": "A captured blue flame. Hums faintly.",
		"sell": 22, "color": Color(0.4, 0.8, 1.0), "glyph": "W"},
	"ember_seed": {"name": "Ember Seed", "kind": KIND_MATERIAL, "desc": "Still warm from the jack-o'-lantern's grin.",
		"sell": 12, "color": Color(1.0, 0.5, 0.15), "glyph": "S"},
	"drowned_crown": {"name": "Drowned Crown", "kind": KIND_MATERIAL, "desc": "Vorgath's crown of drowned gold.",
		"sell": 300, "color": Color(0.85, 0.65, 0.25), "glyph": "C"},
	"frost_shard": {"name": "Frost Shard", "kind": KIND_MATERIAL, "desc": "A piece of Morvain's heart. Never melts.",
		"sell": 300, "color": Color(0.6, 0.9, 1.0), "glyph": "F"},
	# Accessories: one equipped at a time. Bonuses apply on equip.
	"bone_charm": {"name": "Bone Charm", "kind": KIND_ACCESSORY, "desc": "+15% XP from kills.",
		"sell": 60, "color": Color(0.9, 0.88, 0.75), "glyph": "B", "xp_mult": 1.15},
	"pearl_pendant": {"name": "Pearl Pendant", "kind": KIND_ACCESSORY, "desc": "+20 max HP.",
		"sell": 90, "color": Color(0.35, 0.4, 0.6), "glyph": "P", "hp": 20.0},
	"frost_talisman": {"name": "Frost Talisman", "kind": KIND_ACCESSORY, "desc": "Immune to chill. +10% attack.",
		"sell": 250, "color": Color(0.6, 0.9, 1.0), "glyph": "F", "atk_mult": 1.10, "chill_immune": true},
	"drowned_circlet": {"name": "Drowned Circlet", "kind": KIND_ACCESSORY, "desc": "+30 max HP, +6 attack.",
		"sell": 300, "color": Color(0.85, 0.65, 0.25), "glyph": "C", "hp": 30.0, "atk": 6.0},
}

## Blacksmith recipes: result id -> {"needs": {material: count}, "fee": gold}.
const RECIPES := {
	"ether": {"needs": {"wisp_essence": 2, "slime_gel": 1}, "fee": 20},
	"elixir": {"needs": {"bone_shard": 3, "black_pearl": 2, "ember_seed": 1}, "fee": 60},
	"bone_charm": {"needs": {"bone_shard": 6, "stolen_trinket": 1}, "fee": 80},
	"pearl_pendant": {"needs": {"black_pearl": 4, "slime_gel": 2}, "fee": 120},
	"frost_talisman": {"needs": {"frost_shard": 1, "wisp_essence": 3}, "fee": 200},
	"drowned_circlet": {"needs": {"drowned_crown": 1, "black_pearl": 4}, "fee": 200},
}

static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func item_name(id: String) -> String:
	return String(ITEMS.get(id, {}).get("name", id))

static func is_kind(id: String, kind: String) -> bool:
	return String(ITEMS.get(id, {}).get("kind", "")) == kind

static func recipe_ids() -> Array:
	return RECIPES.keys()

## Human-readable ingredient list: "2 Wisp Essence, 1 Slime Gel".
static func recipe_text(result_id: String) -> String:
	var parts := []
	var needs: Dictionary = RECIPES[result_id]["needs"]
	for mat in needs:
		parts.append("%d %s" % [int(needs[mat]), item_name(mat)])
	return ", ".join(parts)
