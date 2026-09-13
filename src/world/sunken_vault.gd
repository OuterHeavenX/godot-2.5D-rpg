class_name SunkenVault
extends Node3D
## The Sunken Vault: what the village well was dug into, and what has been
## sitting under Emberfell the whole time. It opens when Gholl dies.
##
## The vault is built well off the map so it needs no sky, no weather and
## no view of the world above. The hero reaches it by climbing down the
## well and leaves the same way.
##
##   z=182..200   entry hall, with the stair back up
##   z=200..340   the long gallery, four burial chambers off it
##   z=340..376   the throne of the Hollow Crown

const HALL_Z0 := 182.0
const HALL_Z1 := 202.0
const GALLERY_Z0 := 202.0
const GALLERY_Z1 := 340.0
const GALLERY_HALF := 8.0
const THRONE_Z0 := 340.0
const THRONE_Z1 := 376.0
const THRONE_HALF := 22.0
const HALL_HALF := 12.0
const CEILING_Y := 7.0
const ENTRY := Vector3(0, 0.1, 187)
const THRONE_CENTER := Vector3(0, 0, 358)

## Burial chambers off the gallery: [z centre, side (-1 west, +1 east)].
const CHAMBERS := [
	[224.0, -1.0],
	[254.0, 1.0],
	[284.0, -1.0],
	[314.0, 1.0],
]
const CHAMBER_HALF := 11.0

const CROWN_SCENE_PATH := "res://src/enemy/hollow_crown.tscn"

var _rng := RandomNumberGenerator.new()

var _stone_mat: StandardMaterial3D
var _dark_stone_mat: StandardMaterial3D
var _bone_mat: StandardMaterial3D
var _gold_mat: StandardMaterial3D
var _fire_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D

## True anywhere inside the vault's rooms.
static func is_inside(x: float, z: float) -> bool:
	if z < HALL_Z0 or z > THRONE_Z1:
		return false
	if z <= HALL_Z1:
		return absf(x) <= HALL_HALF
	if z >= THRONE_Z0:
		return absf(x) <= THRONE_HALF
	if absf(x) <= GALLERY_HALF:
		return true
	for c: Array in CHAMBERS:
		if absf(z - float(c[0])) <= CHAMBER_HALF and absf(x) <= GALLERY_HALF + CHAMBER_HALF * 2.0:
			return true
	return false

## Centre of one of the four burial chambers.
static func chamber_center(i: int) -> Vector3:
	var c: Array = CHAMBERS[i % CHAMBERS.size()]
	return Vector3(float(c[1]) * (GALLERY_HALF + CHAMBER_HALF), 0.0, float(c[0]))

func _ready() -> void:
	# Scenery sleeps while the hero is in another region.
	add_to_group("scenery")
	set_meta("region", Regions.DEEP)
	_rng.seed = 303030
	_make_materials()
	_build_rooms()
	var batch := PropBatch.new()
	_build_stair(batch)
	_dress_gallery(batch)
	_dress_chambers(batch)
	_build_throne(batch)
	batch.build(self)
	_spawn_crown()

func _mat(color: Color, rough := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _make_materials() -> void:
	_stone_mat = _mat(Color(0.38, 0.37, 0.36))
	_dark_stone_mat = _mat(Color(0.26, 0.25, 0.27))
	_floor_mat = _mat(Color(0.32, 0.31, 0.31))
	_bone_mat = _mat(Color(0.78, 0.75, 0.66))
	_gold_mat = _mat(Color(0.72, 0.58, 0.24), 0.35)
	_gold_mat.metallic = 0.7
	_fire_mat = StandardMaterial3D.new()
	_fire_mat.albedo_color = Color(0.55, 0.95, 0.70)
	_fire_mat.emission_enabled = true
	_fire_mat.emission = Color(0.35, 1.0, 0.65)
	_fire_mat.emission_energy_multiplier = 2.6
	_fire_mat.roughness = 0.5

## One rectangular room: floor, ceiling and four walls with the openings
## the layout needs cut out by simply not building those pieces.
func _room(body: StaticBody3D, x0: float, z0: float, x1: float, z1: float) -> void:
	var w := x1 - x0
	var d := z1 - z0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(w, 0.5, d)
	floor_mi.mesh = fm
	floor_mi.material_override = _floor_mat
	floor_mi.position = Vector3(cx, -0.25, cz)
	add_child(floor_mi)
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(w, 0.5, d)
	fcs.shape = fbox
	fcs.position = Vector3(cx, -0.25, cz)
	body.add_child(fcs)
	var ceil_mi := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(w, 0.6, d)
	ceil_mi.mesh = cm
	ceil_mi.material_override = _dark_stone_mat
	ceil_mi.position = Vector3(cx, CEILING_Y, cz)
	add_child(ceil_mi)

## A wall slab with collision.
func _wall(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _stone_mat
	mi.position = center
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, maxf(size.y, CEILING_Y), size.z)
	cs.shape = box
	cs.position = Vector3(center.x, maxf(size.y, CEILING_Y) * 0.5, center.z)
	body.add_child(cs)

func _build_rooms() -> void:
	var body := StaticBody3D.new()
	body.name = "VaultShell"
	add_child(body)
	# Entry hall.
	_room(body, -HALL_HALF, HALL_Z0, HALL_HALF, HALL_Z1)
	_wall(body, Vector3(0, 3, HALL_Z0 - 0.75), Vector3(HALL_HALF * 2 + 3, 6, 1.5))
	_wall(body, Vector3(-HALL_HALF - 0.75, 3, (HALL_Z0 + HALL_Z1) * 0.5),
		Vector3(1.5, 6, HALL_Z1 - HALL_Z0))
	_wall(body, Vector3(HALL_HALF + 0.75, 3, (HALL_Z0 + HALL_Z1) * 0.5),
		Vector3(1.5, 6, HALL_Z1 - HALL_Z0))
	# The hall's north wall, with the gallery mouth left open.
	for side: float in [1.0, -1.0]:
		var span := HALL_HALF - GALLERY_HALF
		_wall(body, Vector3(side * (GALLERY_HALF + span * 0.5), 3, HALL_Z1),
			Vector3(span, 6, 1.5))
	# The gallery.
	_room(body, -GALLERY_HALF, GALLERY_Z0, GALLERY_HALF, GALLERY_Z1)
	# Gallery side walls, broken by each chamber's doorway.
	for side2: float in [1.0, -1.0]:
		var cuts: Array = []
		for c: Array in CHAMBERS:
			if float(c[1]) == side2:
				cuts.append(float(c[0]))
		cuts.sort()
		var z := GALLERY_Z0
		for cut: float in cuts:
			var door_half := 3.0
			if cut - door_half > z:
				_wall(body, Vector3(side2 * (GALLERY_HALF + 0.75), 3,
					(z + cut - door_half) * 0.5),
					Vector3(1.5, 6, cut - door_half - z))
			z = cut + door_half
		if z < GALLERY_Z1:
			_wall(body, Vector3(side2 * (GALLERY_HALF + 0.75), 3, (z + GALLERY_Z1) * 0.5),
				Vector3(1.5, 6, GALLERY_Z1 - z))
	# Burial chambers.
	for i in CHAMBERS.size():
		var c := chamber_center(i)
		_room(body, c.x - CHAMBER_HALF, c.z - CHAMBER_HALF,
			c.x + CHAMBER_HALF, c.z + CHAMBER_HALF)
		var outer := signf(c.x)
		_wall(body, Vector3(c.x + outer * (CHAMBER_HALF + 0.75), 3, c.z),
			Vector3(1.5, 6, CHAMBER_HALF * 2 + 3))
		for zside: float in [1.0, -1.0]:
			_wall(body, Vector3(c.x, 3, c.z + zside * (CHAMBER_HALF + 0.75)),
				Vector3(CHAMBER_HALF * 2 + 3, 6, 1.5))
	# The throne chamber.
	_room(body, -THRONE_HALF, THRONE_Z0, THRONE_HALF, THRONE_Z1)
	_wall(body, Vector3(-THRONE_HALF - 0.75, 3, (THRONE_Z0 + THRONE_Z1) * 0.5),
		Vector3(1.5, 6, THRONE_Z1 - THRONE_Z0))
	_wall(body, Vector3(THRONE_HALF + 0.75, 3, (THRONE_Z0 + THRONE_Z1) * 0.5),
		Vector3(1.5, 6, THRONE_Z1 - THRONE_Z0))
	_wall(body, Vector3(0, 3, THRONE_Z1 + 0.75), Vector3(THRONE_HALF * 2 + 3, 6, 1.5))
	# Its south wall, with the gallery mouth left open.
	for side3: float in [1.0, -1.0]:
		var span3 := THRONE_HALF - GALLERY_HALF
		_wall(body, Vector3(side3 * (GALLERY_HALF + span3 * 0.5), 3, THRONE_Z0),
			Vector3(span3, 6, 1.5))

## The stair the hero climbs down from the well, and the shaft of pale
## light that falls down it.
func _build_stair(batch: PropBatch) -> void:
	var step := BoxMesh.new()
	step.size = Vector3(4.0, 0.4, 1.0)
	step.material = _stone_mat
	for i in 7:
		batch.add("step", step, Transform3D(Basis(),
			ENTRY + Vector3(0, 2.6 - i * 0.4, -3.4 + i * 1.0)))
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 1.4
	sm.bottom_radius = 1.9
	sm.height = CEILING_Y
	sm.radial_segments = 12
	shaft.mesh = sm
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.65, 0.72, 0.75, 0.16)
	pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft.material_override = pale
	shaft.position = ENTRY + Vector3(0, CEILING_Y * 0.5, -4.0)
	add_child(shaft)
	var light := OmniLight3D.new()
	light.light_color = Color(0.72, 0.8, 0.9)
	light.light_energy = 3.0
	light.omni_range = 16.0
	light.shadow_enabled = false
	light.position = ENTRY + Vector3(0, 4.0, -4.0)
	add_child(light)

## A brazier of the vault's green fire: the only thing still burning here.
func _brazier(at: Vector3) -> void:
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.55
	bm.bottom_radius = 0.25
	bm.height = 0.5
	bm.radial_segments = 8
	bowl.mesh = bm
	bowl.material_override = _dark_stone_mat
	bowl.position = at + Vector3(0, 1.1, 0)
	add_child(bowl)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.14
	sm.bottom_radius = 0.28
	sm.height = 1.1
	sm.radial_segments = 6
	stem.mesh = sm
	stem.material_override = _dark_stone_mat
	stem.position = at + Vector3(0, 0.55, 0)
	add_child(stem)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.34
	fm.height = 0.7
	fm.radial_segments = 7
	fm.rings = 5
	flame.mesh = fm
	flame.material_override = _fire_mat
	flame.position = at + Vector3(0, 1.6, 0)
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(0.42, 1.0, 0.62)
	light.light_energy = 3.4
	light.omni_range = 13.0
	light.shadow_enabled = false
	light.position = at + Vector3(0, 1.8, 0)
	add_child(light)

func _dress_gallery(batch: PropBatch) -> void:
	var body := StaticBody3D.new()
	body.name = "GalleryProps"
	add_child(body)
	# Pillars down both sides of the gallery.
	var pillar := BoxMesh.new()
	pillar.size = Vector3(1.1, CEILING_Y, 1.1)
	pillar.material = _dark_stone_mat
	var z := GALLERY_Z0 + 6.0
	while z < GALLERY_Z1 - 4.0:
		for side: float in [1.0, -1.0]:
			var p := Vector3(side * (GALLERY_HALF - 1.2), CEILING_Y * 0.5, z)
			batch.add("pillar", pillar, Transform3D(Basis(), p))
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.1, CEILING_Y, 1.1)
			cs.shape = box
			cs.position = p
			body.add_child(cs)
		z += 12.0
	# Braziers, spaced so the gallery is a chain of lit pools.
	var bz := GALLERY_Z0 + 12.0
	while bz < GALLERY_Z1:
		_brazier(Vector3(-GALLERY_HALF + 2.2, 0, bz))
		bz += 34.0
	# Bones, swept to the edges over the centuries.
	var bone := BoxMesh.new()
	bone.size = Vector3(0.5, 0.12, 0.12)
	bone.material = _bone_mat
	for i in 260:
		var p2 := Vector3(
			_rng.randf_range(-GALLERY_HALF + 0.8, GALLERY_HALF - 0.8), 0.06,
			_rng.randf_range(GALLERY_Z0 + 1.0, GALLERY_Z1 - 1.0))
		var b := Basis(Vector3.UP, _rng.randf() * TAU) \
			* Basis.from_scale(Vector3(_rng.randf_range(0.7, 1.5), 1.0, 1.0))
		batch.add("bone", bone, Transform3D(b, p2))

func _dress_chambers(batch: PropBatch) -> void:
	var body := StaticBody3D.new()
	body.name = "ChamberProps"
	add_child(body)
	var lid := BoxMesh.new()
	lid.size = Vector3(1.6, 0.9, 3.4)
	lid.material = _stone_mat
	var skull := SphereMesh.new()
	skull.radius = 0.22
	skull.height = 0.44
	skull.radial_segments = 6
	skull.rings = 4
	skull.material = _bone_mat
	for i in CHAMBERS.size():
		var c := chamber_center(i)
		_brazier(c + Vector3(0, 0, -CHAMBER_HALF + 2.0))
		# Sarcophagi in rows, lids off.
		for row in 3:
			for col in 3:
				var p := c + Vector3(-6.0 + col * 6.0, 0.45, -6.0 + row * 6.0)
				var b := Basis(Vector3.UP, _rng.randf_range(-0.12, 0.12))
				batch.add("sarcophagus", lid, Transform3D(b, p))
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(1.8, 1.0, 3.6)
				cs.shape = box
				cs.position = p
				body.add_child(cs)
		# Skulls stacked against the walls.
		for s in 40:
			var sp := c + Vector3(
				_rng.randf_range(-CHAMBER_HALF + 1.0, CHAMBER_HALF - 1.0), 0.2,
				_rng.randf_range(-CHAMBER_HALF + 1.0, CHAMBER_HALF - 1.0))
			batch.add("skull", skull, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), sp))

## The throne: a chair of gold and bone at the end of everything, and the
## crowns of every king the vault has already taken.
func _build_throne(batch: PropBatch) -> void:
	var c := THRONE_CENTER
	var seat := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(4.0, 1.0, 3.0)
	seat.mesh = sm
	seat.material_override = _gold_mat
	seat.position = c + Vector3(0, 1.4, 8.0)
	add_child(seat)
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 5.0, 0.8)
	back.mesh = bm
	back.material_override = _gold_mat
	back.position = c + Vector3(0, 3.4, 9.4)
	add_child(back)
	var dais := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 7.0
	dm.bottom_radius = 8.0
	dm.height = 0.9
	dm.radial_segments = 18
	dais.mesh = dm
	dais.material_override = _dark_stone_mat
	dais.position = c + Vector3(0, 0.45, 8.0)
	add_child(dais)
	var body := StaticBody3D.new()
	body.name = "ThroneCollision"
	add_child(body)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 7.5
	cyl.height = 0.9
	cs.shape = cyl
	cs.position = c + Vector3(0, 0.45, 8.0)
	body.add_child(cs)
	# Braziers flanking the dais.
	_brazier(c + Vector3(-9.0, 0, 6.0))
	_brazier(c + Vector3(9.0, 0, 6.0))
	# Crowns, laid out in a ring. Every one of them was somebody.
	var crown := TorusMesh.new()
	crown.inner_radius = 0.22
	crown.outer_radius = 0.34
	crown.rings = 8
	crown.ring_segments = 5
	crown.material = _gold_mat
	for i in 22:
		var ang := TAU * float(i) / 22.0
		var rad := _rng.randf_range(10.0, 17.0)
		batch.add("crown", crown, Transform3D(
			Basis(Vector3.FORWARD, _rng.randf_range(-0.3, 0.3)),
			c + Vector3(cos(ang) * rad, 0.12, sin(ang) * rad - 2.0)))

func _spawn_crown() -> void:
	var packed := load(CROWN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("sunken_vault: could not load the Hollow Crown")
		return
	var boss := packed.instantiate()
	boss.position = THRONE_CENTER + Vector3(0, 0.1, 4.0)
	boss.set("roam_min", Vector2(-THRONE_HALF + 3.0, THRONE_Z0 + 3.0))
	boss.set("roam_max", Vector2(THRONE_HALF - 3.0, THRONE_Z1 - 3.0))
	add_child(boss)
