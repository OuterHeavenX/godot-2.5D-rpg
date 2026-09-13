extends Node3D
## A dropped crafting material or consumable: a spinning gem tinted by the
## item, with a nameplate. Walking close collects it into the inventory.

const PICKUP_RADIUS := 1.6

var item_id := "bone_shard"
var count := 1
var _t := 0.0
var _gem: Node3D
var _collected := false

func _ready() -> void:
	var info := ItemDB.get_item(item_id)
	var color: Color = info.get("color", Color(1, 1, 1))
	_gem = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	if ItemDB.is_kind(item_id, ItemDB.KIND_MATERIAL):
		var prism := PrismMesh.new()
		prism.size = Vector3(0.4, 0.5, 0.4)
		mesh = prism
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 0.35, 0.35)
		mesh = box
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mi.set_surface_override_material(0, mat)
	mi.position.y = 0.35
	_gem.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.shadow_enabled = false
	light.position.y = 0.5
	_gem.add_child(light)
	add_child(_gem)
	var label := Label3D.new()
	label.text = ItemDB.item_name(item_id) if count == 1 else "%s x%d" % [ItemDB.item_name(item_id), count]
	label.font_size = 40
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.4)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.position = Vector3(0, 1.0, 0)
	add_child(label)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	cs.shape = sphere
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _process(delta: float) -> void:
	_t += delta
	_gem.position.y = 0.1 + sin(_t * 3.0) * 0.08
	_gem.rotation.y = _t * 1.8

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("player") and body.has_method("add_item"):
		_collected = true
		body.add_item(item_id, count)
		AudioMan.play("potion", 1.3, -2.0)
		queue_free()
