extends Node3D
## Potion pickup dropped by skeletons. Bobs and spins; walking close
## collects it into the player's inventory.

const PICKUP_RADIUS := 1.6
const HEAL_AMOUNT := 50.0

var _t := 0.0
var _collected := false
var _bottle: Node3D

func _ready() -> void:
	_bottle = _build_bottle()
	add_child(_bottle)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	cs.shape = sphere
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _build_bottle() -> Node3D:
	var root := Node3D.new()
	# Glass body: red liquid. Oversized so drops are easy to spot.
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.22
	body_mesh.bottom_radius = 0.28
	body_mesh.height = 0.58
	body.mesh = body_mesh
	body.position.y = 0.35
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.12, 0.18)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.2, 0.25)
	red.emission_energy_multiplier = 1.2
	body.set_surface_override_material(0, red)
	root.add_child(body)
	# Neck.
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.1
	neck_mesh.bottom_radius = 0.1
	neck_mesh.height = 0.24
	neck.mesh = neck_mesh
	neck.position.y = 0.75
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 0.95, 1.0, 0.7)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	neck.set_surface_override_material(0, glass)
	root.add_child(neck)
	# Cork.
	var cork := MeshInstance3D.new()
	var cork_mesh := CylinderMesh.new()
	cork_mesh.top_radius = 0.11
	cork_mesh.bottom_radius = 0.11
	cork_mesh.height = 0.14
	cork.mesh = cork_mesh
	cork.position.y = 0.92
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.55, 0.38, 0.22)
	cork.set_surface_override_material(0, brown)
	root.add_child(cork)
	# Glow light so drops are visible in grass.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.3)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 0.6
	root.add_child(light)
	return root

func _process(delta: float) -> void:
	_t += delta
	_bottle.position.y = 0.15 + sin(_t * 3.0) * 0.08
	_bottle.rotation.y = _t * 2.0

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("player") and body.has_method("add_potion"):
		_collected = true
		body.add_potion(1)
		AudioMan.play("potion", 1.0, 0.0)
		queue_free()
