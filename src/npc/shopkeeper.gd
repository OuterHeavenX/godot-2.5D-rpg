extends Node3D
## Simple merchant NPC built from primitives in low-poly style.
## Stands behind the counter in the market interior.

func _ready() -> void:
	_build_merchant()

func _build_merchant() -> void:
	# Body (tunic): green.
	var body := _part(Vector3(0.6, 0.8, 0.4), Color(0.25, 0.45, 0.25))
	body.position = Vector3(0, 1.0, 0)
	add_child(body)
	# Head (skin).
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28
	head_mesh.height = 0.56
	head.mesh = head_mesh
	head.position = Vector3(0, 1.65, 0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.95, 0.78, 0.62)
	head.set_surface_override_material(0, skin)
	add_child(head)
	# Hat (wide-brimmed merchant hat): brown.
	var hat_top := _part(Vector3(0.35, 0.25, 0.35), Color(0.45, 0.32, 0.20))
	hat_top.position = Vector3(0, 1.95, 0)
	add_child(hat_top)
	var hat_brim := _part(Vector3(0.7, 0.08, 0.7), Color(0.40, 0.28, 0.18))
	hat_brim.position = Vector3(0, 1.85, 0)
	add_child(hat_brim)
	# Arms.
	for side in [-1.0, 1.0]:
		var arm := _part(Vector3(0.18, 0.6, 0.18), Color(0.25, 0.45, 0.25))
		arm.position = Vector3(side * 0.4, 1.0, 0)
		add_child(arm)
	# Apron (front).
	var apron := _part(Vector3(0.45, 0.6, 0.05), Color(0.75, 0.68, 0.55))
	apron.position = Vector3(0, 0.9, 0.22)
	add_child(apron)
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
		# Notify the shop UI to show the TALK prompt.
		var shop := get_tree().get_first_node_in_group("shop_ui")
		if shop != null and shop.has_method("set_shop"):
			# Reset to merchant inventory (in case innkeeper changed it).
			shop.set_shop("MERCHANT'S WARES", [
				{"name": "Potion", "price": 50, "desc": "Restores 50 HP"},
				{"name": "Hi-Potion", "price": 150, "desc": "Restores 150 HP"},
			])
		if shop != null and shop.has_method("show_talk_prompt"):
			shop.show_talk_prompt()

func _on_body_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		var shop := get_tree().get_first_node_in_group("shop_ui")
		if shop != null and shop.has_method("hide_talk_prompt"):
			shop.hide_talk_prompt()
