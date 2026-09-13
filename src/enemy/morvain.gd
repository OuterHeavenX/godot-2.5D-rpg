class_name Morvain
extends Monster
## Morvain, the Frozen Heart — ice golem boss of the frozen arena.
## Shard volley at range, crushing slam up close, and a faster,
## angrier second phase below half health. Never respawns.

const BOSS_NAME := "MORVAIN, THE FROZEN HEART"
const GOLD_REWARD := 500

var boss_id := "morvain"
var boss_name := BOSS_NAME

var _phase_two := false
var _volley_timer := 4.0
var _volley_cooldown := 7.0
var _slam_radius := 4.2

var _core_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D

func _ready() -> void:
	max_hp = 600.0
	attack_damage = 30.0
	chase_speed = 3.4
	walk_speed = 1.2
	aggro_range = 18.0
	attack_range = 3.4
	attack_cooldown = 2.4
	windup_time = 1.0
	xp_reward = 800
	voice = "growl"
	voice_pitch = 0.5
	avoid_lake = false
	# Never leaves the arena. The arena itself sets the real circle when it
	# places him; these are a sane fallback around the same spot.
	roam_min = Vector2(-13.0, -301.0)
	roam_max = Vector2(13.0, -275.0)
	super._ready()
	add_to_group("boss")
	scale = Vector3(1.5, 1.5, 1.5)
	_build_nameplate()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)

func _build_nameplate() -> void:
	var plate := Label3D.new()
	plate.text = BOSS_NAME
	plate.font_size = 48
	plate.pixel_size = 0.002
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color(0.5, 0.85, 1.0)
	plate.outline_size = 10
	plate.outline_modulate = Color(0, 0, 0, 0.9)
	plate.position = Vector3(0, 4.6, 0)
	# Only near the fight, and never through a wall: the HUD carries the
	# name for anyone further out.
	plate.visibility_range_end = 30.0
	plate.visibility_range_end_margin = 4.0
	add_child(plate)

func _build_body() -> void:
	super._build_body()
	# Bigger collision for a golem.
	body_cs.shape = null
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 2.6
	body_cs.shape = cap
	body_cs.position = Vector3(0, 1.3, 0)

	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.6, 0.78, 0.92)
	ice.roughness = 0.3
	ice.metallic = 0.15
	var dark_ice := StandardMaterial3D.new()
	dark_ice.albedo_color = Color(0.3, 0.48, 0.68)
	dark_ice.roughness = 0.45
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.5, 0.9, 1.0)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.35, 0.75, 1.0)
	_core_mat.emission_energy_multiplier = 2.0
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.6, 0.95, 1.0)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.5, 0.85, 1.0)
	_eye_mat.emission_energy_multiplier = 3.0

	# Legs: two thick pillars.
	for sx in [-1.0, 1.0]:
		var leg := _box_mesh(Vector3(0.55, 1.3, 0.55), dark_ice)
		leg.position = Vector3(sx * 0.45, 0.65, 0)
		body.add_child(leg)
	# Torso: big jagged block.
	_torso = _box_mesh(Vector3(1.7, 1.5, 1.1), ice)
	_torso.position = Vector3(0, 2.0, 0)
	body.add_child(_torso)
	# Frozen heart: glowing core in the chest.
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.32
	core_mesh.height = 0.64
	core.mesh = core_mesh
	core.set_surface_override_material(0, _core_mat)
	core.position = Vector3(0, 2.1, 0.58)
	body.add_child(core)
	var core_light := OmniLight3D.new()
	core_light.light_color = Color(0.4, 0.75, 1.0)
	core_light.light_energy = 1.1
	core_light.omni_range = 8.0
	core_light.shadow_enabled = false
	core_light.position = Vector3(0, 2.1, 0.8)
	body.add_child(core_light)
	# Shoulder shards.
	for sx in [-1.0, 1.0]:
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.28
		sm.height = 1.1
		sm.radial_segments = 6
		spike.mesh = sm
		spike.set_surface_override_material(0, ice)
		spike.position = Vector3(sx * 1.05, 2.9, 0)
		spike.rotation.z = sx * -0.35
		body.add_child(spike)
	# Arms: heavy clubs ending in shard fists.
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 1.05, 2.5, 0)
		body.add_child(arm)
		var upper := _box_mesh(Vector3(0.5, 1.1, 0.5), dark_ice)
		upper.position = Vector3(0, -0.55, 0)
		arm.add_child(upper)
		var fist := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.42
		fm.bottom_radius = 0.12
		fm.height = 0.9
		fm.radial_segments = 6
		fist.mesh = fm
		fist.set_surface_override_material(0, ice)
		fist.position = Vector3(0, -1.45, 0)
		arm.add_child(fist)
		if sx < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	# Head: angular block with glowing eyes.
	_head = _box_mesh(Vector3(0.8, 0.6, 0.7), dark_ice)
	_head.position = Vector3(0, 3.05, 0)
	body.add_child(_head)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09
		em.height = 0.18
		eye.mesh = em
		eye.set_surface_override_material(0, _eye_mat)
		eye.position = Vector3(sx * 0.2, 3.1, 0.36)
		body.add_child(eye)
	# Crown of ice shards.
	for i in 5:
		var ang := TAU * float(i) / 5.0
		var shard := MeshInstance3D.new()
		var shm := CylinderMesh.new()
		shm.top_radius = 0.0
		shm.bottom_radius = 0.1
		shm.height = 0.7
		shm.radial_segments = 5
		shard.mesh = shm
		shard.set_surface_override_material(0, ice)
		shard.position = Vector3(0.35 * cos(ang), 3.55, 0.35 * sin(ang))
		body.add_child(shard)

func _box_mesh(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	return mi

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	_check_phase()
	_volley_timer -= delta
	if _volley_timer > 0.0:
		return
	# Shard volley: only while chasing at mid range.
	if _state != "chase":
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var d := Vector2(
		player.global_position.x - global_position.x,
		player.global_position.z - global_position.z).length()
	if d > 5.0 and d < 24.0:
		_fire_volley(player)
		_volley_timer = _volley_cooldown

func _check_phase() -> void:
	if _phase_two or hp > max_hp * 0.5:
		return
	_phase_two = true
	chase_speed = 4.3
	attack_cooldown = 1.7
	_volley_cooldown = 4.5
	_volley_timer = 1.0
	# The heart burns brighter; the eyes flare.
	_core_mat.emission_energy_multiplier = 4.0
	_eye_mat.emission = Color(1.0, 0.45, 0.2)
	_eye_mat.emission_energy_multiplier = 4.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("MORVAIN ENRAGED")
	AudioMan.play("bone_die", 1.0, -4.0)

func _fire_volley(player: Node3D) -> void:
	var count := 8 if _phase_two else 5
	var base_dir: Vector3 = player.global_position - global_position
	base_dir.y = 0.0
	base_dir = base_dir.normalized()
	# Telegraph: arms sweep up.
	AudioMan.play("cast", 0.8, -2.0)
	for i in count:
		var spread := deg_to_rad(-18.0 + 36.0 * float(i) / float(maxi(1, count - 1)))
		var dir := base_dir.rotated(Vector3.UP, spread)
		var shard := IceShard.create(
			global_position, dir, 16.0 if not _phase_two else 20.0, 3.0)
		get_parent().add_child(shard)

func _on_attack_start() -> void:
	# Slam telegraph handled in _animate (arms raise during windup).
	AudioMan.play("swing", 0.7, -3.0)

func _deal_hit(player: Node3D) -> void:
	# Crushing slam: AoE around the impact point.
	if dead or player == null or not is_instance_valid(player):
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() < _slam_radius and player.has_method("take_damage"):
		player.take_damage(attack_damage, global_position)
	# Shockwave ring on the ice.
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(to.normalized().x * 2.0, 0.3, to.normalized().z * 2.0),
		Color(0.6, 0.85, 1.0))
	AudioMan.play("hit", 1.0, -3.0)

func apply_slow(duration: float) -> void:
	# The Frozen Heart barely feels mortal chill: quarter duration.
	_slow_timer = maxf(_slow_timer, duration * 0.25)

func _animate(delta: float) -> void:
	if body == null:
		return
	var t := _anim_time
	match _state:
		"wander", "chase":
			# Heavy stomp: bob and sway, arms swing.
			var spd := 6.0 if _state == "chase" else 3.0
			body.position.y = absf(sin(t * spd)) * 0.12
			body.rotation.z = sin(t * spd) * 0.03
			if _arm_l != null:
				_arm_l.rotation.x = sin(t * spd) * 0.5
				_arm_r.rotation.x = -sin(t * spd) * 0.5
		"windup":
			# Raise both arms high for the slam.
			body.position.y = 0.0
			if _arm_l != null:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.4, minf(1.0, 8.0 * delta))
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.4, minf(1.0, 8.0 * delta))
			_warn_label.modulate.a = 0.6 + 0.4 * sin(t * 25.0)
		"attack":
			# Crash down.
			if _arm_l != null:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.6, minf(1.0, 14.0 * delta))
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.6, minf(1.0, 14.0 * delta))
	# The heart pulses.
	if _core_mat != null:
		var pulse := 2.0 + sin(t * 4.0) * 0.6
		if _phase_two:
			pulse = 4.0 + sin(t * 9.0) * 1.2
		_core_mat.emission_energy_multiplier = pulse

func _on_player_died() -> void:
	# The heart reclaims its strength if the hero falls.
	if not dead:
		hp = max_hp
		_phase_two = false
		chase_speed = 3.4
		attack_cooldown = 2.4
		_volley_cooldown = 7.0

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	body_cs.set_deferred("disabled", true)
	_warn_label.visible = false
	AudioMan.play("bone_die", 1.0, -2.0)
	# Shatter: bursts of ice where it stood.
	var scene := get_tree().current_scene
	HitEffects.burst(scene, global_position + Vector3(0, 2.5, 0), Color(0.6, 0.85, 1.0))
	HitEffects.burst(scene, global_position + Vector3(0, 1.2, 0), Color(0.8, 0.95, 1.0))
	HitEffects.burst(scene, global_position + Vector3(0, 0.4, 0), Color(0.4, 0.7, 1.0))
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_reward)
		HitEffects.damage_number(scene, global_position + Vector3(0, 3.6, 0),
			"+%d XP" % xp_reward, Color(1.0, 0.85, 0.3))
	if player != null and player.has_method("add_gold"):
		player.add_gold(GOLD_REWARD)
		HitEffects.damage_number(scene, global_position + Vector3(0, 4.2, 0),
			"+%d G" % GOLD_REWARD, Color(1.0, 0.75, 0.2))
	# The heart shard, and a potion shower.
	var shard := preload("res://src/item/item_drop.gd").new()
	shard.set("item_id", "frost_shard")
	shard.position = position + Vector3(0, 0.2, 1.5)
	get_parent().add_child(shard)
	for i in 4:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2))
		get_parent().add_child(drop)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("MORVAIN SHATTERED")
	died.emit(self)
	# Collapse into the ice, then gone.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(body, "scale", Vector3(1.3, 0.15, 1.3), 0.6)
	tw.tween_property(self, "position:y", position.y - 2.0, 1.4).set_delay(0.6)
	tw.chain().tween_callback(queue_free)
