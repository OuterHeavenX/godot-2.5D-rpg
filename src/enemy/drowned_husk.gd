class_name DrownedHusk
extends Skeleton
## A waterlogged skeleton warrior that crawled out of the black water.
## Slow, but hits like a drowned anchor and takes a beating.

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
	# The husks shamble along the black water's edge, never far from it.
	roam_min = Vector2(6.0, 40.0)
	roam_max = Vector2(22.0, 70.0)

func _ready() -> void:
	super._ready()
	# Sickly green waterlogged tint.
	_tint_rig(Color(0.55, 1.0, 0.65))
	# Bulkier than a common skeleton.
	rig.scale = Vector3(1.15, 1.15, 1.15)

## Multiply every surface material toward a tint color.
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
