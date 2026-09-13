class_name Minimap
extends Control
## Corner minimap: a north-up window around the player drawn straight from
## the world's layout tables (no textures). Shows buildings, walls, water,
## the island and arena, foes, companions, villagers, and the current quest
## objective with an edge arrow when it lies beyond the window.

const WORLD_RADIUS := 42.0   # metres shown from the player to the edge
const REFRESH := 1.0 / 15.0

const StoneWalls := preload("res://src/world/stone_walls.gd")

var _acc := 0.0
var _player: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 190)
	# A Control's _draw() is not bounded by its rect unless it is told to
	# be. Without this, a wall or a building lying outside the window was
	# drawn at its full offset — long white lines and brown boxes ran
	# across the whole screen from the corner of the map.
	clip_contents = true

func _process(delta: float) -> void:
	_acc += delta
	if _acc >= REFRESH:
		_acc = 0.0
		queue_redraw()

func _px() -> float:
	return minf(size.x, size.y) * 0.5 / WORLD_RADIUS

## World XZ -> local minimap pixel, relative to the player at the center.
func _to_map(x: float, z: float, center: Vector3, scale: float) -> Vector2:
	return size * 0.5 + Vector2(x - center.x, z - center.z) * scale

func _draw() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var c: Vector3 = _player.global_position
	if c.x > 400.0:
		_draw_indoors()
		return
	var s := _px()
	var mid := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	# Ground disc and frame.
	draw_circle(mid, r, Color(0.03, 0.05, 0.08, 0.82))
	if _near(Regions.SOUTH, c):
		_draw_south(c, s)
	if _near(Regions.NORTH, c):
		_draw_north(c, s)
	if _near(Regions.WEST, c):
		_draw_west(c, s)
	if _near(Regions.EAST, c):
		_draw_east(c, s)
	if _near(Regions.DEEP, c):
		_draw_deep(c, s)
	if _near(Regions.TOWN, c):
		_draw_town(c, s)
	_draw_actors(c, s, mid, r)
	# Player: a small triangle facing the rig's yaw (north up).
	var yaw := 0.0
	var rig := _player.get_node_or_null("HeroRig") as Node3D
	if rig != null:
		yaw = rig.rotation.y
	var fwd := Vector2(sin(yaw), cos(yaw))  # +Z is down on the map
	var side := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([mid + fwd * 7.0, mid - fwd * 5.0 + side * 5.0, mid - fwd * 5.0 - side * 5.0]), Color(1, 1, 1))
	# The clip is square, so paint over the corners it leaves outside the
	# dial: a thick ring just wide enough to reach them.
	var bezel := (size.length() - r * 2.0) + 6.0
	draw_arc(mid, r + bezel * 0.5, 0.0, TAU, 64, Color(0.03, 0.05, 0.08, 1.0), bezel)
	# Frame and north tick.
	draw_arc(mid, r, 0.0, TAU, 64, Color(0.95, 0.78, 0.38, 0.8), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(mid.x - 4.0, 12.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.78, 0.38))

## Only draw a region's landmarks when they could fall inside the window.
func _near(region: String, c: Vector3) -> bool:
	return Regions.near(region, c, WORLD_RADIUS + 6.0)

## The southern wilds: black water, the island and its bridge.
func _draw_south(c: Vector3, s: float) -> void:
	_rect(IslandLake.WATER_X0, IslandLake.WATER_Z0, IslandLake.WATER_X1, IslandLake.WATER_Z1,
		Color(0.05, 0.12, 0.25, 0.9), c, s)
	# ISLAND_CENTER is a Vector2 of world XZ, so .y here is the world z.
	draw_circle(_to_map(IslandLake.ISLAND_CENTER.x, IslandLake.ISLAND_CENTER.y, c, s),
		IslandLake.ISLAND_RADIUS * s, Color(0.28, 0.3, 0.26))
	_rect(IslandLake.BRIDGE_X0, IslandLake.BRIDGE_Z - IslandLake.BRIDGE_W * 0.5,
		IslandLake.BRIDGE_X1, IslandLake.BRIDGE_Z + IslandLake.BRIDGE_W * 0.5,
		Color(0.45, 0.32, 0.2), c, s)

## The northern wilds: Grimholt and the frozen arena.
func _draw_north(c: Vector3, s: float) -> void:
	var arena := preload("res://src/world/frost_arena.gd")
	draw_circle(_to_map(arena.ARENA_CENTER.x, arena.ARENA_CENTER.z, c, s),
		arena.ARENA_RADIUS * s, Color(0.35, 0.5, 0.65, 0.8))
	for b in Grimholt.BUILDINGS:
		_building(Grimholt.CENTER + b[1], b[2] * Grimholt.BUILDING_SCALE, c, s)

## The Ashen Highlands: the road, Ashfall Watch, the reaver wall and the
## black glass where Kael waits.
func _draw_west(c: Vector3, s: float) -> void:
	_rect(AshenHighlands.WEST_EDGE, -AshenHighlands.ROAD_HALF,
		AshenHighlands.EAST_EDGE, AshenHighlands.ROAD_HALF,
		Color(0.22, 0.20, 0.18, 0.9), c, s)
	draw_circle(_to_map(AshenHighlands.CAMP_CENTER.x, AshenHighlands.CAMP_CENTER.z, c, s),
		AshenHighlands.CAMP_RADIUS * 0.8 * s, Color(0.32, 0.27, 0.22))
	draw_circle(_to_map(AshenHighlands.ARENA_CENTER.x, AshenHighlands.ARENA_CENTER.z, c, s),
		AshenHighlands.ARENA_RADIUS * s, Color(0.14, 0.12, 0.15, 0.95))
	var wall := Color(0.6, 0.6, 0.65, 0.9)
	var wx := AshenHighlands.WALL_X
	var wgate := AshenHighlands.GATE_HALF
	_line(wx, -AshenHighlands.HALF_Z, wx, -wgate, wall, c, s)
	_line(wx, wgate, wx, AshenHighlands.HALF_Z, wall, c, s)
	_line(AshenHighlands.WEST_EDGE, -AshenHighlands.HALF_Z,
		AshenHighlands.EAST_EDGE, -AshenHighlands.HALF_Z, wall, c, s)
	_line(AshenHighlands.WEST_EDGE, AshenHighlands.HALF_Z,
		AshenHighlands.EAST_EDGE, AshenHighlands.HALF_Z, wall, c, s)

## The Mirefen: the causeway, the chapel island, the lich-gate and the
## pool at the end of the stones.
func _draw_east(c: Vector3, s: float) -> void:
	_rect(Mirefen.WEST_EDGE, -Mirefen.HALF_Z, Mirefen.EAST_EDGE, Mirefen.HALF_Z,
		Color(0.06, 0.13, 0.12, 0.85), c, s)
	_rect(Mirefen.WEST_EDGE, -Mirefen.CAUSEWAY_HALF,
		Mirefen.EAST_EDGE, Mirefen.CAUSEWAY_HALF,
		Color(0.35, 0.36, 0.33, 0.95), c, s)
	draw_circle(_to_map(Mirefen.CHAPEL_CENTER.x, Mirefen.CHAPEL_CENTER.z, c, s),
		Mirefen.CHAPEL_RADIUS * s, Color(0.22, 0.32, 0.24))
	draw_circle(_to_map(Mirefen.POOL_CENTER.x, Mirefen.POOL_CENTER.z, c, s),
		Mirefen.POOL_RADIUS * s, Color(0.03, 0.09, 0.08, 0.95))
	var wall := Color(0.6, 0.6, 0.65, 0.9)
	_line(Mirefen.GATE_X, -Mirefen.HALF_Z, Mirefen.GATE_X, -Mirefen.GATE_HALF, wall, c, s)
	_line(Mirefen.GATE_X, Mirefen.GATE_HALF, Mirefen.GATE_X, Mirefen.HALF_Z, wall, c, s)
	_line(Mirefen.WEST_EDGE, -Mirefen.HALF_Z, Mirefen.EAST_EDGE, -Mirefen.HALF_Z, wall, c, s)
	_line(Mirefen.WEST_EDGE, Mirefen.HALF_Z, Mirefen.EAST_EDGE, Mirefen.HALF_Z, wall, c, s)

## The Sunken Vault: the hall, the gallery, its burial chambers and the
## throne at the end.
func _draw_deep(c: Vector3, s: float) -> void:
	var stone := Color(0.30, 0.29, 0.30, 0.95)
	_rect(-SunkenVault.HALL_HALF, SunkenVault.HALL_Z0,
		SunkenVault.HALL_HALF, SunkenVault.HALL_Z1, stone, c, s)
	_rect(-SunkenVault.GALLERY_HALF, SunkenVault.GALLERY_Z0,
		SunkenVault.GALLERY_HALF, SunkenVault.GALLERY_Z1, stone, c, s)
	_rect(-SunkenVault.THRONE_HALF, SunkenVault.THRONE_Z0,
		SunkenVault.THRONE_HALF, SunkenVault.THRONE_Z1, stone, c, s)
	for i in SunkenVault.CHAMBERS.size():
		var cc := SunkenVault.chamber_center(i)
		_rect(cc.x - SunkenVault.CHAMBER_HALF, cc.z - SunkenVault.CHAMBER_HALF,
			cc.x + SunkenVault.CHAMBER_HALF, cc.z + SunkenVault.CHAMBER_HALF, stone, c, s)

## Emberfell itself: the plaza, its buildings and its four gated walls.
func _draw_town(c: Vector3, s: float) -> void:
	# Cobble plaza.
	draw_circle(_to_map(VillageLayout.WELL_POS.x, VillageLayout.WELL_POS.z, c, s),
		VillageLayout.PLAZA_RADIUS * s, Color(0.25, 0.25, 0.28))
	for b in VillageLayout.BUILDINGS:
		_building(b[1], b[2] * VillageLayout.BUILDING_SCALE, c, s)
	# Walls: the outer ring, and the four village walls with their gates.
	var half: float = StoneWalls.HALF
	var wall := Color(0.6, 0.6, 0.65, 0.9)
	var gate: float = StoneWalls.GATE_HALF
	_line(-half, StoneWalls.NORTH_Z, -half, -gate, wall, c, s)
	_line(-half, gate, -half, StoneWalls.WILD_Z, wall, c, s)
	_line(half, StoneWalls.NORTH_Z, half, -gate, wall, c, s)
	_line(half, gate, half, StoneWalls.WILD_Z, wall, c, s)
	_line(-half, StoneWalls.WILD_Z, half, StoneWalls.WILD_Z, wall, c, s)
	_line(-half, StoneWalls.NORTH_Z, -3.0, StoneWalls.NORTH_Z, wall, c, s)
	_line(3.0, StoneWalls.NORTH_Z, half, StoneWalls.NORTH_Z, wall, c, s)
	for gz: float in [half, -half]:
		_line(-half, gz, -gate, gz, wall, c, s)
		_line(gate, gz, half, gz, wall, c, s)

## Everything that moves: villagers, foes, companions, the objective.
func _draw_actors(c: Vector3, s: float, mid: Vector2, r: float) -> void:
	for n in get_tree().get_nodes_in_group("villagers"):
		var v := n as Node3D
		if v != null and v.visible and v.global_position.x < 400.0:
			_dot(v.global_position, 2.5, Color(1.0, 0.85, 0.3), c, s)
	for n in get_tree().get_nodes_in_group("skeletons"):
		var f := n as Node3D
		if f == null or bool(f.get("dead")):
			continue
		if f.is_in_group("boss"):
			_dot(f.global_position, 5.0, Color(1.0, 0.2, 0.15), c, s)
		else:
			_dot(f.global_position, 2.5, Color(0.95, 0.35, 0.3), c, s)
	for n in get_tree().get_nodes_in_group("companions"):
		var comp := n as Node3D
		if comp != null:
			_dot(comp.global_position, 3.0, Color(0.5, 1.0, 0.6), c, s)
	# Objective.
	var obj: Variant = QuestMan.objective_position()
	if obj != null:
		var op: Vector3 = obj
		var p := _to_map(op.x, op.z, c, s)
		var d := p - mid
		if d.length() <= r - 8.0:
			_diamond(p, 6.0, Color(1.0, 0.85, 0.3))
		else:
			var dir := d.normalized()
			var tip := mid + dir * (r - 6.0)
			var back := tip - dir * 12.0
			var perp := Vector2(-dir.y, dir.x) * 6.0
			draw_colored_polygon(PackedVector2Array([tip, back + perp, back - perp]), Color(1.0, 0.85, 0.3))
			var metres := Vector2(op.x - c.x, op.z - c.z).length()
			var font := ThemeDB.fallback_font
			var txt := "%dm" % int(metres)
			var tpos := mid + dir * (r - 24.0) - Vector2(font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, -4)
			draw_string(font, tpos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.5))

func _draw_indoors() -> void:
	var mid := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(mid, r, Color(0.03, 0.05, 0.08, 0.82))
	draw_arc(mid, r, 0.0, TAU, 64, Color(0.95, 0.78, 0.38, 0.8), 2.0, true)
	var font := ThemeDB.fallback_font
	var txt := "INDOORS"
	draw_string(font, mid - Vector2(font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, -5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.85))

func _rect(x0: float, z0: float, x1: float, z1: float, col: Color, c: Vector3, s: float) -> void:
	var a := _to_map(x0, z0, c, s)
	var b := _to_map(x1, z1, c, s)
	draw_rect(Rect2(a, b - a), col)

func _building(pos: Vector3, fp: Vector2, c: Vector3, s: float) -> void:
	_rect(pos.x - fp.x * 0.5, pos.z - fp.y * 0.5, pos.x + fp.x * 0.5, pos.z + fp.y * 0.5,
		Color(0.55, 0.45, 0.35), c, s)

func _line(x0: float, z0: float, x1: float, z1: float, col: Color, c: Vector3, s: float) -> void:
	draw_line(_to_map(x0, z0, c, s), _to_map(x1, z1, c, s), col, 1.5, true)

func _dot(pos: Vector3, radius: float, col: Color, c: Vector3, s: float) -> void:
	var p := _to_map(pos.x, pos.z, c, s)
	if (p - size * 0.5).length() < minf(size.x, size.y) * 0.5 - 3.0:
		draw_circle(p, radius, col)

func _diamond(p: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)
