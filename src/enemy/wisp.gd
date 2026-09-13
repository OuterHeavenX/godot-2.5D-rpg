class_name Wisp
extends Monster
## A mournful blue flame drifting over the black water's edge.
## Fast and fragile; its touch burns cold. A wisp does not fight at once:
## it drifts just out of reach, east toward the black water, drawing the
## curious after it, and only turns to strike once it has led them on.

var _core: MeshInstance3D
var _glow: OmniLight3D
var _base_y := 1.0
const LURE_TRIGGER := 5.5
const LURE_RELEASE := 9.5
var _lures_left := 3

func _init() -> void:
	max_hp = 18.0
	walk_speed = 2.8
	chase_speed = 4.5
	aggro_range = 14.0
	attack_range = 1.9
	attack_damage = 11.0
	attack_cooldown = 1.2
	windup_time = 0.55
	xp_reward = 32
	voice = "wisp"
	drops = [["potion", 0.25, 1, 1], ["wisp_essence", 0.6, 1, 1]]
	avoid_lake = false  # Wisps drift OVER the black water.
	hover = true # No gravity; they float.
	roam_min = Vector2(20.0, 38.0)
	roam_max = Vector2(50.0, 72.0)

func _build_body() -> void:
	super._build_body()
	# Floating flame core.
	_core = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	sphere.radial_segments = 12
	sphere.rings = 8
	_core.mesh = sphere
	_core.position = Vector3(0, _base_y, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.5
	_core.set_surface_override_material(0, mat)
	body.add_child(_core)
	# Cold light.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.35, 0.7, 1.0)
	_glow.light_energy = 0.8
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, _base_y, 0)
	body.add_child(_glow)
	# Collision follows the floating core.
	body_cs.shape.radius = 0.35
	body_cs.shape.height = 0.8
	body_cs.position = Vector3(0, _base_y, 0)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _state == "lure":
		# The lure runs its own movement, so it has to keep the shared
		# bookkeeping itself: without this a chilled or slowed wisp kept
		# the debuff for the whole lure and its glow stopped pulsing.
		_tick_timers(delta)
		var victim := _nearest_victim()
		if victim == null:
			_state = "wander"
		else:
			var away: Vector3 = global_position - victim.global_position
			away.y = 0.0
			var d := away.length()
			# Drift away from the victim, bending east toward the water.
			var dir := (away.normalized() + Vector3(0.8, 0, 0)).normalized()
			_move_toward(dir, chase_speed * 0.9, delta)
			if d > LURE_RELEASE or global_position.x > IslandLake.WATER_X0 + 6.0:
				_lures_left -= 1
				_state = "chase"
		_animate(delta)
		_update_flash()
		velocity.y = 0.0
		move_and_slide()
		# The same bounds every other state respects — a luring wisp used
		# to drift into the chapel island and the other safe ground.
		_settle_position()
		return
	super._physics_process(delta)
	if _state == "chase" and _lures_left > 0:
		var victim := _nearest_victim()
		if victim != null and global_position.distance_to(victim.global_position) < LURE_TRIGGER:
			_state = "lure"

func is_luring() -> bool:
	return _state == "lure"

func lures_left() -> int:
	return _lures_left

func _animate(delta: float) -> void:
	# Bob and drift.
	var bob := sin(_anim_time * 3.0) * 0.18
	_core.position.y = _base_y + bob
	_glow.position.y = _base_y + bob
	var pulse := 1.0 + sin(_anim_time * 5.0) * 0.12
	if _state == "windup":
		# Swell before striking.
		pulse = 1.0 + (1.0 - _windup_timer / windup_time) * 0.6
		_glow.light_energy = 0.8 + (1.0 - _windup_timer / windup_time) * 1.5
	elif _state == "attack":
		pulse = 1.5
		_glow.light_energy = 2.0
	else:
		_glow.light_energy = 0.8
	_core.scale = Vector3(pulse, 2.0 - pulse, pulse) * 0.5 + Vector3(0.5, 0.5, 0.5)
	# Face drift tilt.
	if _state == "chase":
		body.rotation.z = lerp(body.rotation.z, 0.15, 5.0 * delta)
	else:
		body.rotation.z = lerp(body.rotation.z, 0.0, 5.0 * delta)

func _on_attack_start() -> void:
	# Dart at the victim.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var dir: Vector3 = player.global_position - global_position
		dir.y = 0.0
		velocity = dir.normalized() * 8.0

func _on_hit() -> void:
	# Flicker.
	var tw := create_tween()
	tw.tween_property(_glow, "light_energy", 0.1, 0.08)
	tw.tween_property(_glow, "light_energy", 0.8, 0.2)
