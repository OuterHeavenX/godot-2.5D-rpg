class_name BogWight
extends Skeleton
## A Bog Wight: a knight of some drowned order, still in its armour, still
## walking its post. Slow and very hard to put down — and every blow it
## lands drags its victim in closer, so backing off is not a plan.

const DRAG_DISTANCE := 1.6

func _init() -> void:
	max_hp = 115.0
	walk_speed = 1.3
	chase_speed = 2.5
	turn_speed = 5.0
	aggro_range = 12.0
	attack_range = 2.4
	attack_damage = 27.0
	attack_cooldown = 2.2
	windup_time = 1.0
	xp_reward = 120
	gold_min = 20
	gold_max = 45
	hit_reach = 1.4
	voice = "growl"
	voice_pitch = 0.55
	drops = [["potion", 0.45, 1, 1], ["bog_iron", 0.55, 1, 2],
		["black_pearl", 0.25, 1, 1]]
	roam_min = Vector2(34.0, -28.0)
	roam_max = Vector2(266.0, 28.0)
	avoid_lake = false
	anim_attack = "1H_Melee_Attack_Stab"
	anim_death = "Death_A"
	anim_windup = "Idle"

func _ready() -> void:
	super._ready()
	# Waterlogged steel, green with two centuries of standing water.
	_tint_rig(Color(0.45, 0.72, 0.52))
	rig.scale = Vector3(1.1, 1.1, 1.1)

## The wight does not swing so much as reach. What it catches, it keeps.
func _deal_hit(target: Node3D) -> void:
	if dead or target == null or not is_instance_valid(target):
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	if to.length() >= attack_range * hit_reach:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position)
	# Drag them in: the fen is full of things that pull.
	var pull := to.normalized() * -DRAG_DISTANCE
	target.global_position += Vector3(pull.x, 0.0, pull.z)
	HitEffects.burst(get_tree().current_scene,
		target.global_position + Vector3(0, 0.6, 0), Color(0.3, 0.5, 0.35))
