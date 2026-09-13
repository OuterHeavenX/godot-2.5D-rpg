class_name Kael
extends Skeleton
## Kael, the Ash Reaver — warlord of the burnt highlands.
##
## He fights the way his clan raids: close the distance in one rush, then
## keep swinging. Below half health he calls the two reavers who never
## leave his fire, and the fight gets faster.

const BOSS_NAME := "KAEL, THE ASH REAVER"
const GOLD_REWARD := 700
const CHARGE_COOLDOWN := 8.5
const CHARGE_MIN := 6.5
const CHARGE_MAX := 19.0
const CHARGE_SPEED := 12.5
const CHARGE_TIME := 0.75
const CHARGE_DAMAGE := 24.0
const REAVER_SCENE := preload("res://src/enemy/ash_reaver.tscn")

var boss_id := "kael"
var boss_name := BOSS_NAME

var _fight_base := {}
var _adds: Array[Node] = []
var _charge_cd := 4.0
var _charge_timer := 0.0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _phase_two := false
var _rage_tinted := false

func _init() -> void:
	max_hp = 900.0
	walk_speed = 1.8
	chase_speed = 4.2
	turn_speed = 7.0
	aggro_range = 20.0
	attack_range = 2.8
	attack_damage = 36.0
	attack_cooldown = 1.9
	windup_time = 0.8
	xp_reward = 1200
	hit_reach = 1.6
	voice = "growl"
	voice_pitch = 0.75
	avoid_lake = false
	drops = []
	anim_attack = "2H_Melee_Attack_Chop"
	anim_death = "Death_A"
	anim_windup = "Idle"
	# He never leaves his own ground. The highlands set the real bounds
	# when they place him; these keep him sane until they do.
	roam_min = Vector2(-298.0, -12.0)
	roam_max = Vector2(-274.0, 12.0)

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	_fight_base = {"dmg": attack_damage, "cd": attack_cooldown, "chase": chase_speed}
	scale = Vector3(1.55, 1.55, 1.55)
	_tint_rig(Color(0.95, 0.40, 0.28))
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
	plate.modulate = Color(1.0, 0.55, 0.25)
	plate.outline_size = 10
	plate.outline_modulate = Color(0, 0, 0, 0.9)
	plate.position = Vector3(0, 2.9, 0)
	# Only near the fight, and never through a wall: the HUD carries the
	# name for anyone further out.
	plate.visibility_range_end = 30.0
	plate.visibility_range_end_margin = 4.0
	add_child(plate)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _charge_timer > 0.0:
		_run_charge(delta)
		return
	_charge_cd = maxf(0.0, _charge_cd - delta)
	if _charge_cd <= 0.0 and _state == "chase":
		var victim := _nearest_victim()
		if victim != null:
			var to: Vector3 = victim.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d > CHARGE_MIN and d < CHARGE_MAX:
				_begin_charge(to.normalized())
				return
	super._physics_process(delta)
	if not _phase_two and hp <= max_hp * 0.5:
		_enter_phase_two()

func _begin_charge(dir: Vector3) -> void:
	_charge_timer = CHARGE_TIME
	_charge_cd = CHARGE_COOLDOWN
	_charge_dir = dir
	_charge_hit = false
	_warn_label.visible = true
	_play(anim_walk)
	AudioMan.play("growl", 0.6, -1.0)

## The rush itself: he covers the ground fast and flattens whatever is in
## the way, once per charge.
func _run_charge(delta: float) -> void:
	_charge_timer -= delta
	_face(_charge_dir, delta * 2.0)
	velocity.x = _charge_dir.x * CHARGE_SPEED
	velocity.z = _charge_dir.z * CHARGE_SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	_clamp_to_roam()
	if not _charge_hit:
		for node in _victims():
			if global_position.distance_to(node.global_position) < 2.6:
				_charge_hit = true
				if node.has_method("take_damage"):
					node.take_damage(CHARGE_DAMAGE, global_position)
				HitEffects.burst(get_tree().current_scene,
					node.global_position + Vector3(0, 1.0, 0))
				break
	if _charge_timer <= 0.0:
		_warn_label.visible = false
		_state = "chase"

## Half dead, Kael calls the two who guard his fire and stops pacing.
func _enter_phase_two() -> void:
	_phase_two = true
	attack_damage *= 1.3
	chase_speed *= 1.15
	attack_cooldown *= 0.85
	if not _rage_tinted:
		# Tinting multiplies what is already there, so only ever once.
		_rage_tinted = true
		_tint_rig(Color(1.0, 0.65, 0.55))
	AudioMan.play("growl", 0.5, 1.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("KAEL CALLS THE BAND")
	for offset: Vector3 in [Vector3(4.0, 0, 4.0), Vector3(4.0, 0, -4.0)]:
		var reaver := REAVER_SCENE.instantiate()
		reaver.position = global_position + offset
		# They fight where he fights.
		reaver.set("roam_min", roam_min - Vector2(2.0, 2.0))
		reaver.set("roam_max", roam_max + Vector2(2.0, 2.0))
		get_parent().add_child(reaver)
		_adds.append(reaver)
		if reaver.has_method("scale_to_level"):
			var player := get_tree().get_first_node_in_group("player")
			reaver.scale_to_level(int(player.get("level")) if player != null else 1)

func _on_player_died() -> void:
	# Kael walks back to his fire and heals up. The hill is still his —
	# and so is the fight: the band he called goes back to the fire with
	# him, and he is no angrier than he started.
	if dead:
		return
	hp = max_hp
	attack_damage = float(_fight_base["dmg"])
	attack_cooldown = float(_fight_base["cd"])
	chase_speed = float(_fight_base["chase"])
	_phase_two = false
	for add in _adds:
		if is_instance_valid(add):
			add.queue_free()
	_adds.clear()

func _die() -> void:
	_begin_death()
	AudioMan.play("bone_die", 0.6, 2.0)
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
	var crest := preload("res://src/item/item_drop.gd").new()
	crest.set("item_id", "reaver_crest")
	crest.position = position + Vector3(0, 0.2, 1.0)
	get_parent().add_child(crest)
	var cinders := preload("res://src/item/item_drop.gd").new()
	cinders.set("item_id", "ash_cinder")
	cinders.set("count", 4)
	cinders.position = position + Vector3(1.0, 0.2, -0.6)
	get_parent().add_child(cinders)
	for i in 3:
		var drop := preload("res://src/item/potion_drop.gd").new()
		drop.position = position + Vector3(randf_range(-1.0, 1.0), 0.2, randf_range(-1.0, 1.0))
		get_parent().add_child(drop)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce"):
		hud.announce("KAEL SLAIN")
	died.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(self, "position:y", position.y - 2.0, 1.2)
	tw.tween_callback(queue_free)
