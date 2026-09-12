class_name HitEffects
## Shared combat feedback: hit particle bursts and floating damage numbers.

## Spawn a hit particle burst at a position.
static func burst(parent: Node3D, pos: Vector3, color: Color = Color(1.0, 0.7, 0.2)) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.9
	# Particle material: small bright quads flying outward.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 45.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.15
	pm.color = color
	particles.process_material = pm
	# Draw as small billboard quads.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	particles.draw_pass_1 = quad
	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	# Clean up after the burst finishes.
	var timer := parent.get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)

## Spawn a floating damage number at a position.
## Text like "-43" (red) or "+30 XP" (gold).
static func damage_number(parent: Node3D, pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.5, 0)
	# Animate: float up and fade out over 0.9 seconds.
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
