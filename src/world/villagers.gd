extends Node3D
## Spawns villagers around the village that wander and can be talked to.

const VILLAGERS := [
	{
		"name": "Mira",
		"pos": Vector3(-4, 0, 2),
		"dialogue": ["Welcome to our village, traveler!", "Skeletons roam the southern wilds. Be careful out there."],
		"tunic": Color(0.55, 0.30, 0.35),
		"wanders": true,
	},
	{
		"name": "Bram",
		"pos": Vector3(5, 0, 4),
		"dialogue": ["The market has the best potions around.", "If you're hurt, buy a potion. Trust me."],
		"tunic": Color(0.35, 0.45, 0.55),
		"wanders": true,
	},
	{
		"name": "Old Fen",
		"pos": Vector3(-2, 0, 12),
		"dialogue": ["I've seen heroes come and go...", "The skeletons fear a sharp blade and a full HP bar."],
		"tunic": Color(0.45, 0.40, 0.30),
		"wanders": false,
	},
	{
		"name": "Pip",
		"pos": Vector3(12, 0, 8),
		"dialogue": ["Have you been inside the tavern? The innkeeper tells great stories!", "I want to be an adventurer when I grow up!"],
		"tunic": Color(0.40, 0.55, 0.35),
		"wanders": true,
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
		add_child(v)
