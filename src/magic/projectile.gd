class_name MagicProjectile
extends Node3D
## A spell projectile (Fireball / Frost Bolt). Flies straight, explodes on
## contact with a skeleton or after max range. Uses HitEffects for impact.

signal hit_target

var velocity := Vector3.ZERO
var damage := 10.0
var max_distance := 18.0
var spell_id := ""
var slow_duration := 0.0
var _traveled := 0.0
var _dead := false

static func create(spell_id: String, from_pos: Vector3, direction: Vector3, damage: float) -> MagicProjectile:
	var p := MagicProjectile.new()
	p.spell_id = spell_id
	p.damage = damage
	var info := Spells.get_info(spell_id)
	p.velocity = direction.normalized() * 14.0
	p.slow_duration = float(info.get("slow_duration", 0.0))
	p.position = from_pos + Vector3(0, 1.2, 0) + direction.normalized() * 0.8
	# Visual: glowing sphere + point light.
	var color: Color = info["color"]
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 10
	sphere.rings = 8
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mesh_inst.set_surface_override_material(0, mat)
	p.add_child(mesh_inst)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	p.add_child(light)
	# Trail particles.
	var trail := GPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.5
	trail.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.08
	pm.scale_max = 0.18
	pm.color = color
	trail.process_material = pm
	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.12
	draw_mesh.height = 0.24
	trail.draw_pass_1 = draw_mesh
	p.add_child(trail)
	return p

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step: Vector3 = velocity * delta
	position += step
	_traveled += step.length()
	# Check enemy hits: any living node in "skeletons" with take_damage.
	# (Duck-typed — Skeleton subclasses AND procedural Monsters.)
	for node in get_tree().get_nodes_in_group("skeletons"):
		if node == null or bool(node.get("dead")):
			continue
		if not node.has_method("take_damage"):
			continue
		var target_pos: Vector3 = node.global_position + Vector3(0, 1.0, 0)
		var to: Vector3 = target_pos - global_position
		if to.length() < 1.0:
			_impact(node)
			return
	if _traveled >= max_distance:
		_fizzle()

func _impact(target: Node) -> void:
	if _dead:
		return
	_dead = true
	target.take_damage(damage, global_position)
	if slow_duration > 0.0 and target.has_method("apply_slow"):
		target.apply_slow(slow_duration)
	var info := Spells.get_info(spell_id)
	HitEffects.burst(get_parent(), global_position, info["color"])
	AudioMan.play("hit")
	hit_target.emit()
	queue_free()

func _fizzle() -> void:
	if _dead:
		return
	_dead = true
	var info := Spells.get_info(spell_id)
	HitEffects.burst(get_parent(), global_position, info["color"])
	queue_free()
