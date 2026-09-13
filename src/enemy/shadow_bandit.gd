class_name ShadowBandit
extends Skeleton
## A living rogue turned cutthroat, preying on travelers in the western wilds.
## Fragile, but very fast with a quick blade.

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
	# Bandits haunt the western wilds, away from the skeletons.
	roam_min = Vector2(-27.0, 34.0)
	roam_max = Vector2(-8.0, 66.0)
	# The Rogue rig uses the plain Death_A clip and has no combat idle.
	anim_death = "Death_A"
	anim_windup = "Idle"

func _ready() -> void:
	super._ready()
	# Dark violet shadow tint.
	_tint_rig(Color(0.55, 0.45, 0.8))

func _tint_rig(tint: Color) -> void:
	for mi in _collect_meshes(rig):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for si in range(mesh.get_surface_count()):
			var mat: Material = mi.get_surface_override_material(si)
			if mat == null:
				mat = mesh.surface_get_material(si)
			if mat is StandardMaterial3D:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = dup.albedo_color * tint
				mi.set_surface_override_material(si, dup)

func _collect_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for ch in n.get_children():
		out.append_array(_collect_meshes(ch))
	return out
