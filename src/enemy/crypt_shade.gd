class_name CryptShade
extends Skeleton
## A Crypt Shade: whatever is left of someone the vault kept. Barely
## there, very fast, and it hits from a standstill. Shades blink a short
## distance towards their prey instead of closing the gap on foot.

const BLINK_COOLDOWN := 4.5
const BLINK_RANGE := 11.0
const BLINK_DISTANCE := 5.0

var _blink_cd := 2.0

func _init() -> void:
	max_hp = 46.0
	walk_speed = 2.8
	chase_speed = 5.2
	turn_speed = 12.0
	aggro_range = 16.0
	attack_range = 2.0
	attack_damage = 30.0
	attack_cooldown = 1.2
	windup_time = 0.45
	xp_reward = 150
	gold_min = 25
	gold_max = 55
	voice = "wisp"
	voice_pitch = 0.7
	drops = [["potion", 0.35, 1, 1], ["grave_dust", 0.6, 1, 2]]
	roam_min = Vector2(-30.0, 195.0)
	roam_max = Vector2(30.0, 372.0)
	avoid_lake = false
	anim_attack = "1H_Melee_Attack_Slice_Diagonal"
	anim_death = "Death_A"
	anim_windup = "Idle"

func _ready() -> void:
	super._ready()
	_tint_rig(Color(0.28, 0.30, 0.42))
	_make_translucent()

## Shades are half here: the rig is drawn faded rather than solid.
func _make_translucent() -> void:
	for mi in _collect_meshes(rig):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var mat := mi.get_surface_override_material(si) as StandardMaterial3D
			if mat == null:
				continue
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.62
			mat.emission_enabled = true
			mat.emission = Color(0.25, 0.45, 0.7)
			mat.emission_energy_multiplier = 0.5

func _physics_process(delta: float) -> void:
	_blink_cd = maxf(0.0, _blink_cd - delta)
	if not dead and _blink_cd <= 0.0 and _state == "chase":
		_try_blink()
	super._physics_process(delta)

## Step through the dark: a short jump straight at whoever it is hunting.
func _try_blink() -> void:
	var victim := _nearest_victim()
	if victim == null:
		return
	var to: Vector3 = victim.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < attack_range * 1.6 or d > BLINK_RANGE:
		return
	_blink_cd = BLINK_COOLDOWN
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 0.9, 0), Color(0.35, 0.5, 0.8))
	var step := to.normalized() * minf(BLINK_DISTANCE, d - attack_range)
	global_position += Vector3(step.x, 0.0, step.z)
	global_position.x = clampf(global_position.x, roam_min.x, roam_max.x)
	global_position.z = clampf(global_position.z, roam_min.y, roam_max.y)
	AudioMan.play("wisp", 0.7, -4.0)
	HitEffects.burst(get_tree().current_scene,
		global_position + Vector3(0, 0.9, 0), Color(0.35, 0.5, 0.8))
