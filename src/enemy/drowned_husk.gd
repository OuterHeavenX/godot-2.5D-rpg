class_name DrownedHusk
extends Skeleton
## A waterlogged skeleton warrior that crawled out of the black water.
## Slow, but hits like a drowned anchor and takes a beating. Husks lurk
## submerged along the shoreline and burst out when someone walks close,
## then sink back once the shore is quiet.

func _init() -> void:
	max_hp = 70.0
	walk_speed = 1.5
	chase_speed = 2.6
	aggro_range = 11.0
	attack_range = 2.3
	attack_damage = 18.0
	attack_cooldown = 2.0
	windup_time = 0.9
	xp_reward = 45
	voice = "growl"
	voice_pitch = 0.8
	drops = [["potion", 0.40, 1, 1], ["bone_shard", 0.4, 1, 1], ["black_pearl", 0.5, 1, 2]]
	# The husks shamble along the black water's edge, and lurk in it.
	roam_min = Vector2(6.0, 40.0)
	roam_max = Vector2(29.0, 70.0)
	avoid_lake = false

const LURK_X := 26.0          # in the shallows, just past the shoreline
const AMBUSH_RANGE := 7.0
const BURST_TIME := 1.6
const BURST_MULT := 1.8

## In the southern wilds a husk wades back to the lake shore to lurk. In
## the Mirefen the whole region is water, so it sinks where it stands.
var lurk_in_place := false

var _lurking := false
var _burst_timer := 0.0
var _base_chase := 0.0

func _ready() -> void:
	super._ready()
	_base_chase = chase_speed
	# Sickly green waterlogged tint.
	_tint_rig(Color(0.55, 1.0, 0.65))
	# Bulkier than a common skeleton.
	rig.scale = Vector3(1.15, 1.15, 1.15)
	_start_lurking()

## Sink into the shallows at the shoreline and wait.
func _start_lurking() -> void:
	_lurking = true
	_state = "lurk"
	if not lurk_in_place:
		global_position.x = LURK_X
		global_position.z = clampf(global_position.z,
			IslandLake.WATER_Z0 + 2.0, IslandLake.WATER_Z1 - 4.0)
	rig.position.y = -1.3
	_warn_label.visible = false
	velocity = Vector3.ZERO

func _surface() -> void:
	_lurking = false
	rig.position.y = 0.0
	_state = "chase"
	_burst_timer = BURST_TIME
	chase_speed = _base_chase * BURST_MULT
	AudioMan.play("growl", 0.7, -2.0)
	HitEffects.burst(get_tree().current_scene, global_position + Vector3(0, 0.3, 0), Color(0.2, 0.35, 0.5))

func is_lurking() -> bool:
	return _lurking

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _burst_timer > 0.0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			chase_speed = _base_chase
	if _state == "lurk":
		# Wait, submerged, for something warm to walk the shore.
		var victim := _nearest_victim()
		if victim != null:
			var d := Vector2(victim.global_position.x - global_position.x,
				victim.global_position.z - global_position.z).length()
			if d < AMBUSH_RANGE:
				_surface()
		return
	super._physics_process(delta)
	# Lost the trail: slip back into the water.
	if _state == "wander" and not _lurking:
		_start_lurking()

func take_damage(amount: float, from_pos: Vector3) -> void:
	if _state == "lurk":
		_surface()
	super.take_damage(amount, from_pos)
