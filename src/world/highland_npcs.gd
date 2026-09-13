extends Node3D
## The garrison of Ashfall Watch: what is left of the company the crown
## sent west, holding a broken tower on a burnt hill.

const VILLAGERS := [
	{
		"name": "Ilsa",
		"pos": Vector3(-207, 0, 2),
		"dialogue": [
			"Emberfell sent someone. After four years, Emberfell sent someone.",
			"Kael holds the far end of the road. Everything between here and there is his.",
		],
		"tunic": Color(0.55, 0.50, 0.45),
		"wanders": false,
		"kaykit": "Knight",
	},
	{
		"name": "Corin",
		"pos": Vector3(-213, 0, 4),
		"dialogue": [
			"Supplies came up the road once a month. The road's been shut two years.",
			"What I've got, I'll sell. What I sell, I can't replace. Choose carefully.",
		],
		"tunic": Color(0.42, 0.34, 0.28),
		"wanders": false,
		"kaykit": "Rogue",
		"shop_title": "CORIN'S STORES",
		"shop_items": [
			{"name": "Potion", "price": 60, "desc": "Restores 50 HP"},
			{"name": "Potion Bundle", "price": 170, "desc": "Three potions (150 HP in all)"},
		],
	},
	{
		"name": "Halden",
		"pos": Vector3(-210, 0, -3),
		"dialogue": [
			"I watched the hills burn from that tower. Took eleven days.",
			"The reavers came up through the smoke while it was still hot. They've been here since.",
		],
		"tunic": Color(0.38, 0.36, 0.40),
		"wanders": true,
		"kaykit": "Barbarian",
	},
]

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.WEST)
	var villager_script := preload("res://src/npc/villager.gd")
	for data in VILLAGERS:
		var v: Node3D = villager_script.new()
		v.position = data["pos"]
		v.set("npc_name", data["name"])
		v.set("dialogue", data["dialogue"])
		v.set("tunic_color", data["tunic"])
		v.set("wanders", data["wanders"])
		if data.has("kaykit"):
			v.set("kaykit_model", data["kaykit"])
		if data.has("shop_title"):
			v.set("shop_title", data["shop_title"])
		if data.has("shop_items"):
			v.set("shop_items", data["shop_items"])
		add_child(v)
