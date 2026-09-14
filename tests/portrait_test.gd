extends SceneTree
## Portrait smoke test: the menu portrait builds its 3D ninja rig cleanly.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for i in 5:
		await process_frame
	var portrait_script: GDScript = load("res://src/ui/portrait.gd")
	var p: Control = portrait_script.new()
	root.add_child(p)
	for i in 10:
		await process_frame
	var rig: Node3D = p.get("_rig")
	print("portrait rig: ", "OK" if rig != null else "FAIL null")
	if rig != null:
		print("  mask: ", rig.find_child("Ninja_Mask") != null)
		print("  headband: ", rig.find_child("Ninja_Headband") != null)
		print("  cape: ", rig.find_child("Rogue_Cape") != null)
		var anim := rig.find_child("AnimationPlayer") as AnimationPlayer
		print("  idle anim: ", anim != null and anim.current_animation == "Idle")
		print("  brows: ", rig.get_child_count() > 2)
	print("PORTRAIT TEST DONE")
	quit(0)
