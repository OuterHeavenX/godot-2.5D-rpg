class_name AshenHighlands
extends Node3D
## The Ashen Highlands: the burnt country west of Emberfell, opened when
## Morvain falls. Nothing grows here. The Ash Reavers took the high ground
## after the fires and have held it since.
##
## Layout, running west from the village's west gate at x=-30:
##   -30 .. -240   open highland, burnt trunks, basalt, ash drifts
##  -210           Ashfall Watch, a half-ruined tower held by the Warden
##  -270           the reaver wall, with a gap on the road
##  -286           Kael's amphitheatre

const EAST_EDGE := -30.0
const WEST_EDGE := -302.0
const HALF_Z := 30.0
const WALL_X := -270.0        # the reavers' wall across the road
const GATE_HALF := 3.0        # gap in that wall, on the road
const ROAD_HALF := 2.6
const CAMP_CENTER := Vector3(-210, 0, 0)
const CAMP_RADIUS := 15.0
const ARENA_CENTER := Vector3(-286, 0, 0)
const ARENA_RADIUS := 14.0

## Loaded when he is placed, not when this script is parsed: the boss
## pulls in the whole enemy stack, which is not needed to read the map.
const KAEL_SCENE_PATH := "res://src/enemy/kael.tscn"

var _rng := RandomNumberGenerator.new()

var _ash_mat: StandardMaterial3D
var _char_mat: StandardMaterial3D
var _basalt_mat: StandardMaterial3D
var _drift_mat: StandardMaterial3D
var _ember_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
var _canvas_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D

## True on the road, where scenery keeps clear.
static func is_on_road(x: float, z: float, margin := 0.0) -> bool:
	return x < EAST_EDGE and absf(z) <= ROAD_HALF + margin

## True inside the Warden's camp, which stays free of foes and clutter.
static func is_in_camp(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x - CAMP_CENTER.x, z - CAMP_CENTER.z).length() < CAMP_RADIUS + margin

## True on Kael's ground.
static func is_in_arena(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x - ARENA_CENTER.x, z - ARENA_CENTER.z).length() < ARENA_RADIUS + margin

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.WEST)
	_rng.seed = 515151
	_make_materials()
	_build_ground()
	_build_cliffs()
	_build_reaver_wall()
	var batch := PropBatch.new()
	_dunes(batch)
	_scatter(batch)
	_build_camp(batch)
	_build_arena(batch)
	batch.build(self)
	_spawn_kael()

func _mat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _make_materials() -> void:
	_ash_mat = _mat(Color(0.34, 0.31, 0.29))
	_char_mat = _mat(Color(0.20, 0.17, 0.16))
	_basalt_mat = _mat(Color(0.37, 0.36, 0.39), 0.85)
	_drift_mat = _mat(Color(0.48, 0.45, 0.43))
	_road_mat = _mat(Color(0.52, 0.49, 0.45))
	_wood_mat = _mat(Color(0.34, 0.25, 0.18))
	_canvas_mat = _mat(Color(0.50, 0.40, 0.29))
	_glass_mat = _mat(Color(0.16, 0.14, 0.17), 0.25)
	_glass_mat.metallic = 0.3
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(0.9, 0.35, 0.12)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.45, 0.12)
	_ember_mat.emission_energy_multiplier = 2.2
	_ember_mat.roughness = 0.6

func _build_ground() -> void:
	var width := EAST_EDGE - WEST_EDGE
	var mid := (EAST_EDGE + WEST_EDGE) * 0.5
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, HALF_Z * 2.0)
	ground.mesh = pm
	ground.material_override = _ash_mat
	ground.position = Vector3(mid, 0.0, 0.0)
	add_child(ground)
	var body := StaticBody3D.new()
	body.name = "HighlandGround"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, HALF_Z * 2.0)
	cs.shape = box
	cs.position = Vector3(mid, -0.5, 0.0)
	body.add_child(cs)
	add_child(body)
	# The road the Warden's riders still use.
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(width, ROAD_HALF * 2.0)
	road.mesh = rm
	road.material_override = _road_mat
	road.position = Vector3(mid, 0.07, 0.0)
	add_child(road)

## Sheer black cliffs pen the highlands in on three sides.
func _build_cliffs() -> void:
	var body := StaticBody3D.new()
	body.name = "HighlandCliffs"
	add_child(body)
	var runs := [
		[Vector3((EAST_EDGE + WEST_EDGE) * 0.5, 3.0, HALF_Z + 1.5),
			Vector3(EAST_EDGE - WEST_EDGE, 6.0, 3.0)],
		[Vector3((EAST_EDGE + WEST_EDGE) * 0.5, 3.0, -HALF_Z - 1.5),
			Vector3(EAST_EDGE - WEST_EDGE, 6.0, 3.0)],
		[Vector3(WEST_EDGE - 1.5, 3.0, 0.0), Vector3(3.0, 6.0, HALF_Z * 2.0 + 6.0)],
	]
	for run: Array in runs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = run[1]
		mi.mesh = bm
		mi.material_override = _basalt_mat
		mi.position = run[0]
		add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = run[1]
		cs.shape = shape
		cs.position = run[0]
		body.add_child(cs)

## The reavers' wall of stakes and rubble, with the road running through.
func _build_reaver_wall() -> void:
	var body := StaticBody3D.new()
	body.name = "ReaverWall"
	add_child(body)
	for side: float in [1.0, -1.0]:
		var span := HALF_Z - GATE_HALF
		var mid := side * (GATE_HALF + span * 0.5)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 4.5, span)
		mi.mesh = bm
		mi.material_override = _char_mat
		mi.position = Vector3(WALL_X, 2.25, mid)
		add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 6.0, span)
		cs.shape = shape
		cs.position = Vector3(WALL_X, 3.0, mid)
		body.add_child(cs)
	# Stakes flanking the gap, with skulls on them: the reavers' welcome.
	for side2: float in [1.0, -1.0]:
		var post := MeshInstance3D.new()
		var pmesh := CylinderMesh.new()
		pmesh.top_radius = 0.18
		pmesh.bottom_radius = 0.22
		pmesh.height = 5.0
		pmesh.radial_segments = 6
		post.mesh = pmesh
		post.material_override = _wood_mat
		post.position = Vector3(WALL_X, 2.5, side2 * GATE_HALF)
		add_child(post)
		var fire := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.32
		fm.height = 0.64
		fm.radial_segments = 6
		fm.rings = 4
		fire.mesh = fm
		fire.material_override = _ember_mat
		fire.position = Vector3(WALL_X, 5.1, side2 * GATE_HALF)
		add_child(fire)

## Somewhere out in the open highland, clear of the road, camp and arena.
func _wild_pos() -> Vector3:
	for attempt in 18:
		var p := Vector3(
			_rng.randf_range(WEST_EDGE + 4.0, EAST_EDGE - 2.0), 0.0,
			_rng.randf_range(-HALF_Z + 2.0, HALF_Z - 2.0))
		if is_on_road(p.x, p.z, 1.8):
			continue
		if is_in_camp(p.x, p.z, 2.0):
			continue
		if is_in_arena(p.x, p.z, 2.0):
			continue
		if absf(p.x - WALL_X) < 4.0:
			continue
		return p
	return Vector3(-120, 0, 18)

func _scatter(batch: PropBatch) -> void:
	var body := StaticBody3D.new()
	body.name = "HighlandProps"
	add_child(body)
	# Burnt trunks: black, branchless, snapped off at different heights.
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _char_mat
	for i in 260:
		var p := _wild_pos()
		var h := _rng.randf_range(1.8, 5.0)
		var lean := _rng.randf_range(-0.2, 0.2)
		var b := Basis(Vector3.FORWARD, lean) * Basis.from_scale(Vector3(1.0, h, 1.0))
		batch.add("trunk", trunk_mesh, Transform3D(b, p + Vector3(0, h * 0.5, 0)))
		_collide(body, p + Vector3(0, 1.0, 0), 0.35, 2.0)
	# Basalt spikes shouldering up out of the ash.
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.9
	spike_mesh.height = 1.0
	spike_mesh.radial_segments = 5
	spike_mesh.material = _basalt_mat
	for i in 190:
		var p2 := _wild_pos()
		var h2 := _rng.randf_range(1.5, 4.5)
		var w2 := _rng.randf_range(0.6, 1.4)
		var b2 := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis.from_scale(Vector3(w2, h2, w2))
		batch.add("spike", spike_mesh, Transform3D(b2, p2))
		_collide(body, p2 + Vector3(0, 0.8, 0), 0.8 * w2, 1.6)
	# Ash drifts: soft pale mounds, no collision.
	var drift_mesh := SphereMesh.new()
	drift_mesh.radius = 1.0
	drift_mesh.height = 2.0
	drift_mesh.radial_segments = 8
	drift_mesh.rings = 4
	drift_mesh.material = _drift_mat
	for i in 210:
		var p3 := _wild_pos()
		var r3 := _rng.randf_range(0.9, 2.6)
		var b3 := Basis.from_scale(Vector3(r3, r3 * 0.22, r3 * _rng.randf_range(0.7, 1.3)))
		batch.add("drift", drift_mesh, Transform3D(b3, p3 + Vector3(0, 0.05, 0)))
	# Embers still burning in the ash, days or years later.
	var ember_mesh := BoxMesh.new()
	ember_mesh.size = Vector3(0.3, 0.18, 0.3)
	ember_mesh.material = _ember_mat
	for i in 150:
		var p4 := _wild_pos()
		var b4 := Basis(Vector3.UP, _rng.randf() * TAU)
		batch.add("ember", ember_mesh, Transform3D(b4, p4 + Vector3(0, 0.1, 0)))

## Long drifts of ash banked up across the plain, so the eye has
## something to read the distance against.
func _dunes(batch: PropBatch) -> void:
	var dune := SphereMesh.new()
	dune.radius = 1.0
	dune.height = 2.0
	dune.radial_segments = 10
	dune.rings = 5
	dune.material = _drift_mat
	for i in 30:
		var p := _wild_pos()
		# The mesh is a unit sphere, so these are half-extents: a "4" here
		# is eight metres of drift.
		var half_len := _rng.randf_range(2.5, 6.0)
		var b := Basis(Vector3.UP, _rng.randf_range(-0.6, 0.6)) \
			* Basis.from_scale(Vector3(half_len, _rng.randf_range(0.25, 0.55),
				_rng.randf_range(1.0, 2.2)))
		batch.add("dune", dune, Transform3D(b, p))

func _collide(body: StaticBody3D, at: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = at
	body.add_child(cs)

## Ashfall Watch: a broken tower, a palisade, tents and a fire that the
## Warden keeps lit so travellers know somebody is still holding on.
func _build_camp(batch: PropBatch) -> void:
	var body := StaticBody3D.new()
	body.name = "CampCollision"
	add_child(body)
	var c := CAMP_CENTER
	# Packed earth under the camp so it reads as cleared ground.
	var floor_mi := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = CAMP_RADIUS * 0.8
	fm.bottom_radius = CAMP_RADIUS * 0.8
	fm.height = 0.12
	fm.radial_segments = 20
	floor_mi.mesh = fm
	floor_mi.material_override = _road_mat
	floor_mi.position = c + Vector3(0, 0.12, 0)
	add_child(floor_mi)
	# The tower: three stacked blocks, the top one broken open.
	var stack := [
		[Vector3(0, 2.0, -6.0), Vector3(6.0, 4.0, 6.0)],
		[Vector3(0, 5.4, -6.0), Vector3(5.0, 3.0, 5.0)],
		[Vector3(-0.7, 7.9, -6.0), Vector3(3.2, 2.2, 4.4)],
	]
	for part: Array in stack:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		mi.mesh = bm
		mi.material_override = _basalt_mat
		mi.position = c + part[0]
		add_child(mi)
	var tcs := CollisionShape3D.new()
	var tshape := BoxShape3D.new()
	tshape.size = Vector3(6.0, 10.0, 6.0)
	tcs.shape = tshape
	tcs.position = c + Vector3(0, 5.0, -6.0)
	body.add_child(tcs)
	# Palisade of stakes around the camp, open towards the road.
	var stake_mesh := CylinderMesh.new()
	stake_mesh.top_radius = 0.0
	stake_mesh.bottom_radius = 0.17
	stake_mesh.height = 2.4
	stake_mesh.radial_segments = 5
	stake_mesh.material = _wood_mat
	for i in 46:
		var ang := TAU * float(i) / 46.0
		if absf(sin(ang)) < 0.28 and cos(ang) > 0.0:
			continue  # leave the road side open
		var p := c + Vector3(cos(ang), 0, sin(ang)) * (CAMP_RADIUS * 0.82)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis(Vector3.FORWARD, _rng.randf_range(-0.08, 0.08))
		batch.add("stake", stake_mesh, Transform3D(b, p + Vector3(0, 1.2, 0)))
	# Two tents.
	var tent_mesh := CylinderMesh.new()
	tent_mesh.top_radius = 0.0
	tent_mesh.bottom_radius = 2.0
	tent_mesh.height = 2.2
	tent_mesh.radial_segments = 4
	tent_mesh.material = _canvas_mat
	for offset: Vector3 in [Vector3(6.5, 0, 4.0), Vector3(-6.0, 0, 5.5)]:
		var b2 := Basis(Vector3.UP, _rng.randf() * TAU)
		batch.add("tent", tent_mesh, Transform3D(b2, c + offset + Vector3(0, 1.1, 0)))
	# The watchfire, the one real light out here.
	_build_fire(c + Vector3(0, 0, 2.0), 2.6, Color(1.0, 0.55, 0.2), 9.0)

## A ring of stones, logs, and a light that flickers.
func _build_fire(at: Vector3, size: float, color: Color, energy: float) -> void:
	var logs := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = size * 0.45
	lm.bottom_radius = size * 0.6
	lm.height = 0.4
	lm.radial_segments = 8
	logs.mesh = lm
	logs.material_override = _char_mat
	logs.position = at + Vector3(0, 0.2, 0)
	add_child(logs)
	for i in 3:
		var flame := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.0
		fm.bottom_radius = size * (0.22 - i * 0.05)
		fm.height = size * (0.5 + i * 0.16)
		fm.radial_segments = 6
		flame.mesh = fm
		flame.material_override = _ember_mat
		var ang := TAU * float(i) / 3.0
		flame.position = at + Vector3(cos(ang) * size * 0.16, 0.35 + size * 0.25,
			sin(ang) * size * 0.16)
		flame.name = "Flame%d" % i
		add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = size * 9.0
	light.position = at + Vector3(0, size * 0.8, 0)
	light.shadow_enabled = false
	add_child(light)

## Kael's ground: a bowl of black glass where the fire burned hottest.
func _build_arena(batch: PropBatch) -> void:
	var c := ARENA_CENTER
	var floor_mi := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = ARENA_RADIUS
	fm.bottom_radius = ARENA_RADIUS
	fm.height = 0.25
	fm.radial_segments = 36
	floor_mi.mesh = fm
	floor_mi.material_override = _glass_mat
	floor_mi.position = c + Vector3(0, 0.16, 0)
	add_child(floor_mi)
	# A ring of basalt teeth around the bowl, open on the road side.
	var tooth := CylinderMesh.new()
	tooth.top_radius = 0.0
	tooth.bottom_radius = 1.1
	tooth.height = 1.0
	tooth.radial_segments = 5
	tooth.material = _basalt_mat
	var body := StaticBody3D.new()
	body.name = "ArenaTeeth"
	add_child(body)
	for i in 26:
		var ang := TAU * float(i) / 26.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		if dir.x > 0.72:
			continue  # the way in
		var p := c + dir * (ARENA_RADIUS + 1.0)
		var h := _rng.randf_range(3.0, 6.0)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis.from_scale(Vector3(1.0, h, 1.0))
		batch.add("tooth", tooth, Transform3D(b, p))
		_collide(body, p + Vector3(0, 1.5, 0), 1.0, 3.0)
	# Kael's bonfire at the far edge, and his banner over it.
	_build_fire(c + Vector3(-8.0, 0, 0), 3.4, Color(1.0, 0.4, 0.15), 12.0)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.12
	pm.bottom_radius = 0.15
	pm.height = 6.0
	pm.radial_segments = 6
	pole.mesh = pm
	pole.material_override = _wood_mat
	pole.position = c + Vector3(-11.0, 3.0, 3.0)
	add_child(pole)
	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 2.4, 1.8)
	banner.mesh = bm
	banner.material_override = _mat(Color(0.55, 0.12, 0.10))
	banner.position = c + Vector3(-11.0, 4.4, 3.9)
	add_child(banner)

func _spawn_kael() -> void:
	var packed := load(KAEL_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("ashen_highlands: could not load Kael")
		return
	var kael := packed.instantiate()
	kael.position = ARENA_CENTER + Vector3(-2.0, 0.1, 0.0)
	kael.set("roam_min", Vector2(ARENA_CENTER.x - 12.0, -12.0))
	kael.set("roam_max", Vector2(ARENA_CENTER.x + 12.0, 12.0))
	add_child(kael)
