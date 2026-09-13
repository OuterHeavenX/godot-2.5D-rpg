extends Node3D
## Iron portcullis gates in Emberfell's walls, one per spoke of the world,
## plus the old stone cap over the village well.
##
## A gate stays barred until the boss guarding the region behind it falls.
## Walk up to a barred gate and the hero reads the reason off it. When the
## guardian dies the portcullis grinds up and stays up for the rest of the
## run — every region opened so far remains open for training.

const BAR_COUNT := 5
const GAP_WIDTH := 4.0
const BAR_HEIGHT := 3.4
const RAISE_HEIGHT := 3.5
const RAISE_TIME := 2.0
## How close the hero gets before a barred gate speaks up. The well sits
## in the middle of the square, so it keeps its own shorter leash.
const HINT_RANGE := 7.0
const WELL_HINT_RANGE := 3.2
const HINT_COOLDOWN := 8.0
## Height of the slab over the well mouth. The KayKit well stands 4.1m
## tall with its roof; the lid sits on the rim, in plain sight from the
## square.
const WELL_CAP_Y := 1.8

# region -> {"root": Node3D, "shape": CollisionShape3D, "open": bool}
var _gates := {}
var _hint_cd := {}
var _poll := 0.0

func _ready() -> void:
	add_to_group("region_gates")
	# Deliberately not scenery: a sleeping node's bodies leave the physics
	# space, and a barred gate has to stay solid even when the hero is far
	# enough away for the town to have gone quiet.
	_build_gate(Regions.NORTH, Vector3(0, 0, -30), false)
	_build_gate(Regions.WEST, Vector3(-30, 0, 0), true)
	_build_gate(Regions.EAST, Vector3(30, 0, 0), true)
	_build_well_cap()
	QuestMan.quests_changed.connect(_sync)
	QuestMan.region_opened.connect(_on_region_opened)
	_sync()

## True when this region's gate stands open.
func is_open(region: String) -> bool:
	if not _gates.has(region):
		return true
	return bool(_gates[region]["open"])

func _iron() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.23, 0.26)
	m.metallic = 0.7
	m.roughness = 0.45
	return m

## A portcullis filling one wall gap. `along_z` gates sit in the east and
## west walls; the others sit in the north wall.
func _build_gate(region: String, pos: Vector3, along_z: bool) -> void:
	var root := Node3D.new()
	root.name = "Gate_%s" % region
	root.position = pos
	if along_z:
		root.rotation.y = PI * 0.5
	add_child(root)
	var iron := _iron()
	for i in BAR_COUNT:
		var t := float(i) / float(BAR_COUNT - 1) - 0.5
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.09
		cyl.height = BAR_HEIGHT
		cyl.radial_segments = 6
		bar.mesh = cyl
		bar.material_override = iron
		bar.position = Vector3(t * (GAP_WIDTH - 0.5), BAR_HEIGHT * 0.5, 0)
		root.add_child(bar)
	for rail_y in [0.9, 2.4, BAR_HEIGHT - 0.1]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(GAP_WIDTH, 0.16, 0.16)
		rail.mesh = bm
		rail.material_override = iron
		rail.position = Vector3(0, rail_y, 0)
		root.add_child(rail)
	# Spikes along the bottom edge.
	for i in BAR_COUNT:
		var t2 := float(i) / float(BAR_COUNT - 1) - 0.5
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.09
		sm.height = 0.3
		sm.radial_segments = 6
		spike.mesh = sm
		spike.material_override = iron
		spike.rotation.x = PI
		spike.position = Vector3(t2 * (GAP_WIDTH - 0.5), -0.15, 0)
		root.add_child(spike)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GAP_WIDTH + 0.4, 6.0, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 3.0, 0)
	body.add_child(shape)
	root.add_child(body)
	_gates[region] = {"root": root, "shape": shape, "open": false, "tween": null}

## The well in the square is capped with a slab of old stone until the
## Mirefen is cleared and the way down reveals itself.
func _build_well_cap() -> void:
	var root := Node3D.new()
	root.name = "WellCap"
	root.position = VillageLayout.WELL_POS + Vector3(0, WELL_CAP_Y, 0)
	add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.42, 0.45)
	stone.roughness = 0.95
	var slab := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.5
	cyl.height = 0.34
	cyl.radial_segments = 10
	slab.mesh = cyl
	slab.material_override = stone
	root.add_child(slab)
	# A worn sigil on the lid, so the eye is drawn to it.
	var sigil := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.75
	ring.rings = 10
	ring.ring_segments = 6
	sigil.mesh = ring
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.42, 0.38, 0.28)
	glow.roughness = 0.7
	glow.emission_enabled = true
	glow.emission = Color(0.45, 0.38, 0.20)
	glow.emission_energy_multiplier = 0.5
	sigil.material_override = glow
	sigil.position = Vector3(0, 0.19, 0)
	root.add_child(sigil)
	_gates[Regions.DEEP] = {"root": root, "shape": null, "open": false, "tween": null}

## Match every gate to the story so far. Cheap enough to call on any
## quest change, and it fixes the world up after loading a save.
func _sync() -> void:
	for key in _gates:
		var region := String(key)
		var want: bool = QuestMan.region_unlocked(region)
		if want != bool(_gates[region]["open"]):
			_set_open(region, want, false)

func _on_region_opened(region: String) -> void:
	if _gates.has(region):
		_set_open(region, true, true)

func _set_open(region: String, open: bool, animate: bool) -> void:
	var gate: Dictionary = _gates[region]
	# Kill a raise that is still in flight, or it would keep driving the
	# gate upward after the state has changed back.
	var running: Variant = gate.get("tween")
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	gate["tween"] = null
	gate["open"] = open
	var root := gate["root"] as Node3D
	var shape := gate["shape"] as CollisionShape3D
	var base := Vector3(0, RAISE_HEIGHT, 0) if open else Vector3.ZERO
	if region == Regions.DEEP:
		# The well lid slides aside rather than rising.
		base = Vector3(2.2, -0.2, 0) if open else Vector3.ZERO
	if shape != null:
		shape.set_deferred("disabled", open)
	if not animate:
		root.position = _gate_home(region) + base
		return
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(root, "position", _gate_home(region) + base, RAISE_TIME)
	gate["tween"] = tw
	AudioMan.play("levelup", 0.6, -6.0)

## A gate only explains itself once it is the next one in the story. The
## hero walking out of their first tavern does not need to hear about the
## thing under the well.
func _is_next(region: String) -> bool:
	var idx := Regions.ORDER.find(region)
	if idx <= 0:
		return true
	return QuestMan.region_unlocked(String(Regions.ORDER[idx - 1]))

func _gate_home(region: String) -> Vector3:
	if region == Regions.DEEP:
		return VillageLayout.WELL_POS + Vector3(0, WELL_CAP_Y, 0)
	var g: Vector3 = Regions.GATES[region]
	return g

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.3:
		return
	_poll = 0.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pp := player.global_position
	for key in _gates:
		var region := String(key)
		if bool(_gates[region]["open"]):
			continue
		if not _is_next(region):
			continue
		var home := _gate_home(region)
		var range_m := WELL_HINT_RANGE if region == Regions.DEEP else HINT_RANGE
		if Vector2(pp.x - home.x, pp.z - home.z).length() > range_m:
			continue
		var last := float(_hint_cd.get(region, -100.0))
		var now := float(Time.get_ticks_msec()) * 0.001
		if now - last < HINT_COOLDOWN:
			continue
		_hint_cd[region] = now
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("toast"):
			hud.toast(String(Regions.SEALED_LINES.get(region, "The way is barred.")))
