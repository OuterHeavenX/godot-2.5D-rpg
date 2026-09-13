extends SceneTree
## Development tool: look for big flat surfaces stacked at nearly the same
## height. Two of them within a centimetre fight for the same depth and
## the surface blinks, which is what the island did during the first boss
## fight. Run it after moving any ground, path, floor or water plane:
##
##   godot --headless --path . -s tools/check_stacked_surfaces.gd
##
## It compares bounding boxes, so two long strips crossing at an angle can
## be reported without really overlapping. Check any pair it names.
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	change_scene_to_file("res://src/world/main.tscn")
	for i in 12:
		await process_frame
	var boxes: Array = []
	_collect(current_scene, boxes)
	print("large surfaces: ", boxes.size())
	var reported := 0
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			if absf(float(a["top"]) - float(b["top"])) > 0.012:
				continue
			var ox := minf(float(a["x1"]), float(b["x1"])) - maxf(float(a["x0"]), float(b["x0"]))
			var oz := minf(float(a["z1"]), float(b["z1"])) - maxf(float(a["z0"]), float(b["z0"]))
			if ox <= 0.5 or oz <= 0.5:
				continue
			reported += 1
			if reported <= 25:
				print("  %.3f  %-34s vs %-34s  overlap %.0fx%.0fm"
					% [float(a["top"]), String(a["path"]), String(b["path"]), ox, oz])
	print("stacked pairs: ", reported)
	quit(0)

func _collect(n: Node, out: Array) -> void:
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if ab.size.x * ab.size.z >= 6.0 and ab.size.y <= 2.5:
			out.append({
				"path": String(mi.name if mi.get_parent() == null else "%s/%s" % [mi.get_parent().name, mi.name]),
				"top": ab.position.y + ab.size.y,
				"x0": ab.position.x, "x1": ab.position.x + ab.size.x,
				"z0": ab.position.z, "z1": ab.position.z + ab.size.z,
			})
	for c in n.get_children():
		_collect(c, out)
