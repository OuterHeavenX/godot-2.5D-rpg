class_name IceShard
extends Node3D
## Hostile ice projectile (Morvain's shard volley). Flies at the player,
## dealing damage and chilling them on hit.

var velocity := Vector3.ZERO
var damage := 18.0
var chill_duration := 3.0
var max_distance := 24.0
var _traveled := 0.0
var _dead := false

static func create(from_pos: Vector3, direction: Vector3, damage: float, chill: float) -> IceShard:
	var p := IceShard.new()
	p.damage = damage
	p.chill_duration = chill
	p.velocity = direction.normalized() * 11.0
	p.position = from_pos + Vector3(0, 1.6, 0) + direction.normalized() * 1.0
	# Visual: jagged ice shard + cold light.
	var color := Color(0.55, 0.85, 1.0)
	var mesh_inst := MeshInstance3D.new()
	var shard := CylinderMesh.new()
	shard.top_radius = 0.0
	shard.bottom_radius = 0.22
	shard.height = 0.9
	shard.radial_segments = 6
	mesh_inst.mesh = shard
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh_inst.set_surface_override_material(0, mat)
	# Orient along flight direction.
	mesh_inst.rotation.x = PI * 0.5
	p.add_child(mesh_inst)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.shadow_enabled = false
	p.add_child(light)
	return p

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step: Vector3 = velocity * delta
	position += step
	_traveled += step.length()
	# Spin for a vicious look.
	rotate_y(delta * 9.0)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and not bool(player.get("dead")):
		var to: Vector3 = player.global_position + Vector3(0, 1.0, 0) - global_position
		if to.length() < 1.1 and player.has_method("take_damage"):
			_impact(player)
			return
	if _traveled >= max_distance or position.y < -1.0:
		_fizzle()

func _impact(player: Node) -> void:
	if _dead:
		return
	_dead = true
	player.take_damage(damage, global_position)
	if player.has_method("apply_chill"):
		player.apply_chill(chill_duration)
	var HitFx := preload("res://src/fx/hit_effects.gd")
	HitFx.burst(get_parent(), global_position, Color(0.55, 0.85, 1.0))
	AudioMan.play("hit", 0.9, 2.0)
	queue_free()

func _fizzle() -> void:
	if _dead:
		return
	_dead = true
	var HitFx := preload("res://src/fx/hit_effects.gd")
	HitFx.burst(get_parent(), global_position, Color(0.55, 0.85, 1.0))
	queue_free()
