extends Node3D
## Grimholt's people: hardy northerners holding out against the cold
## and the things that walk in it.

const VILLAGERS := [
	{
		"name": "Elder Sella",
		"pos": Vector3(-2, 0, -83),
		"dialogue": ["So Emberfell still stands. Good. We feared the worst when the riders stopped coming.", "Vorgath's death echoes north, traveler. But something older stirs beneath the ice."],
		"tunic": Color(0.50, 0.45, 0.55),
		"wanders": false,
		"kaykit": "Mage",
	},
	{
		"name": "Hob",
		"pos": Vector3(5, 0, -80),
		"dialogue": ["I scout the northern road. The dead walk bolder every night.", "If you're heading back south, watch the treeline. They like the treeline."],
		"tunic": Color(0.35, 0.40, 0.30),
		"wanders": true,
		"kaykit": "Rogue",
	},
	{
		"name": "Wren",
		"pos": Vector3(-6, 0, -88),
		"dialogue": ["Potions? Aye, I trade in 'em. The cold's good for preserving.", "Buy something, or don't. The dead don't haggle."],
		"tunic": Color(0.55, 0.40, 0.25),
		"wanders": false,
		"kaykit": "Barbarian",
		"shop_title": "WREN'S WARES",
		"shop_items": [
			{"name": "Potion", "price": 50, "desc": "Restores 50 HP"},
			{"name": "Potion Bundle", "price": 140, "desc": "Three potions (150 HP in all)"},
		],
	},
]

func _ready() -> void:
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
