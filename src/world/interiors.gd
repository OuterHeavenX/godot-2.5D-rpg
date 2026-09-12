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

	# Ceiling.
	var ceil := _box(Vector3(w, 0.2, d), wall_color.darkened(0.3))
	ceil.position = origin + Vector3(0, h, 0)
	add_child(ceil)

	# Walls (north, south with door gap, east, west).
	var wall_mat := wall_color
	# North wall (full).
	var north := _box(Vector3(w, h, 0.3), wall_mat)
	north.position = origin + Vector3(0, h / 2, -d / 2)
	add_child(north)
	# South wall with 2m door gap in center.
	var door_w := 2.0
	var side_w := (w - door_w) / 2
	var south_l := _box(Vector3(side_w, h, 0.3), wall_mat)
	south_l.position = origin + Vector3(-(door_w / 2 + side_w / 2), h / 2, d / 2)
	add_child(south_l)
	var south_r := _box(Vector3(side_w, h, 0.3), wall_mat)
	south_r.position = origin + Vector3(door_w / 2 + side_w / 2, h / 2, d / 2)
	add_child(south_r)
	# Door lintel (above the gap).
	var lintel := _box(Vector3(door_w, h - 2.5, 0.3), wall_mat)
	lintel.position = origin + Vector3(0, 2.5 + (h - 2.5) / 2, d / 2)
	add_child(lintel)
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
	# South wall with door gap (two segments).
	var door_w := 2.0
	var side_w := (w - door_w) / 2
	for x in [-(door_w / 2 + side_w / 2), door_w / 2 + side_w / 2]:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(side_w, h, 0.3)
		col.shape = shape
		col.position = Vector3(x, h / 2, d / 2)
		body.add_child(col)
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
