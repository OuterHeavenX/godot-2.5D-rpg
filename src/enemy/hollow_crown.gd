class_name HollowCrown
extends Skeleton
## The Hollow Crown — what wore the crown before Vorgath did, sitting at
## the bottom of the well the village has been drawing water from all
## along.
##
## It fights the way the whole vault fights, all at once: it reaches
## through the floor for you, it steps out of one shadow into another,
## it takes back what you take off it, and at half health it wakes its
## court.

const BOSS_NAME := "THE HOLLOW CROWN"
const GOLD_REWARD := 1500
const SHADE_SCENE := preload("res://src/enemy/crypt_shade.tscn")
const SPIKE_COOLDOWN := 6.0
const SPIKE_RADIUS := 7.5
const SPIKE_DAMAGE := 34.0
const SPIKE_WARNING := 1.1
const BLINK_COOLDOWN := 9.0
const DRAIN_SHARE := 0.2

var boss_id := "hollow"
var boss_name := BOSS_NAME

var _fight_base := {}
var _adds: Array[Node] = []
var _spike_cd := 4.0
var _blink_cd := 7.0
var _court_woken := false
var _crown: Node3D

func _init() -> void:
	max_hp = 1800.0
	walk_speed = 1.6
	chase_speed = 3.8
	turn_speed = 6.0
	aggro_range = 24.0
	attack_range = 3.0
	attack_damage = 46.0
	attack_cooldown = 2.0
	windup_time = 0.85
	xp_reward = 2500
	hit_reach = 1.5
	voice = "growl"
	voice_pitch = 0.4
	avoid_lake = false
	drops = []
	anim_attack = "2H_Melee_Attack_Spin"
	anim_death = "Death_C_Skeletons"
	roam_min = Vector2(-19.0, 343.0)
	roam_max = Vector2(19.0, 373.0)

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	_fight_base = {"cd": attack_cooldown, "chase": chase_speed}
	scale = Vector3(1.9, 1.9, 1.9)
	_tint_rig(Color(0.42, 0.40, 0.52))
	_build_nameplate()
	_build_crown()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)

func _build_nameplate() -> void:
	var plate := Label3D.new()
	plate.text = BOSS_NAME
	plate.font_size = 52
	plate.pixel_size = 0.002
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.modulate = Color(0.85, 0.75, 1.0)
	plate.outline_size = 10
	plate.outline_modulate = Color(0, 0, 0, 0.9)
	plate.position = Vector3(0, 2.8, 0)
	# Only near the fight, and never through a wall: the HUD carries the
	# name for anyone further out.
	plate.visibility_range_end = 30.0
	plate.visibility_range_end_margin = 4.0
	add_child(plate)

## The crown itself, floating where a head would be if there were one.
func _build_crown() -> void:
	_crown = Node3D.new()
	_crown.position = Vector3(0, 1.95, 0)
	add_child(_crown)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.75, 0.62, 0.28)
	gold.metallic = 0.85
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(0.5, 0.4, 0.75)
	gold.emission_energy_multiplier = 0.9
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.24
	bm.outer_radius = 0.36
	bm.rings = 10
	bm.ring_segments = 6
	band.mesh = bm
	band.material_override = gold
	_crown.add_child(band)
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.07
		sm.height = 0.34
		sm.radial_segments = 5
		spike.mesh = sm
		spike.material_override = gold
		spike.position = Vector3(cos(ang) * 0.3, 0.18, sin(ang) * 0.3)
		_crown.add_child(spike)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _crown != null:
		_crown.rotation.y += delta * 0.8
	_spike_cd = maxf(0.0, _spike_cd - delta)
	_blink_cd = maxf(0.0, _blink_cd - delta)
	if _state in ["chase", "windup", "attack"]:
		if _spike_cd <= 0.0:
			_call_spikes()
		elif _blink_cd <= 0.0:
			_step_through_shadow()
	super._physics_process(delta)
	if not _court_woken and hp <= max_hp * 0.5:
		_wake_the_court()

## It reaches up through the floor where its prey is standing. The ground
## cracks first — that is the only warning anyone gets.
func _call_spikes() -> void:
	_spike_cd = SPIKE_COOLDOWN
	var victim := _nearest_victim()
	if victim == null:
		return
	var at: Vector3 = victim.global_position
	var mark := _mark_ground(at)
	AudioMan.play("cast", 0.5, -2.0)
	var tw := create_tween()
	tw.tween_interval(SPIKE_WARNING)
	tw.tween_callback(_erupt.bind(at, mark))

## A ring of cracks on the floor where the spikes will come up.
func _mark_ground(at: Vector3) -> Node3D:
	var mark := Node3D.new()
	mark.position = Vector3(at.x, 0.06, at.z)
	get_parent().add_child(mark)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.45, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = SPIKE_RADIUS - 0.4
	tm.outer_radius = SPIKE_RADIUS
	tm.rings = 20
	tm.ring_segments = 5
	ring.mesh = tm
	ring.material_override = mat
	mark.add_child(ring)
	return mark

func _erupt(at: Vector3, mark: Node3D) -> void:
	if is_instance_valid(mark):
		mark.queue_free()
	if dead:
		return
	HitEffects.burst(get_tree().current_scene, at + Vector3(0, 0.5, 0),
		Color(0.6, 0.45, 0.95))
	AudioMan.play("bone_hit", 0.5, 2.0)
	for target in _victims():
		if Vector2(target.global_position.x - at.x,
				target.global_position.z - at.z).length() > SPIKE_RADIUS:
			continue
		if target.has_method("take_damage"):
			target.take_damage(SPIKE_DAMAGE, at)
		HitEffects.burst(get_tree().current_scene,
			target.global_position + Vector3(0, 0.9, 0), Color(0.6, 0.45, 0.95))

## It does not cross the floor. It stops being in one place and starts
## being in another.
func _step_through_shadow() -> void:
	var victim := _nearest_victim()
	if victim == null:
		return
	var to: Vector3 = victim.global_position - global_position
	to.y = 0.0
	if to.length() < 6.0:
		return
	_blink_cd = BLINK_COOLDOWN
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 1.2, 0), Color(0.5, 0.4, 0.8))
	var behind: Vector3 = victim.global_position + to.normalized() * 2.8
	global_position = Vector3(
		clampf(behind.x, roam_min.x, roam_max.x), global_position.y,
		clampf(behind.z, roam_min.y, roam_max.y))
	AudioMan.play("cast", 0.4, 0.0)
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 1.2, 0), Color(0.5, 0.4, 0.8))

## Half dead, it wakes the court that was buried with it.
func _wake_the_court() -> void:
	_court_woken = true
	attack_cooldown *= 0.8
	chase_speed += 0.5
	AudioMan.play("growl", 0.35, 2.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("THE COURT RISES")
	var player := get_tree().get_first_node_in_group("player")
	var level := int(player.get("level")) if player != null else 1
	for i in 4:
		var ang := TAU * float(i) / 4.0
		var shade := SHADE_SCENE.instantiate()
		shade.position = global_position + Vector3(cos(ang) * 6.0, 0.1, sin(ang) * 6.0)
		shade.set("roam_min", roam_min - Vector2(2.0, 2.0))
		shade.set("roam_max", roam_max + Vector2(2.0, 2.0))
		get_parent().add_child(shade)
		_adds.append(shade)
		if shade.has_method("scale_to_level"):
			shade.scale_to_level(level)

## Whatever it lands, it keeps a share of.
func _deal_hit(target: Node3D) -> void:
	var before := hp
	super._deal_hit(target)
	if dead or target == null or not is_instance_valid(target):
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if to.length() >= attack_range * hit_reach:
		return
	if hp > before:
		return  # The blow killed the hero, which put this thing back to full.
	hp = minf(max_hp, before + attack_damage * DRAIN_SHARE)
	HitEffects.damage_number(get_tree().current_scene,
		global_position + Vector3(0, 2.4, 0),
		"+%d" % int(attack_damage * DRAIN_SHARE), Color(0.6, 0.45, 0.95))

func _on_player_died() -> void:
	# The court lies back down with it. Otherwise every attempt left four
	# more shades in the room and a faster thing on the throne.
	if dead:
		return
	hp = max_hp
	_court_woken = false
	attack_cooldown = float(_fight_base["cd"])
	chase_speed = float(_fight_base["chase"])
	for add in _adds:
		if is_instance_valid(add):
			add.queue_free()
	_adds.clear()

func _die() -> void:
	_begin_death()
	AudioMan.play("bone_die", 0.4, 2.0)
	for i in 3:
		HitEffects.burst(get_tree().current_scene,
			global_position + Vector3(0, 0.6 + i * 0.7, 0), Color(0.6, 0.45, 0.95))
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
	var crown := preload("res://src/item/item_drop.gd").new()
	crown.set("item_id", "hollow_crown")
	crown.position = position + Vector3(0, 0.2, 1.2)
	get_parent().add_child(crown)
	var dust := preload("res://src/item/item_drop.gd").new()
	dust.set("item_id", "grave_dust")
	dust.set("count", 6)
	dust.position = position + Vector3(1.2, 0.2, -0.6)
	get_parent().add_child(dust)
	for i in 4:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2))
		get_parent().add_child(drop)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("THE HOLLOW CROWN FALLS")
	if _crown != null:
		var ctw := create_tween()
		ctw.tween_property(_crown, "position:y", 0.3, 1.6)
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(self, "position:y", position.y - 2.5, 1.4)
	tw.tween_callback(queue_free)
