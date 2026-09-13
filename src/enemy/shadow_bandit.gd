class_name ShadowBandit
extends Skeleton
## A living rogue turned cutthroat, preying on travelers in the western wilds.
## Fragile, but very fast with a quick blade. Cowardly too: badly hurt, a
## bandit breaks off and runs, whistles up the nearest bandits, and comes
## back with them, angrier than before.

func _init() -> void:
	max_hp = 22.0
	walk_speed = 3.2
	chase_speed = 5.4
	turn_speed = 10.0
	aggro_range = 14.0
	attack_range = 2.0
	attack_damage = 10.0
	attack_cooldown = 1.1
	windup_time = 0.45
	xp_reward = 35
	voice = "laugh"
	voice_pitch = 1.0
	drops = [["potion", 0.30, 1, 1], ["stolen_trinket", 0.35, 1, 1]]
	# Bandits haunt the western wilds, away from the skeletons.
	roam_min = Vector2(-27.0, 34.0)
	roam_max = Vector2(-8.0, 66.0)
	# The Rogue rig uses the plain Death_A clip and has no combat idle.
	anim_death = "Death_A"
	anim_windup = "Idle"

const FLEE_TIME := 3.5
const REGROUP_RANGE := 26.0
const ENRAGE_TIME := 10.0
const ENRAGE_MULT := 1.3

var _fled_once := false
var _flee_timer := 0.0
var _enrage_timer := 0.0
var _base_damage := 0.0

func _ready() -> void:
	super._ready()
	_base_damage = attack_damage
	# Dark violet shadow tint.
	_tint_rig(Color(0.55, 0.45, 0.8))

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _enrage_timer > 0.0:
		_enrage_timer -= delta
		if _enrage_timer <= 0.0:
			attack_damage = _base_damage
	if _state != "flee":
		super._physics_process(delta)
		return
	# Flee: run from the nearest party member, then rally.
	_flee_timer -= delta
	var victim := _nearest_victim()
	if victim != null:
		var away: Vector3 = global_position - victim.global_position
		away.y = 0.0
		if away.length() > 0.01:
			_move_toward(away.normalized(), chase_speed * 1.15, delta)
			_play(anim_walk)
	if _flee_timer <= 0.0:
		_regroup()
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# The same keep-outs the normal walk obeys: its own ground, the towns,
	# and the water.
	_clamp_to_roam()
	_keep_out_of_safe_ground()

func take_damage(amount: float, from_pos: Vector3) -> void:
	super.take_damage(amount, from_pos)
	if dead or _fled_once or hp > max_hp * 0.35:
		return
	# Break off and run.
	_fled_once = true
	_state = "flee"
	_flee_timer = FLEE_TIME
	_warn_label.visible = false
	AudioMan.play("laugh", 1.3, -4.0)

## Whistle: every bandit nearby joins the hunt, and this one comes back enraged.
func _regroup() -> void:
	for n in get_tree().get_nodes_in_group("skeletons"):
		if n == self or not (n is ShadowBandit) or bool(n.get("dead")):
			continue
		if global_position.distance_to((n as Node3D).global_position) < REGROUP_RANGE:
			n.set("_state", "chase")
	_state = "chase"
	_enrage_timer = ENRAGE_TIME
	attack_damage = _base_damage * ENRAGE_MULT
	_base_damage = _base_damage  # unchanged; restored when the rage ends
	AudioMan.play("laugh", 0.8, -2.0)

func is_enraged() -> bool:
	return _enrage_timer > 0.0
