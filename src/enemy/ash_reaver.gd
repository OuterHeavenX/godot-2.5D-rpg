class_name AshReaver
extends Skeleton
## An Ash Reaver: one of the clan that took the highlands after the fires.
## Living, fast, and never alone — a reaver who spots the hero bellows for
## the rest of the war band, and every reaver within earshot comes.

const RALLY_RANGE := 20.0
const RALLY_COOLDOWN := 6.0

var _rally_cd := 0.0

func _init() -> void:
	max_hp = 58.0
	walk_speed = 2.4
	chase_speed = 4.7
	turn_speed = 9.0
	aggro_range = 15.0
	attack_range = 2.2
	attack_damage = 19.0
	attack_cooldown = 1.3
	windup_time = 0.55
	xp_reward = 80
	gold_min = 14
	gold_max = 34
	voice = "growl"
	voice_pitch = 1.15
	drops = [["potion", 0.35, 1, 1], ["ash_cinder", 0.55, 1, 2],
		["stolen_trinket", 0.2, 1, 1]]
	roam_min = Vector2(-266.0, -28.0)
	roam_max = Vector2(-32.0, 28.0)
	avoid_lake = false
	# The Barbarian rig: heavy chop, no combat idle.
	anim_attack = "1H_Melee_Attack_Chop"
	anim_death = "Death_A"
	anim_windup = "Idle"

func _ready() -> void:
	super._ready()
	# Ash-scoured leather and fire-blackened steel.
	_tint_rig(Color(0.85, 0.52, 0.42))

func _physics_process(delta: float) -> void:
	_rally_cd = maxf(0.0, _rally_cd - delta)
	super._physics_process(delta)

## Spotting the hero is a war cry: the band answers it.
func _on_aggro() -> void:
	super._on_aggro()
	if _rally_cd > 0.0:
		return
	_rally_cd = RALLY_COOLDOWN
	for node in get_tree().get_nodes_in_group("skeletons"):
		var mate := node as AshReaver
		if mate == null or mate == self or mate.dead:
			continue
		if global_position.distance_to(mate.global_position) > RALLY_RANGE:
			continue
		mate.answer_rally(global_position)

## Answer another reaver's cry: break off whatever you were doing and run
## towards the trouble.
func answer_rally(from: Vector3) -> void:
	if dead or _state == "chase" or _state == "windup" or _state == "attack":
		return
	_rally_cd = RALLY_COOLDOWN
	_state = "wander"
	_target = from
	_idle_timer = 0.0
