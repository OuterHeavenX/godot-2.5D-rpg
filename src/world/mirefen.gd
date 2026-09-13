class_name Mirefen
extends Node3D
## The Mirefen: the drowned country east of Emberfell, opened when Kael
## falls. A flooded plain of standing water, reeds and sunken stone, with
## one raised causeway running through it — step off the stones and you
## are wading.
##
## Layout, running east from the village's east gate at x=30:
##    30 .. 240    open fen, water, reeds, dead willows, sunken pillars
##   210           the Drowned Chapel, where what is left of the order lives
##   270           the lich-gate, a ruin across the causeway
##   286           Gholl's pool

const WEST_EDGE := 30.0
const EAST_EDGE := 302.0
const HALF_Z := 30.0
const GATE_X := 270.0
const GATE_HALF := 3.0
const CAUSEWAY_HALF := 2.8
const CAUSEWAY_Y := 0.35
const WATER_Y := 0.16
const CHAPEL_CENTER := Vector3(210, 0, 0)
const CHAPEL_RADIUS := 15.0
const POOL_CENTER := Vector3(286, 0, 0)
const POOL_RADIUS := 14.0

const GHOLL_SCENE_PATH := "res://src/enemy/gholl.tscn"

var _rng := RandomNumberGenerator.new()

var _mud_mat: StandardMaterial3D
var _water_mat: StandardMaterial3D
var _stone_mat: StandardMaterial3D
var _reed_mat: StandardMaterial3D
var _willow_mat: StandardMaterial3D
var _rot_mat: StandardMaterial3D
var _moss_mat: StandardMaterial3D

## True on the raised causeway, the one piece of dry footing out here.
static func is_on_causeway(x: float, z: float, margin := 0.0) -> bool:
	return x > WEST_EDGE and absf(z) <= CAUSEWAY_HALF + margin

## True on the chapel's island.
static func is_at_chapel(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x - CHAPEL_CENTER.x, z - CHAPEL_CENTER.z).length() < CHAPEL_RADIUS + margin

## True in Gholl's pool.
static func is_in_pool(x: float, z: float, margin := 0.0) -> bool:
	return Vector2(x - POOL_CENTER.x, z - POOL_CENTER.z).length() < POOL_RADIUS + margin

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.EAST)
	_rng.seed = 717171
	_make_materials()
	_build_ground()
	_build_causeway()
	_build_banks()
	_build_lich_gate()
	var batch := PropBatch.new()
	_scatter(batch)
	_build_chapel(batch)
	_build_pool(batch)
	batch.build(self)
	_spawn_gholl()

func _mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _make_materials() -> void:
	_mud_mat = _mat(Color(0.26, 0.24, 0.19))
	_stone_mat = _mat(Color(0.42, 0.43, 0.40))
	_reed_mat = _mat(Color(0.42, 0.44, 0.24))
	_willow_mat = _mat(Color(0.28, 0.24, 0.19))
	_rot_mat = _mat(Color(0.32, 0.34, 0.25))
	_moss_mat = _mat(Color(0.30, 0.37, 0.28))
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.10, 0.17, 0.14, 0.80)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 0.12
	_water_mat.metallic = 0.45

func _build_ground() -> void:
	var width := EAST_EDGE - WEST_EDGE
	var mid := (EAST_EDGE + WEST_EDGE) * 0.5
	var bed := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, HALF_Z * 2.0)
	bed.mesh = pm
	bed.material_override = _mud_mat
	bed.position = Vector3(mid, 0.0, 0.0)
	add_child(bed)
	var body := StaticBody3D.new()
	body.name = "FenGround"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.0, HALF_Z * 2.0)
	cs.shape = box
	cs.position = Vector3(mid, -0.5, 0.0)
	body.add_child(cs)
	add_child(body)
	# Standing water over the whole plain, a hand's depth above the mud.
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(width, HALF_Z * 2.0)
	water.mesh = wm
	water.material_override = _water_mat
	water.position = Vector3(mid, WATER_Y, 0.0)
	water.name = "FenWater"
	add_child(water)

## The causeway: old paving raised out of the water, running the length of
## the fen. It is the road, the drainage and the only safe ground.
func _build_causeway() -> void:
	var width := EAST_EDGE - WEST_EDGE
	var mid := (EAST_EDGE + WEST_EDGE) * 0.5
	var road := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, CAUSEWAY_Y, CAUSEWAY_HALF * 2.0)
	road.mesh = bm
	road.material_override = _stone_mat
	road.position = Vector3(mid, CAUSEWAY_Y * 0.5, 0.0)
	add_child(road)
	var body := StaticBody3D.new()
	body.name = "CausewayTop"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, CAUSEWAY_Y, CAUSEWAY_HALF * 2.0)
	cs.shape = box
	cs.position = Vector3(mid, CAUSEWAY_Y * 0.5, 0.0)
	body.add_child(cs)
	add_child(body)

## Low banks pen the fen in: beyond them the water simply goes on.
func _build_banks() -> void:
	var body := StaticBody3D.new()
	body.name = "FenBanks"
	add_child(body)
	var width := EAST_EDGE - WEST_EDGE
	var mid := (EAST_EDGE + WEST_EDGE) * 0.5
	var runs := [
		[Vector3(mid, 1.5, HALF_Z + 1.5), Vector3(width, 3.0, 3.0)],
		[Vector3(mid, 1.5, -HALF_Z - 1.5), Vector3(width, 3.0, 3.0)],
		[Vector3(EAST_EDGE + 1.5, 1.5, 0.0), Vector3(3.0, 3.0, HALF_Z * 2.0 + 6.0)],
	]
	for run: Array in runs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = run[1]
		mi.mesh = bm
		mi.material_override = _rot_mat
		mi.position = run[0]
		add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(run[1].x, 6.0, run[1].z)
		cs.shape = shape
		cs.position = run[0]
		body.add_child(cs)

## The lich-gate: a chapel arch that used to stand over the causeway, and
## the wall of tombs that grew out from it.
func _build_lich_gate() -> void:
	var body := StaticBody3D.new()
	body.name = "LichGate"
	add_child(body)
	for side: float in [1.0, -1.0]:
		var span := HALF_Z - GATE_HALF
		var mid := side * (GATE_HALF + span * 0.5)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.4, 3.6, span)
		mi.mesh = bm
		mi.material_override = _stone_mat
		mi.position = Vector3(GATE_X, 1.8, mid)
		add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.4, 6.0, span)
		cs.shape = shape
		cs.position = Vector3(GATE_X, 3.0, mid)
		body.add_child(cs)
	# The arch itself, still standing over the road.
	for side2: float in [1.0, -1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.0, 5.5, 1.0)
		post.mesh = pm
		post.material_override = _stone_mat
		post.position = Vector3(GATE_X, 2.75, side2 * GATE_HALF)
		add_child(post)
	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.2, 0.9, GATE_HALF * 2.0 + 1.0)
	lintel.mesh = lm
	lintel.material_override = _stone_mat
	lintel.position = Vector3(GATE_X, 5.9, 0)
	add_child(lintel)

## Somewhere out in the water, clear of the causeway, chapel and pool.
func _wet_pos() -> Vector3:
	for attempt in 18:
		var p := Vector3(
			_rng.randf_range(WEST_EDGE + 3.0, EAST_EDGE - 3.0), 0.0,
			_rng.randf_range(-HALF_Z + 2.0, HALF_Z - 2.0))
		if is_on_causeway(p.x, p.z, 1.6):
			continue
		if is_at_chapel(p.x, p.z, 2.0):
			continue
		if is_in_pool(p.x, p.z, 2.0):
			continue
		if absf(p.x - GATE_X) < 4.0:
			continue
		return p
	return Vector3(120, 0, 18)

func _scatter(batch: PropBatch) -> void:
	var body := StaticBody3D.new()
	body.name = "FenProps"
	add_child(body)
	# Reed beds: tall, thin, and everywhere. No collision — wade through.
	var reed := BoxMesh.new()
	reed.size = Vector3(0.06, 1.0, 0.06)
	reed.material = _reed_mat
	for i in 900:
		var p := _wet_pos()
		for blade in 5:
			var h := _rng.randf_range(1.1, 2.2)
			var b := Basis(Vector3.UP, _rng.randf() * TAU) \
				* Basis(Vector3.FORWARD, _rng.randf_range(-0.25, 0.25)) \
				* Basis.from_scale(Vector3(1.0, h, 1.0))
			var off := Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))
			batch.add("reed", reed, Transform3D(b, p + off + Vector3(0, h * 0.5, 0)))
	# Dead willows leaning over the water.
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.42
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.material = _willow_mat
	var bough := CylinderMesh.new()
	bough.top_radius = 0.05
	bough.bottom_radius = 0.12
	bough.height = 1.0
	bough.radial_segments = 5
	bough.material = _willow_mat
	for i in 70:
		var p2 := _wet_pos()
		var h2 := _rng.randf_range(2.4, 4.8)
		var lean := _rng.randf_range(-0.28, 0.28)
		var b2 := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.FORWARD, lean) \
			* Basis.from_scale(Vector3(1.0, h2, 1.0))
		batch.add("willow", trunk, Transform3D(b2, p2 + Vector3(0, h2 * 0.5, 0)))
		for arm in 3:
			var ang := _rng.randf() * TAU
			var bb := Basis(Vector3.UP, ang) * Basis(Vector3.FORWARD, 1.1) \
				* Basis.from_scale(Vector3(1.0, _rng.randf_range(1.2, 2.2), 1.0))
			batch.add("bough", bough,
				Transform3D(bb, p2 + Vector3(cos(ang) * 0.5, h2 * 0.85, sin(ang) * 0.5)))
		_collide(body, p2 + Vector3(0, 1.0, 0), 0.45, 2.2)
	# Rotting stumps and mud hummocks that break the surface.
	var hummock := SphereMesh.new()
	hummock.radius = 1.0
	hummock.height = 2.0
	hummock.radial_segments = 7
	hummock.rings = 4
	hummock.material = _moss_mat
	for i in 140:
		var p3 := _wet_pos()
		var r3 := _rng.randf_range(0.8, 2.4)
		var b3 := Basis.from_scale(Vector3(r3, r3 * 0.3, r3 * _rng.randf_range(0.7, 1.3)))
		batch.add("hummock", hummock, Transform3D(b3, p3 + Vector3(0, 0.08, 0)))
	# Sunken pillars: whatever stood here before the water came.
	var pillar := BoxMesh.new()
	pillar.size = Vector3(0.9, 1.0, 0.9)
	pillar.material = _stone_mat
	for i in 60:
		var p4 := _wet_pos()
		var h4 := _rng.randf_range(1.0, 4.0)
		var b4 := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis(Vector3.FORWARD, _rng.randf_range(-0.14, 0.14)) \
			* Basis.from_scale(Vector3(1.0, h4, 1.0))
		batch.add("pillar", pillar, Transform3D(b4, p4 + Vector3(0, h4 * 0.4, 0)))
		_collide(body, p4 + Vector3(0, 1.0, 0), 0.6, 2.0)
	# Grave markers leaning in the shallows near the lich-gate.
	var marker := BoxMesh.new()
	marker.size = Vector3(0.7, 1.2, 0.14)
	marker.material = _stone_mat
	for i in 50:
		var p5 := _wet_pos()
		var b5 := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis(Vector3.FORWARD, _rng.randf_range(-0.4, 0.4))
		batch.add("marker", marker, Transform3D(b5, p5 + Vector3(0, 0.6, 0)))

func _collide(body: StaticBody3D, at: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = at
	body.add_child(cs)

## The Drowned Chapel: a stone hall standing on the last dry island in the
## fen, with what is left of its order still keeping the lamps lit.
func _build_chapel(batch: PropBatch) -> void:
	var c := CHAPEL_CENTER
	var body := StaticBody3D.new()
	body.name = "ChapelCollision"
	add_child(body)
	# The island.
	var island := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = CHAPEL_RADIUS * 0.85
	im.bottom_radius = CHAPEL_RADIUS
	im.height = 0.8
	im.radial_segments = 22
	island.mesh = im
	island.material_override = _moss_mat
	island.position = c + Vector3(0, 0.25, 0)
	add_child(island)
	var icol := CollisionShape3D.new()
	var icyl := CylinderShape3D.new()
	icyl.radius = CHAPEL_RADIUS * 0.9
	icyl.height = 0.8
	icol.shape = icyl
	icol.position = c + Vector3(0, 0.25, 0)
	body.add_child(icol)
	# The hall: a long nave, its east end sunk into the water.
	var nave := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(11.0, 5.0, 6.0)
	nave.mesh = nm
	nave.material_override = _stone_mat
	nave.position = c + Vector3(-1.0, 2.3, -5.0)
	nave.rotation.z = 0.05
	add_child(nave)
	var ncol := CollisionShape3D.new()
	var nbox := BoxShape3D.new()
	nbox.size = Vector3(11.0, 6.0, 6.0)
	ncol.shape = nbox
	ncol.position = c + Vector3(-1.0, 3.0, -5.0)
	body.add_child(ncol)
	# A tower at the west end, leaning with the ground.
	var tower := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(4.0, 9.0, 4.0)
	tower.mesh = tm
	tower.material_override = _stone_mat
	tower.position = c + Vector3(-6.0, 4.4, -5.0)
	tower.rotation.z = 0.07
	add_child(tower)
	var tcol := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(4.0, 10.0, 4.0)
	tcol.shape = tbox
	tcol.position = c + Vector3(-6.0, 5.0, -5.0)
	body.add_child(tcol)
	# Lamps on poles: the order still lights them every dusk.
	for offset: Vector3 in [Vector3(5.0, 0, 2.0), Vector3(-5.0, 0, 4.0), Vector3(2.0, 0, 6.0)]:
		_build_lamp(c + offset)
	# Broken pews and crates around the island.
	var crate := BoxMesh.new()
	crate.size = Vector3(1.2, 0.8, 0.9)
	crate.material = _willow_mat
	for i in 10:
		var ang := _rng.randf() * TAU
		var rad := _rng.randf_range(6.0, CHAPEL_RADIUS * 0.8)
		var b := Basis(Vector3.UP, _rng.randf() * TAU)
		batch.add("crate", crate,
			Transform3D(b, c + Vector3(cos(ang) * rad, 0.9, sin(ang) * rad)))

## A green lamp on a pole — the chapel's mark, and the only warm light in
## the fen.
func _build_lamp(at: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.09
	pm.height = 3.2
	pm.radial_segments = 5
	pole.mesh = pm
	pole.material_override = _willow_mat
	pole.position = at + Vector3(0, 1.6, 0)
	add_child(pole)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.7, 1.0, 0.75)
	glow.emission_enabled = true
	glow.emission = Color(0.45, 1.0, 0.6)
	glow.emission_energy_multiplier = 2.6
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.22
	fm.height = 0.44
	fm.radial_segments = 6
	fm.rings = 4
	flame.mesh = fm
	flame.material_override = glow
	flame.position = at + Vector3(0, 3.3, 0)
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(0.62, 0.92, 0.72)
	light.light_energy = 1.7
	light.omni_range = 10.0
	light.shadow_enabled = false
	light.position = at + Vector3(0, 3.3, 0)
	add_child(light)

## Gholl's pool: deeper water, still as glass, ringed with the stones of
## whatever the fen swallowed first.
func _build_pool(batch: PropBatch) -> void:
	var c := POOL_CENTER
	var pool := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = POOL_RADIUS
	pm.bottom_radius = POOL_RADIUS
	pm.height = 0.2
	pm.radial_segments = 32
	pool.mesh = pm
	var deep := StandardMaterial3D.new()
	deep.albedo_color = Color(0.04, 0.09, 0.08, 0.92)
	deep.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	deep.roughness = 0.08
	deep.metallic = 0.55
	pool.material_override = deep
	pool.position = c + Vector3(0, WATER_Y + 0.02, 0)
	add_child(pool)
	# A ring of standing stones, open on the causeway side.
	var stone := BoxMesh.new()
	stone.size = Vector3(1.2, 1.0, 1.2)
	stone.material = _stone_mat
	var body := StaticBody3D.new()
	body.name = "PoolStones"
	add_child(body)
	for i in 24:
		var ang := TAU * float(i) / 24.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		if dir.x < -0.72:
			continue  # the way in, from the causeway
		var p := c + dir * (POOL_RADIUS + 1.2)
		var h := _rng.randf_range(2.5, 5.0)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis(Vector3.FORWARD, _rng.randf_range(-0.1, 0.1)) \
			* Basis.from_scale(Vector3(1.0, h, 1.0))
		batch.add("standing_stone", stone, Transform3D(b, p + Vector3(0, h * 0.4, 0)))
		_collide(body, p + Vector3(0, 1.5, 0), 0.8, 3.0)

func _spawn_gholl() -> void:
	var packed := load(GHOLL_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("mirefen: could not load Gholl")
		return
	var gholl := packed.instantiate()
	gholl.position = POOL_CENTER + Vector3(2.0, 0.1, 0.0)
	gholl.set("roam_min", Vector2(POOL_CENTER.x - 12.0, -12.0))
	gholl.set("roam_max", Vector2(POOL_CENTER.x + 12.0, 12.0))
	add_child(gholl)
