extends SceneTree

func _init() -> void:
	var packed := load("res://src/player/rogue_hooded.glb") as PackedScene
	var inst := packed.instantiate()
	root.add_child(inst)
	call_deferred("_go", inst)

func _go(inst: Node) -> void:
	var out := FileAccess.open("res://tools/uvs.txt", FileAccess.WRITE)
	_dump(inst, out)
	out.close()
	print("UVS EXPORTED")
	quit()

func _dump(n: Node, out: FileAccess) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var arrays := mi.mesh.surface_get_arrays(s)
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				out.store_line("MESH " + n.name)
				for uv in uvs:
					out.store_line(str(uv.x) + "," + str(uv.y))
	if n is MeshInstance3D and (n as MeshInstance3D).mesh == null:
		pass
	for ch in n.get_children():
		_dump(ch, out)
