extends Node3D
## The one thing in the vault that still talks. Alwin went down the well
## to fix the winch four hundred years ago and has been keeping the lamps
## lit ever since. He has not noticed.

const VILLAGERS := [
	{
		"name": "Keeper Alwin",
		"pos": Vector3(4, 0, 190),
		"dialogue": [
			"Careful on those steps, they're slick. Did Maren send you down with the rope?",
			"I'll have the winch fixed by supper. Tell her that. Tell her supper.",
		],
		"tunic": Color(0.45, 0.48, 0.55),
		"wanders": false,
		"kaykit": "Mage",
	},
]

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.DEEP)
	var villager_script := preload("res://src/npc/villager.gd")
	for data in VILLAGERS:
		var v: Node3D = villager_script.new()
		v.position = data["pos"]
		v.set("npc_name", data["name"])
		v.set("dialogue", data["dialogue"])
		v.set("tunic_color", data["tunic"])
		v.set("wanders", data["wanders"])
		v.set("kaykit_model", data["kaykit"])
		add_child(v)
