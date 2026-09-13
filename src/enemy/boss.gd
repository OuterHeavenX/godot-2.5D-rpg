class_name Boss
extends Skeleton
## Vorgath, the Drowned King — boss of the cursed island.
## A giant skeleton that never leaves its island and never respawns.

const BOSS_NAME := "VORGATH, THE DROWNED KING"
const GOLD_REWARD := 250

var boss_id := "vorgath"
var boss_name := BOSS_NAME

func _ready() -> void:
	max_hp = 450.0
	attack_damage = 26.0
	chase_speed = 3.1
	walk_speed = 1.4
	aggro_range = 12.0
	attack_range = 2.3
	attack_cooldown = 2.2
	windup_time = 0.9
	xp_reward = 400
	avoid_lake = false
	# Island bounds: never leaves.
	roam_min = Vector2(34.0, 51.0)
	roam_max = Vector2(43.0, 63.0)
	super._ready()
	add_to_group("boss")
	scale = Vector3(1.65, 1.65, 1.65)
	_build_crown()
	_build_nameplate()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)

func _build_crown() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.65, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.35
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.30
	band_mesh.bottom_radius = 0.32
	band_mesh.height = 0.18
	band_mesh.radial_segments = 8
	band.mesh = band_mesh
	band.position = Vector3(0, 2.62, 0)
	band.material_override = gold
	add_child(band)
	for i in 5:
		var ang := TAU * float(i) / 5.0
		var spike := MeshInstance3D.new()
		var spike_mesh := CylinderMesh.new()
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.06
		spike_mesh.height = 0.28
		spike_mesh.radial_segments = 6
		spike.mesh = spike_mesh
		spike.position = Vector3(0.26 * cos(ang), 2.82, 0.26 * sin(ang))
		spike.material_override = gold
		add_child(spike)

func _build_nameplate() -> void:
	var plate := Label3D.new()
	plate.text = BOSS_NAME
	plate.font_size = 48
	plate.pixel_size = 0.002
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.modulate = Color(1.0, 0.35, 0.25)
	plate.outline_size = 10
	plate.outline_modulate = Color(0, 0, 0, 0.9)
	plate.position = Vector3(0, 3.1, 0)
	add_child(plate)

func _on_player_died() -> void:
	# The king reclaims his strength if the hero falls.
	if not dead:
		hp = max_hp

func _die() -> void:
	dead = true
	_state = "dead"
	velocity = Vector3.ZERO
	body_cs.set_deferred("disabled", true)
	_play(anim_death)
	AudioMan.play("bone_die", 0.6, 2.0)
	# Big burst where he fell.
	HitEffects.burst(get_tree().current_scene, global_position + Vector3(0, 1.5, 0))
	HitEffects.burst(get_tree().current_scene, global_position + Vector3(0, 1.0, 0))
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
	# The crown, and a potion shower.
	var crown := preload("res://src/item/item_drop.gd").new()
	crown.set("item_id", "drowned_crown")
	crown.position = position + Vector3(0, 0.2, 1.0)
	get_parent().add_child(crown)
	for i in 3:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-1.0, 1.0), 0.2, randf_range(-1.0, 1.0))
		get_parent().add_child(drop)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("VORGATH SLAIN")
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(self, "position:y", position.y - 2.0, 1.2)
	tw.tween_callback(queue_free)
