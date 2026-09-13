extends Node3D
## What is left of the Order of the Drowned Chapel: three of them, keeping
## lamps lit on an island in a flooded country.

const VILLAGERS := [
	{
		"name": "Odren",
		"pos": Vector3(212, 0, 3),
		"dialogue": [
			"Mind the stones. Step off the causeway and the fen has you by the ankle.",
			"We ring the bell at dusk. Not for prayer — so the ones still out there know which way is home.",
		],
		"tunic": Color(0.30, 0.42, 0.34),
		"wanders": false,
		"kaykit": "Mage",
	},
	{
		"name": "Sister Vane",
		"pos": Vector3(207, 0, 5),
		"dialogue": [
			"Dry goods, dry bandages, dry anything. Out here that is worth more than gold.",
			"Buy what you need. The water will take the rest eventually.",
		],
		"tunic": Color(0.38, 0.40, 0.32),
		"wanders": false,
		"kaykit": "Rogue",
		"shop_title": "THE CHAPEL STORES",
		"shop_items": [
			{"name": "Potion", "price": 65, "desc": "Restores 50 HP"},
			{"name": "Potion Bundle", "price": 185, "desc": "Three potions (150 HP in all)"},
		],
	},
	{
		"name": "Tam",
		"pos": Vector3(210, 0, -4),
		"dialogue": [
			"I count the lamps every morning. Some mornings there are fewer.",
			"There is a pool at the end of the causeway. Do not swim in it. Do not stand near it. Do not look at it long.",
		],
		"tunic": Color(0.34, 0.36, 0.40),
		"wanders": true,
		"kaykit": "Knight",
	},
]

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.EAST)
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
