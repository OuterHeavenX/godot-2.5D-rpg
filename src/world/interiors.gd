extends Node3D
## Builds interior rooms for enterable buildings. Rooms are placed far
## off-map (x=500+) so the player can be teleported inside.
## Each room: floor, 4 walls, ceiling, exit door trigger, basic furniture.

const ROOM_X := 500.0  # Base X for interiors
const ROOM_SPACING := 40.0  # Distance between rooms

# Room definitions: [name, size (Vector2 xz), wall_color, floor_color]
const ROOMS := [
	{"name": "market", "size": Vector2(12, 10), "wall": Color(0.55, 0.42, 0.30), "floor": Color(0.45, 0.35, 0.25)},
	{"name": "tavern", "size": Vector2(14, 12), "wall": Color(0.50, 0.38, 0.28), "floor": Color(0.42, 0.32, 0.22)},
	{"name": "house_a", "size": Vector2(10, 8), "wall": Color(0.60, 0.52, 0.42), "floor": Color(0.48, 0.40, 0.30)},
]

var _rooms := {}  # name -> {"origin": Vector3, "exit_pos": Vector3}

func _ready() -> void:
	for i in ROOMS.size():
		var room = ROOMS[i]
		var origin := Vector3(ROOM_X + i * ROOM_SPACING, 0, 0)
		_build_room(room, origin)
		_rooms[room["name"]] = {
			"origin": origin,
			"exit_pos": origin + Vector3(0, 0, room["size"].y / 2 - 1.0),
		}

func get_room(name: String) -> Dictionary:
	return _rooms.get(name, {})

func _build_room(room: Dictionary, origin: Vector3) -> void:
	var size: Vector2 = room["size"]
	var wall_color: Color = room["wall"]
	var floor_color: Color = room["floor"]
	var w := size.x
	var d := size.y
	var h := 4.0  # Wall height

	# Floor.
	var floor := _box(Vector3(w, 0.2, d), floor_color)
	floor.position = origin + Vector3(0, -0.1, 0)
	add_child(floor)

	# No ceiling: the angled follow camera looks down from above,
	# so a ceiling would block the view of the interior.

	# Walls: north, east, west. No south wall (dollhouse view) — the angled
	# camera looks from the south, so a south wall would block the interior.
	# South edge keeps invisible collision so the player can't walk into the void.
	var wall_mat := wall_color
	# North wall (full).
	var north := _box(Vector3(w, h, 0.3), wall_mat)
	north.position = origin + Vector3(0, h / 2, -d / 2)
	add_child(north)
	# East and west walls.
	var east := _box(Vector3(0.3, h, d), wall_mat)
	east.position = origin + Vector3(w / 2, h / 2, 0)
	add_child(east)
	var west := _box(Vector3(0.3, h, d), wall_mat)
	west.position = origin + Vector3(-w / 2, h / 2, 0)
	add_child(west)

	# Collision: static bodies for floor and walls.
	_add_collision(origin, w, d, h)

	# Basic furniture: table + crates.
	_add_furniture(origin, room["name"])

	# Warm interior light.
	var light := OmniLight3D.new()
	light.position = origin + Vector3(0, 3.0, 0)
	light.light_color = Color(1.0, 0.85, 0.65)
	light.light_energy = 1.2
	light.omni_range = 15.0
	add_child(light)
	# Shopkeeper in the market.
	if room["name"] == "market":
		_add_shopkeeper(origin)
	# Innkeeper in the tavern.
	elif room["name"] == "tavern":
		_add_innkeeper(origin)
	# Villager in houses.
	elif room["name"] == "house_a":
		_add_house_villager(origin)

func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.set_surface_override_material(0, mat)
	return mi

func _add_collision(origin: Vector3, w: float, d: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.position = origin
	# Floor.
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(w, 0.2, d)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, -0.1, 0)
	body.add_child(floor_col)
	# Walls.
	for data in [
		[Vector3(w, h, 0.3), Vector3(0, h / 2, -d / 2)],  # North
		[Vector3(0.3, h, d), Vector3(w / 2, h / 2, 0)],   # East
		[Vector3(0.3, h, d), Vector3(-w / 2, h / 2, 0)],  # West
	]:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = data[0]
		col.shape = shape
		col.position = data[1]
		body.add_child(col)
	# South wall: full width, no gap (invisible — keeps player from walking
	# into the void; exit is via the EXIT button).
	var scol := CollisionShape3D.new()
	var sshape := BoxShape3D.new()
	sshape.size = Vector3(w, h, 0.3)
	scol.shape = sshape
	scol.position = Vector3(0, h / 2, d / 2)
	body.add_child(scol)
	add_child(body)

func _add_furniture(origin: Vector3, room_name: String) -> void:
	# Simple table.
	var table := _box(Vector3(2.0, 0.1, 1.0), Color(0.45, 0.32, 0.20))
	table.position = origin + Vector3(0, 0.9, -1.0)
	add_child(table)
	for lx in [-0.8, 0.8]:
		for lz in [-0.4, 0.4]:
			var leg := _box(Vector3(0.12, 0.9, 0.12), Color(0.40, 0.28, 0.18))
			leg.position = origin + Vector3(lx, 0.45, -1.0 + lz)
			add_child(leg)
	# Crates in corner.
	for i in 3:
		var crate := _box(Vector3(0.8, 0.8, 0.8), Color(0.55, 0.42, 0.28))
		crate.position = origin + Vector3(-3.0 + (i % 2) * 0.9, 0.4, 2.5 - (i / 2) * 0.9)
		crate.rotation.y = randf() * 0.5
		add_child(crate)

func _add_shopkeeper(origin: Vector3) -> void:
	var keeper := preload("res://src/npc/shopkeeper.gd").new()
	# Behind the table (north side).
	keeper.position = origin + Vector3(0, 0, -2.5)
	add_child(keeper)

func _add_innkeeper(origin: Vector3) -> void:
	var v: Node3D = preload("res://src/npc/villager.gd").new()
	v.position = origin + Vector3(0, 0, -2.5)
	v.set("npc_name", "Innkeeper Dora")
	v.set("tunic_color", Color(0.60, 0.35, 0.25))
	v.set("wanders", false)
	# Seller: opens shop with Rest and Ale.
	v.set("shop_title", "THE RUSTY DAGGER")
	v.set("shop_items", [
		{"name": "Rest", "price": 50, "desc": "Full HP restore, cozy bed"},
		{"name": "Ale", "price": 10, "desc": "Restores 25 HP, tasty"},
	])
	add_child(v)

func _add_house_villager(origin: Vector3) -> void:
	var v: Node3D = preload("res://src/npc/villager.gd").new()
	v.position = origin + Vector3(1.5, 0, -1.0)
	v.set("npc_name", "Villager")
	v.set("dialogue", [
		"Oh! A visitor. We don't get many adventurers in here.",
		"It's cozy, isn't it? The village is a safe place.",
	])
	v.set("tunic_color", Color(0.50, 0.45, 0.35))
	v.set("wanders", false)
	add_child(v)
