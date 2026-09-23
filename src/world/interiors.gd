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
	{"name": "blacksmith", "size": Vector2(12, 10), "wall": Color(0.45, 0.38, 0.32), "floor": Color(0.35, 0.30, 0.25)},
	{"name": "house_a", "size": Vector2(10, 8), "wall": Color(0.60, 0.52, 0.42), "floor": Color(0.48, 0.40, 0.30)},
	# Grimholt: colder stone, northern NPCs.
	{"name": "grimholt_tavern", "size": Vector2(14, 12), "wall": Color(0.42, 0.45, 0.52), "floor": Color(0.34, 0.36, 0.42)},
	{"name": "grimholt_market", "size": Vector2(12, 10), "wall": Color(0.48, 0.44, 0.40), "floor": Color(0.38, 0.35, 0.32)},
	{"name": "grimholt_house", "size": Vector2(10, 8), "wall": Color(0.52, 0.50, 0.46), "floor": Color(0.40, 0.38, 0.34)},
]

var _rooms := {}  # name -> {"origin": Vector3, "exit_pos": Vector3}

# Procedural textures for the Emberfell tavern floor
# and walls (the flat browns get wood planks / stone blocks). Generated at
# runtime so the headless PNG import pipeline is never involved. Only the
# "tavern" room uses them — every other room keeps its flat colors.
var _tavern_floor_tex: Texture2D = null
var _tavern_wall_tex: Texture2D = null

func _ensure_tavern_textures() -> void:
	if _tavern_floor_tex == null:
		_tavern_floor_tex = _make_plank_texture()
	if _tavern_wall_tex == null:
		_tavern_wall_tex = _make_stone_texture()

## Dark muted wood planks (detail texture; the room's warm brown
## albedo_color multiplies on top, so the grimdark mood stays).
func _make_plank_texture() -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77031
	var plank_h := size / 8  # 8 planks per tile
	var plank_tone: Array[float] = []
	for p in 8:
		plank_tone.append(rng.randf_range(0.90, 1.0))
	for y in size:
		var plank: int = mini(y / plank_h, 7)
		var tone: float = plank_tone[plank]
		for x in size:
			var v := tone
			# Long horizontal grain streaks + a little noise.
			v *= 1.0 + 0.05 * sin(float(x) * 0.11 + float(plank) * 2.3) \
				+ 0.04 * sin(float(x) * 0.031 + float(y) * 0.7)
			v *= 1.0 + rng.randf_range(-0.03, 0.03)
			var c := Color(0.86 * v, 0.83 * v, 0.79 * v)
			if y % plank_h < 2:
				c = Color(0.40, 0.36, 0.32)  # gap between planks
			var seam_x := (plank * 53 + 20) % size  # staggered butt joints
			if abs(x - seam_x) < 1:
				c = Color(0.42, 0.38, 0.34)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Dark muted stone blocks with mortar courses.
func _make_stone_texture() -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91337
	var course_h := size / 6
	var block_w := size / 2
	for y in size:
		var course: int = mini(y / course_h, 5)
		var offset := (course % 2) * (block_w / 2)
		for x in size:
			var bx := (x + offset) % size
			var block := bx / block_w
			var tone := 0.94 + 0.06 * sin(float(course * 7 + block) * 3.1)
			var v := tone * (1.0 + rng.randf_range(-0.025, 0.025))
			var c := Color(0.82 * v, 0.80 * v, 0.76 * v)
			if y % course_h < 2 or bx % block_w < 2:
				c = Color(0.36, 0.33, 0.30)  # mortar
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

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
	var floor_tex: Texture2D = null
	var wall_tex: Texture2D = null
	if room["name"] == "tavern":
		_ensure_tavern_textures()
		floor_tex = _tavern_floor_tex
		wall_tex = _tavern_wall_tex
	var floor := _box(Vector3(w, 0.2, d), floor_color, floor_tex, Vector3(7, 6, 1))
	floor.position = origin + Vector3(0, -0.1, 0)
	add_child(floor)

	# No ceiling: the angled follow camera looks down from above,
	# so a ceiling would block the view of the interior.

	# Walls: north, east, west. No south wall (dollhouse view) — the angled
	# camera looks from the south, so a south wall would block the interior.
	# South edge keeps invisible collision so the player can't walk into the void.
	var wall_mat := wall_color
	# North wall (full).
	var north := _box(Vector3(w, h, 0.3), wall_mat, wall_tex, Vector3(7, 2, 1))
	north.position = origin + Vector3(0, h / 2, -d / 2)
	add_child(north)
	# East and west walls.
	var east := _box(Vector3(0.3, h, d), wall_mat, wall_tex, Vector3(6, 2, 1))
	east.position = origin + Vector3(w / 2, h / 2, 0)
	add_child(east)
	var west := _box(Vector3(0.3, h, d), wall_mat, wall_tex, Vector3(6, 2, 1))
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
	# Blacksmith in the forge.
	elif room["name"] == "blacksmith":
		_add_blacksmith(origin)
	# Villager in houses.
	elif room["name"] == "house_a":
		_add_house_villager(origin)
	# Grimholt tavern: northern innkeeper.
	elif room["name"] == "grimholt_tavern":
		_add_grimholt_innkeeper(origin)
	# Grimholt market: northern trader.
	elif room["name"] == "grimholt_market":
		_add_grimholt_merchant(origin)
	# Grimholt houses: northern villagers.
	elif room["name"] == "grimholt_house":
		_add_grimholt_villager(origin)

func _box(size: Vector3, color: Color, tex: Texture2D = null, uv_scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if tex != null:
		mat.albedo_texture = tex
		mat.uv1_scale = uv_scale
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
	if room_name == "tavern":
		_add_tavern_furniture(origin)
	else:
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

# KayKit Dungeon Pack (CC0) furniture for the Emberfell
# tavern. Bar counter = table_long turned sideways (the free pack has no
# dedicated bar piece; the paid EXTRA modular bar is not used).
func _add_tavern_furniture(origin: Vector3) -> void:
	# Bar counter along the north side; Dora stands behind it.
	_place_kaykit("table_long.gltf.glb", origin + Vector3(0, 0, -2.0), PI / 2)
	# Stools on the customer side of the bar.
	for sx in [-1.3, 0.0, 1.3]:
		_place_kaykit("stool.gltf.glb", origin + Vector3(sx, 0, -0.3), randf() * 0.4)
	# Guest table + chairs, east side.
	_place_kaykit("table_medium.gltf.glb", origin + Vector3(4.3, 0, 2.2), 0.0)
	_place_kaykit("chair.gltf.glb", origin + Vector3(2.9, 0, 2.2), -PI / 2)
	_place_kaykit("chair.gltf.glb", origin + Vector3(5.7, 0, 2.2), PI / 2)
	# Small decorated table (mugs) + stools, west side.
	_place_kaykit("table_small_decorated_A.gltf.glb", origin + Vector3(-4.8, 0, 0.6), 0.2)
	_place_kaykit("stool.gltf.glb", origin + Vector3(-3.9, 0, 0.6), 0.1)
	_place_kaykit("stool.gltf.glb", origin + Vector3(-5.7, 0, 0.6), -0.2)
	# Kegs and a barrel by the north wall.
	_place_kaykit("keg.gltf.glb", origin + Vector3(-5.9, 0, -4.6), 0.4, 0.7)
	_place_kaykit("keg.gltf.glb", origin + Vector3(-4.7, 0, -5.0), 2.2, 0.7)
	_place_kaykit("barrel_small.gltf.glb", origin + Vector3(5.9, 0, -4.6), 1.1)
	# Candle shelf on the north wall.
	_place_kaykit("shelf_small_candles.gltf.glb", origin + Vector3(-3.2, 1.7, -5.6), 0.0)

func _place_kaykit(file: String, pos: Vector3, rot_y: float, s := 1.0) -> void:
	var packed := load("res://assets/kaykit_dungeon/" + file) as PackedScene
	if packed == null:
		push_error("tavern furniture: failed to load " + file)
		return
	var inst := packed.instantiate() as Node3D
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * s
	# Grimdark sit: darken albedo slightly so the pieces read as one room.
	_tint_furniture(inst)
	add_child(inst)

func _tint_furniture(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat: Material = mi.get_surface_override_material(i)
				if mat == null:
					mat = mi.get_active_material(i)
				if mat is StandardMaterial3D:
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					sm.albedo_color = sm.albedo_color.darkened(0.12)
					mi.set_surface_override_material(i, sm)
	for c in n.get_children():
		_tint_furniture(c)

func _add_shopkeeper(origin: Vector3) -> void:
	var keeper := preload("res://src/npc/shopkeeper.gd").new()
	# Behind the table (north side).
	keeper.position = origin + Vector3(0, 0, -2.5)
	add_child(keeper)

func _add_blacksmith(origin: Vector3) -> void:
	var smith := preload("res://src/npc/blacksmith.gd").new()
	# Behind the forge (north side).
	smith.position = origin + Vector3(0, 0, -2.5)
	add_child(smith)

func _add_innkeeper(origin: Vector3) -> void:
	var v: Node3D = preload("res://src/npc/villager.gd").new()
	# Behind the bar counter (draft furnishing moved the counter in front).
	v.position = origin + Vector3(0, 0, -3.7)
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

func _add_grimholt_innkeeper(origin: Vector3) -> void:
	var v: Node3D = preload("res://src/npc/villager.gd").new()
	v.position = origin + Vector3(0, 0, -2.5)
	v.set("npc_name", "Innkeeper Yrsa")
	v.set("tunic_color", Color(0.45, 0.40, 0.50))
	v.set("wanders", false)
	v.set("kaykit_model", "Mage")
	# Seller: warm bed and hot stew against the northern cold.
	v.set("shop_title", "THE FROSTBOUND REST")
	v.set("shop_items", [
		{"name": "Rest", "price": 50, "desc": "Full HP restore, warm bed"},
		{"name": "Ale", "price": 10, "desc": "Restores 25 HP, mulled wine"},
	])
	add_child(v)

func _add_grimholt_merchant(origin: Vector3) -> void:
	var keeper := preload("res://src/npc/shopkeeper.gd").new()
	# Behind the table (north side).
	keeper.position = origin + Vector3(0, 0, -2.5)
	add_child(keeper)

func _add_grimholt_villager(origin: Vector3) -> void:
	var v: Node3D = preload("res://src/npc/villager.gd").new()
	v.position = origin + Vector3(1.5, 0, -1.0)
	v.set("npc_name", "Grimholt Villager")
	v.set("dialogue", [
		"The cold keeps the dead slow, they say. I don't find that comforting.",
		"Grimholt has stood a hundred winters. It'll stand a hundred more.",
		"You've seen the southern lands? What's it like, where the grass is green?",
	])
	v.set("tunic_color", Color(0.40, 0.42, 0.48))
	v.set("wanders", false)
	add_child(v)
