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
	"ash_cinder": {"name": "Ash Cinder", "kind": KIND_MATERIAL, "desc": "A coal from the highland fires. Still warm after all these years.",
		"sell": 24, "color": Color(0.85, 0.38, 0.15), "glyph": "A"},
	"reaver_crest": {"name": "Reaver Crest", "kind": KIND_MATERIAL, "desc": "Kael's war crest, cut from a shield he took.",
		"sell": 340, "color": Color(0.75, 0.25, 0.18), "glyph": "R"},
	"bog_iron": {"name": "Bog Iron", "kind": KIND_MATERIAL, "desc": "Iron the fen ate and gave back. Heavier than it should be.",
		"sell": 30, "color": Color(0.35, 0.42, 0.30), "glyph": "I"},
	"mire_heart": {"name": "Mire Heart", "kind": KIND_MATERIAL, "desc": "What was beating at the middle of Gholl. It is still warm.",
		"sell": 420, "color": Color(0.35, 0.75, 0.45), "glyph": "M"},
	"grave_dust": {"name": "Grave Dust", "kind": KIND_MATERIAL, "desc": "Swept off the vault floor. Some of it was people.",
		"sell": 36, "color": Color(0.55, 0.52, 0.60), "glyph": "D"},
	"hollow_crown": {"name": "The Hollow Crown", "kind": KIND_MATERIAL, "desc": "The crown every king down here was wearing when the vault took them.",
		"sell": 900, "color": Color(0.78, 0.66, 0.35), "glyph": "H"},
	# Accessories: one equipped at a time. Bonuses apply on equip.
	"bone_charm": {"name": "Bone Charm", "kind": KIND_ACCESSORY, "desc": "+15% XP from kills.",
		"sell": 60, "color": Color(0.9, 0.88, 0.75), "glyph": "B", "xp_mult": 1.15},
	"pearl_pendant": {"name": "Pearl Pendant", "kind": KIND_ACCESSORY, "desc": "+20 max HP.",
		"sell": 90, "color": Color(0.35, 0.4, 0.6), "glyph": "P", "hp": 20.0},
	"frost_talisman": {"name": "Frost Talisman", "kind": KIND_ACCESSORY, "desc": "Immune to chill. +10% attack.",
		"sell": 250, "color": Color(0.6, 0.9, 1.0), "glyph": "F", "atk_mult": 1.10, "chill_immune": true},
	"drowned_circlet": {"name": "Drowned Circlet", "kind": KIND_ACCESSORY, "desc": "+30 max HP, +6 attack.",
		"sell": 300, "color": Color(0.85, 0.65, 0.25), "glyph": "C", "hp": 30.0, "atk": 6.0},
	"cinder_band": {"name": "Cinder Band", "kind": KIND_ACCESSORY, "desc": "+8% attack, +15 max HP.",
		"sell": 180, "color": Color(0.9, 0.45, 0.2), "glyph": "A", "atk_mult": 1.08, "hp": 15.0},
	"reavers_mark": {"name": "Reaver's Mark", "kind": KIND_ACCESSORY, "desc": "+12 attack, +20 max HP.",
		"sell": 420, "color": Color(0.8, 0.3, 0.2), "glyph": "R", "atk": 12.0, "hp": 20.0},
	"bog_iron_ring": {"name": "Bog Iron Ring", "kind": KIND_ACCESSORY, "desc": "+40 max HP.",
		"sell": 260, "color": Color(0.4, 0.5, 0.35), "glyph": "I", "hp": 40.0},
	"drowned_heart": {"name": "Drowned Heart", "kind": KIND_ACCESSORY, "desc": "+15% attack, +45 max HP.",
		"sell": 560, "color": Color(0.4, 0.85, 0.5), "glyph": "M", "atk_mult": 1.15, "hp": 45.0},
	"dust_charm": {"name": "Dust Charm", "kind": KIND_ACCESSORY, "desc": "+25% XP from kills.",
		"sell": 320, "color": Color(0.6, 0.57, 0.65), "glyph": "D", "xp_mult": 1.25},
	"kings_ruin": {"name": "The King's Ruin", "kind": KIND_ACCESSORY, "desc": "+20 attack, +60 max HP, +20% XP.",
		"sell": 1200, "color": Color(0.82, 0.70, 0.38), "glyph": "H", "atk": 20.0, "hp": 60.0, "xp_mult": 1.20},
}

## Blacksmith recipes: result id -> {"needs": {material: count}, "fee": gold}.
const RECIPES := {
	"ether": {"needs": {"wisp_essence": 2, "slime_gel": 1}, "fee": 20},
	"elixir": {"needs": {"bone_shard": 3, "black_pearl": 2, "ember_seed": 1}, "fee": 60},
	"bone_charm": {"needs": {"bone_shard": 6, "stolen_trinket": 1}, "fee": 80},
	"pearl_pendant": {"needs": {"black_pearl": 4, "slime_gel": 2}, "fee": 120},
	"frost_talisman": {"needs": {"frost_shard": 1, "wisp_essence": 3}, "fee": 200},
	"drowned_circlet": {"needs": {"drowned_crown": 1, "black_pearl": 4}, "fee": 200},
	"cinder_band": {"needs": {"ash_cinder": 5, "stolen_trinket": 2}, "fee": 150},
	"reavers_mark": {"needs": {"reaver_crest": 1, "ash_cinder": 6}, "fee": 320},
	"bog_iron_ring": {"needs": {"bog_iron": 6, "black_pearl": 3}, "fee": 240},
	"drowned_heart": {"needs": {"mire_heart": 1, "bog_iron": 8}, "fee": 450},
	"dust_charm": {"needs": {"grave_dust": 6, "bone_shard": 8}, "fee": 300},
	# No unique boss trophy appears in two recipes. The King's Ruin used
	# to want Vorgath's crown as well, and he drops exactly one and never
	# comes back — so forging the Drowned Circlet, which is an obvious
	# upgrade the moment the first boss falls, quietly destroyed the only
	# ingredient for the best accessory in the game.
	"kings_ruin": {"needs": {"hollow_crown": 1, "grave_dust": 10, "black_pearl": 6}, "fee": 900},
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
