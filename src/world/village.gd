extends Node3D
## A small medieval village built from authentic KayKit building models.
## All models are board-game scale, so they're scaled 5x to fit the rogue.
## Each building gets a collision box so the player can't walk through it.
## Layout data lives in VillageLayout (shared with paths and grass).

func _ready() -> void:
	var collision_body := StaticBody3D.new()
	collision_body.name = "VillageCollision"
	add_child(collision_body)
	for spec in VillageLayout.BUILDINGS:
		var path: String = str(spec[0])
		var pos: Vector3 = spec[1]
		var footprint: Vector2 = spec[2]
		var scale_f := VillageLayout.BUILDING_SCALE
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("village: failed to load " + path)
			continue
		var inst := packed.instantiate() as Node3D
		inst.position = pos
		inst.rotation.y = 0.0  # all face south (+Z), toward the camera
		inst.scale = Vector3.ONE * scale_f
		add_child(inst)
		# Collision box, slightly inset from the visual footprint.
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(
			footprint.x * scale_f * 0.92, 4.0,
			footprint.y * scale_f * 0.92)
		cs.shape = box
		cs.position = pos + Vector3(0, 2.0, 0)
		collision_body.add_child(cs)
