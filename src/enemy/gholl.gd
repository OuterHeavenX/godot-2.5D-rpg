class_name Gholl
extends Skeleton
## Gholl, the Mire Horror — whatever the fen made out of everyone it took.
##
## It fights from the water. Twice in a fight it sinks under the pool, is
## gone for a few seconds, and comes up beside whoever it was chasing with
## two of the drowned in tow. Between dives it reaches: long, slow sweeps
## that catch anything standing on its ground.

const BOSS_NAME := "GHOLL, THE MIRE HORROR"
const GOLD_REWARD := 900
const SUBMERGE_TIME := 3.0
const HUSK_SCENE := preload("res://src/enemy/drowned_husk.tscn")
const SWEEP_COOLDOWN := 7.0
const SWEEP_RADIUS := 6.2
const SWEEP_DAMAGE := 30.0

var boss_id := "gholl"
var boss_name := BOSS_NAME

var _fight_base := {}
var _adds: Array[Node] = []
var _dives_left := 2
var _submerged := false
var _submerge_timer := 0.0
var _sweep_cd := 5.0

func _init() -> void:
	max_hp = 1150.0
	walk_speed = 1.3
	chase_speed = 3.0
	turn_speed = 4.5
	aggro_range = 19.0
	attack_range = 3.2
	attack_damage = 40.0
	attack_cooldown = 2.3
	windup_time = 1.0
	xp_reward = 1600
	hit_reach = 1.5
	voice = "growl"
	voice_pitch = 0.45
	avoid_lake = false
	drops = []
	anim_death = "Death_C_Skeletons"
	# Its pool. It has never left it and it never will.
	roam_min = Vector2(274.0, -12.0)
	roam_max = Vector2(298.0, 12.0)

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	_fight_base = {"cd": attack_cooldown, "chase": chase_speed}
	scale = Vector3(2.1, 2.1, 2.1)
	_tint_rig(Color(0.30, 0.55, 0.38))
	_build_nameplate()
	_build_growths()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)

func _build_nameplate() -> void:
	var plate := Label3D.new()
	plate.text = BOSS_NAME
	plate.font_size = 48
	plate.pixel_size = 0.002
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color(0.55, 1.0, 0.6)
	plate.outline_size = 10
	plate.outline_modulate = Color(0, 0, 0, 0.9)
	plate.position = Vector3(0, 2.6, 0)
	# Only near the fight, and never through a wall: the HUD carries the
	# name for anyone further out.
	plate.visibility_range_end = 30.0
	plate.visibility_range_end_margin = 4.0
	add_child(plate)

## Weed, bone and bog iron grown into its back.
func _build_growths() -> void:
	var weed := StandardMaterial3D.new()
	weed.albedo_color = Color(0.20, 0.34, 0.22)
	weed.roughness = 0.95
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.32, 0.24, 0.16)
	rust.roughness = 0.85
	rust.metallic = 0.35
	for i in 9:
		var spur := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.10
		cm.height = randf_range(0.5, 1.1)
		cm.radial_segments = 5
		spur.mesh = cm
		spur.material_override = weed if i % 2 == 0 else rust
		var ang := TAU * float(i) / 9.0
		spur.position = Vector3(cos(ang) * 0.36, 1.25 + randf_range(-0.2, 0.35), sin(ang) * 0.36)
		spur.rotation = Vector3(randf_range(-0.6, 0.6), ang, randf_range(-0.6, 0.6))
		add_child(spur)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _submerged:
		_submerge_timer -= delta
		if _submerge_timer <= 0.0:
			_resurface()
		return
	_sweep_cd = maxf(0.0, _sweep_cd - delta)
	if _sweep_cd <= 0.0 and _state in ["chase", "windup", "attack"]:
		_sweep()
	super._physics_process(delta)
	# It goes under at two thirds and at one third, and comes back worse.
	var threshold := max_hp * (float(_dives_left) / 3.0)
	if _dives_left > 0 and hp <= threshold:
		_submerge()

## A long reach across its own ground: everything standing on the pool
## gets hit, whether it is in front of Gholl or not.
func _sweep() -> void:
	_sweep_cd = SWEEP_COOLDOWN
	AudioMan.play("squish", 0.6, 0.0)
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 0.4, 0), Color(0.3, 0.6, 0.4))
	for target in _victims():
		if global_position.distance_to(target.global_position) > SWEEP_RADIUS:
			continue
		if target.has_method("take_damage"):
			target.take_damage(SWEEP_DAMAGE, global_position)
		HitEffects.burst(get_tree().current_scene,
			target.global_position + Vector3(0, 0.8, 0), Color(0.3, 0.6, 0.4))

## Down into the pool: untouchable, and the water starts giving things up.
func _submerge() -> void:
	_dives_left -= 1
	_submerged = true
	_submerge_timer = SUBMERGE_TIME
	_state = "dive"
	velocity = Vector3.ZERO
	rig.position.y = -3.0
	_warn_label.visible = false
	body_cs.set_deferred("disabled", true)
	AudioMan.play("squish", 0.5, -2.0)
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 0.4, 0), Color(0.25, 0.5, 0.35))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("THE POOL TAKES GHOLL BACK")
	for offset: Vector3 in [Vector3(5.0, 0, 4.0), Vector3(-5.0, 0, -4.0)]:
		var husk := HUSK_SCENE.instantiate()
		husk.position = global_position + offset
		husk.set("lurk_in_place", true)
		husk.set("roam_min", roam_min - Vector2(2.0, 2.0))
		husk.set("roam_max", roam_max + Vector2(2.0, 2.0))
		get_parent().add_child(husk)
		_adds.append(husk)
		if husk.has_method("scale_to_level"):
			var player := get_tree().get_first_node_in_group("player")
			husk.scale_to_level(int(player.get("level")) if player != null else 1)

## Up again, right beside whoever it was hunting.
func _resurface() -> void:
	_submerged = false
	rig.position.y = 0.0
	body_cs.set_deferred("disabled", false)
	var victim := _nearest_victim()
	if victim != null:
		var to: Vector3 = global_position - victim.global_position
		to.y = 0.0
		var behind := to.normalized() * 2.6 if to.length() > 0.1 else Vector3(2.6, 0, 0)
		global_position = victim.global_position + behind
		global_position.x = clampf(global_position.x, roam_min.x, roam_max.x)
		global_position.z = clampf(global_position.z, roam_min.y, roam_max.y)
	_state = "chase"
	_sweep_cd = 1.2
	attack_cooldown = maxf(1.4, attack_cooldown - 0.35)
	chase_speed += 0.4
	AudioMan.play("growl", 0.45, 1.0)
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 0.6, 0), Color(0.35, 0.7, 0.45))

func take_damage(amount: float, from_pos: Vector3) -> void:
	if _submerged:
		return  # Under the water, nothing reaches it.
	super.take_damage(amount, from_pos)

func _on_player_died() -> void:
	# The pool closes over it and everything it brought up goes back down:
	# a fresh attempt should meet the same fight, not a faster one with the
	# last attempt's drowned still standing in the water.
	if dead:
		return
	hp = max_hp
	_dives_left = 2
	attack_cooldown = float(_fight_base["cd"])
	chase_speed = float(_fight_base["chase"])
	if _submerged:
		_submerged = false
		_submerge_timer = 0.0
		rig.position.y = 0.0
		body_cs.set_deferred("disabled", false)
		_state = "wander"
	for add in _adds:
		if is_instance_valid(add):
			add.queue_free()
	_adds.clear()

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	body_cs.set_deferred("disabled", true)
	_play(anim_death)
	AudioMan.play("squish", 0.4, 2.0)
	HitEffects.burst(get_tree().current_scene, global_position + Vector3(0, 1.5, 0),
		Color(0.35, 0.7, 0.45))
	HitEffects.burst(get_tree().current_scene, global_position + Vector3(0, 1.0, 0),
		Color(0.35, 0.7, 0.45))
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_reward)
		HitEffects.damage_number(get_tree().current_scene,
			global_position + Vector3(0, 2.6, 0),
			"+%d XP" % xp_reward, Color(1.0, 0.85, 0.3))
	if player != null and player.has_method("add_gold"):
		player.add_gold(GOLD_REWARD)
		HitEffects.damage_number(get_tree().current_scene,
			global_position + Vector3(0, 3.1, 0),
			"+%d G" % GOLD_REWARD, Color(1.0, 0.75, 0.2))
	var heart := preload("res://src/item/item_drop.gd").new()
	heart.set("item_id", "mire_heart")
	heart.position = position + Vector3(0, 0.2, 1.2)
	get_parent().add_child(heart)
	var iron := preload("res://src/item/item_drop.gd").new()
	iron.set("item_id", "bog_iron")
	iron.set("count", 5)
	iron.position = position + Vector3(1.2, 0.2, -0.6)
	get_parent().add_child(iron)
	for i in 3:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2))
		get_parent().add_child(drop)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("GHOLL SLAIN")
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(self, "position:y", position.y - 2.5, 1.4)
	tw.tween_callback(queue_free)
