extends Node3D
## Burly blacksmith NPC built from primitives in low-poly style.
## Stands behind the forge in the blacksmith interior.

func _ready() -> void:
	_build_blacksmith()

func _build_blacksmith() -> void:
	# Body (burly, dark tunic).
	var body := _part(Vector3(0.8, 0.9, 0.5), Color(0.30, 0.25, 0.22))
	body.position = Vector3(0, 1.0, 0)
	add_child(body)
	# Head (skin).
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28
	head_mesh.height = 0.56
	head.mesh = head_mesh
	head.position = Vector3(0, 1.70, 0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.90, 0.72, 0.55)
	head.set_surface_override_material(0, skin)
	add_child(head)
	# Beard (dark brown box).
	var beard := _part(Vector3(0.4, 0.25, 0.15), Color(0.25, 0.18, 0.12))
	beard.position = Vector3(0, 1.50, 0.20)
	add_child(beard)
	# Arms (bare, muscular).
	for side in [-1.0, 1.0]:
		var arm := _part(Vector3(0.22, 0.65, 0.22), Color(0.90, 0.72, 0.55))
		arm.position = Vector3(side * 0.52, 1.0, 0)
		add_child(arm)
	# Leather apron (front).
	var apron := _part(Vector3(0.6, 0.75, 0.06), Color(0.35, 0.25, 0.18))
	apron.position = Vector3(0, 0.85, 0.27)
	add_child(apron)
	# Hammer (leaning on shoulder).
	var handle := _part(Vector3(0.08, 0.7, 0.08), Color(0.45, 0.32, 0.20))
	handle.position = Vector3(0.55, 1.45, 0.1)
	handle.rotation.z = -0.3
	add_child(handle)
	var hammer_head := _part(Vector3(0.3, 0.18, 0.18), Color(0.50, 0.50, 0.55))
	hammer_head.position = Vector3(0.65, 1.75, 0.1)
	add_child(hammer_head)
	# Interaction area.
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	col.position = Vector3(0, 1.0, 0)
	area.add_child(col)
	area.body_entered.connect(_on_body_enter)
	area.body_exited.connect(_on_body_exit)
	add_child(area)

func _part(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.set_surface_override_material(0, mat)
	return mi

func _on_body_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		var shop := get_tree().get_first_node_in_group("shop_ui")
		if shop != null and shop.has_method("set_shop"):
			# Blacksmith inventory (weapons). Dynamic upgrades added by shop UI.
			shop.set_shop(shop.BLACKSMITH_TITLE, [],
				"Blacksmith: \"Need something sharper?\"")
		if shop != null and shop.has_method("show_talk_prompt"):
			shop.show_talk_prompt()

func _on_body_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		var shop := get_tree().get_first_node_in_group("shop_ui")
		if shop != null and shop.has_method("hide_talk_prompt"):
			shop.hide_talk_prompt()
